use std::collections::BTreeMap;
use std::ffi::CString;
use std::fmt;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::net::Shutdown;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd, RawFd};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};

use crate::auth::approvals::{ApprovalDecision, ApprovalKind};
use crate::auth::credentials::{
    ConfiguredCredentialProvider, CredentialProvider, CredentialRequest,
};
use crate::auth::filesystem::{
    authorize_filesystem_access, FilesystemAuthorization, FilesystemAuthorizationCacheEntry,
    FilesystemAuthorizationContext,
};
use crate::kernel::seccomp;
use crate::model::config::{
    default_global_config_path, CondomConfig, CredentialSource, ExecutionMode,
};
use crate::model::events::EventLog;
use crate::model::policy;
use crate::model::project::ProjectContext;
use crate::model::state::StatePaths;
use crate::net::tproxy;
use crate::sandbox::capture;
use crate::sandbox::fence::{self, FenceRunOptions};
use crate::sandbox::review;

pub(crate) mod probe;
pub(crate) mod protocol;
mod request;
mod sandbox;

use probe::*;
pub use probe::*;
use protocol::*;
pub use protocol::*;
use request::*;
pub use request::*;
use sandbox::*;
pub use sandbox::*;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::auth::approvals::{Approval, ApprovalScope, ApprovalStore, NewApproval};
    use std::os::unix::fs::PermissionsExt;
    use std::os::unix::net::{UnixListener, UnixStream};
    use std::sync::Mutex;
    use std::thread;
    use uuid::Uuid;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn reads_unix_socket_peer_credentials() {
        let (left, right) = UnixStream::pair().unwrap();
        let credentials = socket_peer_credentials(left.as_raw_fd()).unwrap().unwrap();

        assert_eq!(credentials.uid, unsafe { libc::geteuid() });
        assert_eq!(credentials.gid, unsafe { libc::getegid() });
        drop(right);
    }

    #[test]
    fn explicit_helper_socket_is_execution_endpoint_unless_helper_is_disabled() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_helper = std::env::var_os(HELPER_ENV);
        let previous_socket = std::env::var_os(HELPER_SOCKET_ENV);
        let previous_disabled = std::env::var_os(DISABLE_HELPER_REENTRY_ENV);
        std::env::remove_var(HELPER_ENV);
        std::env::set_var(HELPER_SOCKET_ENV, "/tmp/condom-helper-test.sock");
        std::env::set_var(DISABLE_HELPER_REENTRY_ENV, "1");

        assert_eq!(configured_execution_socket_path().unwrap(), None);

        std::env::remove_var(DISABLE_HELPER_REENTRY_ENV);
        assert_eq!(
            configured_execution_socket_path().unwrap(),
            Some(PathBuf::from("/tmp/condom-helper-test.sock"))
        );

        std::env::set_var(HELPER_ENV, "/tmp/condom-helper-test-binary");
        std::env::remove_var(HELPER_SOCKET_ENV);
        assert_eq!(configured_execution_socket_path().unwrap(), None);

        restore_env(HELPER_ENV, previous_helper);
        restore_env(HELPER_SOCKET_ENV, previous_socket);
        restore_env(DISABLE_HELPER_REENTRY_ENV, previous_disabled);
    }

    #[test]
    fn run_sandbox_request_carries_required_caller_credentials() {
        let request = HelperRunSandboxRequest {
            protocol_version: HELPER_PROTOCOL_VERSION,
            kind: HelperSandboxKind::Run,
            project_root: "/tmp/project".into(),
            project_id: "project-id".into(),
            state_root: Some("/tmp/state".into()),
            caller_uid: 123,
            caller_gid: 456,
            caller_env: BTreeMap::from([
                ("HOME".into(), "/home/caller".into()),
                ("USER".into(), "caller".into()),
            ]),
            mode: ExecutionMode::Run,
            command: vec!["true".into()],
            policy_snapshot_id: Uuid::nil().to_string(),
            extra_env: BTreeMap::new(),
            runtime_path: None,
            ephemeral_overlays: Vec::new(),
            result_path: Some("/tmp/result.json".into()),
        };

        let value = serde_json::to_value(&request).unwrap();
        assert_eq!(value["projectId"], "project-id");
        assert_eq!(value["callerUid"], 123);
        assert_eq!(value["callerGid"], 456);
        assert_eq!(value["callerEnv"]["HOME"], "/home/caller");
        assert_eq!(
            request.caller_credentials(),
            PeerCredentials { uid: 123, gid: 456 }
        );
    }

    fn restore_env(key: &str, value: Option<std::ffi::OsString>) {
        if let Some(value) = value {
            std::env::set_var(key, value);
        } else {
            std::env::remove_var(key);
        }
    }

    #[test]
    fn detects_wrapped_broken_pipe_errors() {
        let error = anyhow::Error::new(std::io::Error::from(std::io::ErrorKind::BrokenPipe))
            .context("failed to write helper response");

        assert!(is_broken_pipe_error(&error));
    }

    fn fake_approval_prompt_environment(
        temp: &tempfile::TempDir,
        decision: &str,
    ) -> BTreeMap<String, String> {
        let bin_dir = temp.path().join("fake-bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let approval = bin_dir.join("condom-approval");
        fs::write(
            &approval,
            format!("#!/bin/sh\nprintf '%s\\n' {}\n", shell_quote(decision)),
        )
        .unwrap();
        fs::set_permissions(&approval, fs::Permissions::from_mode(0o755)).unwrap();
        let mut environment = BTreeMap::new();
        environment.insert(
            crate::auth::prompt::APPROVAL_DISPLAY_ENV.into(),
            ":99".into(),
        );
        environment.insert(
            crate::auth::prompt::APPROVAL_PATH_ENV.into(),
            format!(
                "{}:{}",
                bin_dir.display(),
                std::env::var("PATH").unwrap_or_default()
            ),
        );
        environment
    }

    fn shell_quote(value: &str) -> String {
        format!("'{}'", value.replace('\'', "'\\''"))
    }

    #[test]
    fn rejects_protocol_mismatch() {
        assert_eq!(
            validate_protocol(999),
            HelperResponse::UnsupportedProtocol {
                expected: HELPER_PROTOCOL_VERSION,
                actual: 999
            }
        );
    }

    #[test]
    fn handles_versioned_probe_request() {
        assert_eq!(
            handle_request(HelperRequest::Probe {
                protocol_version: HELPER_PROTOCOL_VERSION
            }),
            HelperResponse::Ready {
                protocol_version: HELPER_PROTOCOL_VERSION,
                helper_version: crate::VERSION.to_string(),
                capabilities: helper_capabilities()
            }
        );
    }

    #[test]
    fn credential_request_uses_helper_side_credential_file() {
        let temp = tempfile::tempdir().unwrap();
        let project_root = temp.path().join("project");
        std::fs::create_dir_all(project_root.join(".condom")).unwrap();
        let credential_file = temp.path().join("helper-credentials.toml");
        std::fs::write(
            &credential_file,
            "[hosts]\n\"registry.example.test\" = \"helper-file-secret\"\n",
        )
        .unwrap();
        std::fs::write(
            project_root.join(".condom/config.toml"),
            format!(
                r#"
[proxy]
credentialSource = "helper"
credentialFile = "{}"
"#,
                credential_file.display()
            ),
        )
        .unwrap();

        let response = handle_request(HelperRequest::Credential {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: project_root.display().to_string(),
            scheme: "https".into(),
            host: "registry.example.test".into(),
            port: 443,
            method: "GET".into(),
            path: "/package".into(),
        });

        assert_eq!(
            response,
            HelperResponse::Credential {
                header_name: "Authorization".into(),
                header_value: "Bearer helper-file-secret".into(),
            }
        );
    }

    #[test]
    fn parses_bubblewrap_help_into_partial_capabilities() {
        let help = "--bind SRC DEST --ro-bind SRC DEST --tmpfs DEST --proc DEST --dev DEST --unshare-pid --die-with-parent";

        assert_eq!(
            capabilities_from_bubblewrap_help(help),
            vec![
                HelperCapability::MountIsolation,
                HelperCapability::ProcessRestrictions,
            ]
        );
    }

    #[test]
    fn helper_probe_capability_check_detects_missing_capability() {
        let probe = HelperProbe::Ready {
            path: PathBuf::from("/run/condom/helper.sock"),
            helper_version: "0.1.0".into(),
            capabilities: vec![HelperCapability::MountIsolation],
        };

        assert!(!helper_probe_has_capability(probe, HelperCapability::EphemeralOverlays).unwrap());
    }

    #[test]
    fn bubblewrap_capability_parser_keeps_incomplete_surfaces_partial() {
        assert_eq!(
            capabilities_from_bubblewrap_help("--bind SRC DEST --tmpfs DEST"),
            Vec::<HelperCapability>::new()
        );
        assert_eq!(
            capabilities_from_bubblewrap_help(
                "--bind SRC DEST --ro-bind SRC DEST --tmpfs DEST --proc DEST --dev DEST"
            ),
            vec![HelperCapability::MountIsolation]
        );
    }

    #[test]
    fn transparent_proxy_routing_capability_requires_module_env() {
        assert!(!tproxy::routing_configured(None));
        assert!(!tproxy::routing_configured(Some(std::ffi::OsStr::new("0"))));
        assert!(tproxy::routing_configured(Some(std::ffi::OsStr::new("1"))));
        assert!(tproxy::routing_configured(Some(std::ffi::OsStr::new(
            "true"
        ))));
    }

    #[test]
    fn tproxy_routing_outputs_require_policy_route_and_nft_rule() {
        let rules = "15080: from all fwmark 0xc0de lookup 15080\n";
        let routes = "local default dev lo scope host\n";
        let nft = "table ip condom-tproxy { chain divert { iifname \"lo\" tcp dport { 80, 443 } tproxy to :15080 meta mark set 49374 accept } }\n";

        assert!(tproxy_routing_outputs_match(
            rules,
            routes,
            nft,
            TproxyRoutingExpectation {
                mark: 49374,
                table: 15080,
                proxy_port: 15080,
                tcp_ports: &[80, 443],
                interface: "lo",
            }
        ));
        assert!(!tproxy_routing_outputs_match(
            "",
            routes,
            nft,
            TproxyRoutingExpectation {
                mark: 49374,
                table: 15080,
                proxy_port: 15080,
                tcp_ports: &[80, 443],
                interface: "lo",
            }
        ));
        assert!(!tproxy_routing_outputs_match(
            rules,
            "",
            nft,
            TproxyRoutingExpectation {
                mark: 49374,
                table: 15080,
                proxy_port: 15080,
                tcp_ports: &[80, 443],
                interface: "lo",
            }
        ));
        assert!(!tproxy_routing_outputs_match(
            rules,
            routes,
            "",
            TproxyRoutingExpectation {
                mark: 49374,
                table: 15080,
                proxy_port: 15080,
                tcp_ports: &[80, 443],
                interface: "lo",
            }
        ));
        assert!(!tproxy_routing_outputs_match(
            rules,
            routes,
            nft,
            TproxyRoutingExpectation {
                mark: 49374,
                table: 15080,
                proxy_port: 15080,
                tcp_ports: &[80, 443],
                interface: "container0",
            }
        ));
    }

    #[test]
    fn probes_helper_over_unix_socket() {
        let temp = tempfile::tempdir().unwrap();
        let socket = temp.path().join("helper.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        let handle = thread::spawn(move || {
            let (mut stream, _addr) = listener.accept().unwrap();
            let request = read_request(&mut stream).unwrap();
            assert_eq!(
                request,
                HelperRequest::Probe {
                    protocol_version: HELPER_PROTOCOL_VERSION
                }
            );
            write_response(
                &mut stream,
                &HelperResponse::Ready {
                    protocol_version: HELPER_PROTOCOL_VERSION,
                    helper_version: "socket-test".into(),
                    capabilities: vec![HelperCapability::MountIsolation],
                },
            )
            .unwrap();
        });

        assert_eq!(
            probe_helper_socket(&socket),
            HelperProbe::Ready {
                path: socket,
                helper_version: "socket-test".into(),
                capabilities: vec![HelperCapability::MountIsolation],
            }
        );
        handle.join().unwrap();
    }

    #[test]
    fn prepare_sandbox_client_uses_policy_snapshot_state_root() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext::from_root(temp.path().join("project")).unwrap();
        std::fs::create_dir_all(&project.root).unwrap();
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        let config = CondomConfig::default();
        let snapshot = policy::write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let socket = temp.path().join("helper.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        let snapshot_id = snapshot.id.to_string();
        let expected_state_root = state_root.display().to_string();
        let helper = thread::spawn({
            let snapshot_id = snapshot_id.clone();
            move || {
                let (mut stream, _) = listener.accept().unwrap();
                let request = read_request(&mut stream).unwrap();
                assert!(matches!(
                    request,
                    HelperRequest::PrepareSandbox {
                        state_root: Some(state_root),
                        policy_snapshot_id,
                        ..
                    } if state_root == expected_state_root && policy_snapshot_id == snapshot_id
                ));
                write_response(
                    stream,
                    &HelperResponse::SandboxPrepared {
                        protocol_version: HELPER_PROTOCOL_VERSION,
                        policy_snapshot_id: snapshot_id,
                        capabilities: vec![HelperCapability::MountIsolation],
                        runner: "fence-landlock-seccomp".into(),
                    },
                )
                .unwrap();
            }
        });

        let preparation =
            prepare_sandbox(&HelperEndpoint::Socket(socket), &project, &snapshot).unwrap();
        helper.join().unwrap();

        assert_eq!(preparation.policy_snapshot_id, snapshot.id.to_string());
        assert_eq!(preparation.runner, "fence-landlock-seccomp");
    }

    #[test]
    fn prepare_sandbox_capabilities_follow_transparent_proxy_requirements() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext::from_root(temp.path().join("project")).unwrap();
        std::fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();
        let default_snapshot = policy::write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let mut default_transparent_snapshot = default_snapshot.clone();
        default_transparent_snapshot.transparent_proxy =
            crate::model::policy::TransparentProxySnapshot {
                enabled: true,
                tcp_ports: vec![80, 443],
                allowed_hosts: vec!["*".into()],
            };
        let basic_capabilities = vec![
            HelperCapability::MountIsolation,
            HelperCapability::ProcessRestrictions,
            HelperCapability::SyscallRestrictions,
        ];

        assert_eq!(
            missing_required_capabilities_for_snapshot(&default_snapshot, &basic_capabilities),
            Vec::<HelperCapability>::new()
        );
        assert_eq!(
            missing_required_capabilities_for_snapshot(
                &default_transparent_snapshot,
                &basic_capabilities
            ),
            vec![HelperCapability::NetworkRouting]
        );
    }

    #[test]
    fn prepare_sandbox_returns_prepared_or_missing_required_capabilities() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext::from_root(temp.path().to_path_buf()).unwrap();
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        let config = CondomConfig::default();
        let snapshot = policy::write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let expected_missing =
            missing_required_capabilities_for_snapshot(&snapshot, &helper_capabilities());
        let response = handle_request(HelperRequest::PrepareSandbox {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: project.root.display().to_string(),
            project_id: project.id.clone(),
            state_root: Some(state_root.display().to_string()),
            policy_snapshot_id: snapshot.id.to_string(),
        });

        if expected_missing.is_empty() {
            assert_eq!(
                response,
                HelperResponse::SandboxPrepared {
                    protocol_version: HELPER_PROTOCOL_VERSION,
                    policy_snapshot_id: snapshot.id.to_string(),
                    capabilities: helper_capabilities(),
                    runner: "fence-landlock-seccomp".into(),
                }
            );
        } else {
            assert_eq!(
                response,
                HelperResponse::MissingCapabilities {
                    missing_capabilities: expected_missing,
                    message: "root supervisor sandbox preparation is missing required capabilities"
                        .into()
                }
            );
            if let HelperResponse::MissingCapabilities {
                missing_capabilities,
                ..
            } = response
            {
                assert!(!missing_capabilities.is_empty());
            }
        }
    }

    #[test]
    fn prepare_sandbox_rejects_missing_policy_snapshot_before_capabilities() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext::from_root(temp.path().to_path_buf()).unwrap();
        let missing_id = uuid::Uuid::new_v4().to_string();

        let response = handle_request(HelperRequest::PrepareSandbox {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: project.root.display().to_string(),
            project_id: project.id.clone(),
            state_root: Some(temp.path().join("state").display().to_string()),
            policy_snapshot_id: missing_id.clone(),
        });

        match response {
            HelperResponse::InvalidRequest { message } => {
                assert!(message.contains(&format!("failed to load policy snapshot `{missing_id}`")));
            }
            other => panic!("expected invalid request, got {other:?}"),
        }
    }

    #[test]
    fn prepare_sandbox_rejects_missing_project_root() {
        let temp = tempfile::tempdir().unwrap();
        let missing_root = temp.path().join("missing");

        let response = handle_request(HelperRequest::PrepareSandbox {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: missing_root.display().to_string(),
            project_id: "missing-project".into(),
            state_root: Some(temp.path().join("state").display().to_string()),
            policy_snapshot_id: uuid::Uuid::new_v4().to_string(),
        });

        match response {
            HelperResponse::InvalidRequest { message } => {
                assert!(message.contains("is not a directory"));
            }
            other => panic!("expected invalid request, got {other:?}"),
        }
    }

    #[test]
    fn filesystem_authorization_denies_without_approval_ui() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext::from_root(temp.path().to_path_buf()).unwrap();

        assert_eq!(
            handle_request(HelperRequest::AuthorizeFilesystem {
                protocol_version: HELPER_PROTOCOL_VERSION,
                project_root: project.root.display().to_string(),
                project_id: project.id.clone(),
                state_root: Some(temp.path().join("state").display().to_string()),
                mode: ExecutionMode::Run,
                command: vec!["tool".into()],
                kind: ApprovalKind::FsRead,
                path: "/opt/sdk".into(),
                policy_snapshot_id: None,
                prompt_environment: BTreeMap::new(),
                caller_env: BTreeMap::new(),
            }),
            HelperResponse::FilesystemAuthorization {
                decision: ApprovalDecision::Deny,
                reason: "filesystem access denied because no approval UI is available".into(),
                cacheable: false,
                suggested_allow: Some("condom allow add fs-read /opt/sdk".into()),
                cache_entries: Vec::new(),
            }
        );
    }

    #[test]
    fn filesystem_authorization_prompts_through_request_approval_environment() {
        let temp = tempfile::tempdir().unwrap();
        let prompt_environment = fake_approval_prompt_environment(&temp, "aa");
        let project = ProjectContext::from_root(temp.path().to_path_buf()).unwrap();

        let response = handle_request(HelperRequest::AuthorizeFilesystem {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: project.root.display().to_string(),
            project_id: project.id.clone(),
            state_root: Some(temp.path().join("state").display().to_string()),
            mode: ExecutionMode::Run,
            command: vec!["tool".into()],
            kind: ApprovalKind::FsWrite,
            path: "/opt/cache".into(),
            policy_snapshot_id: None,
            prompt_environment,
            caller_env: BTreeMap::new(),
        });

        assert_eq!(
            response,
            HelperResponse::FilesystemAuthorization {
                decision: ApprovalDecision::Allow,
                reason: "allowed for app/project by filesystem prompt".into(),
                cacheable: true,
                suggested_allow: None,
                cache_entries: Vec::new(),
            }
        );
    }

    #[test]
    fn filesystem_authorization_returns_instance_cache_entries() {
        let temp = tempfile::tempdir().unwrap();
        let prompt_environment =
            fake_approval_prompt_environment(&temp, "ai access=read-write subject=/opt/cache");
        let project = ProjectContext::from_root(temp.path().to_path_buf()).unwrap();

        let response = handle_request(HelperRequest::AuthorizeFilesystem {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: project.root.display().to_string(),
            project_id: project.id.clone(),
            state_root: Some(temp.path().join("state").display().to_string()),
            mode: ExecutionMode::Run,
            command: vec!["tool".into()],
            kind: ApprovalKind::FsRead,
            path: "/opt/cache/file.json".into(),
            policy_snapshot_id: None,
            prompt_environment,
            caller_env: BTreeMap::new(),
        });

        assert_eq!(
            response,
            HelperResponse::FilesystemAuthorization {
                decision: ApprovalDecision::Allow,
                reason: "allowed for instance by filesystem prompt".into(),
                cacheable: true,
                suggested_allow: None,
                cache_entries: vec![
                    FilesystemAuthorizationCacheEntry {
                        kind: ApprovalKind::FsRead,
                        subject: "/opt/cache".into(),
                    },
                    FilesystemAuthorizationCacheEntry {
                        kind: ApprovalKind::FsWrite,
                        subject: "/opt/cache".into(),
                    },
                ],
            }
        );
    }

    #[test]
    fn filesystem_authorization_uses_stored_approval() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext::from_root(temp.path().to_path_buf()).unwrap();
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        ApprovalStore::new(state.approvals_file.clone())
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::FsExec,
                        subject: "/opt/tool".into(),
                        ttl: None,
                        once: false,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();

        assert_eq!(
            handle_request(HelperRequest::AuthorizeFilesystem {
                protocol_version: HELPER_PROTOCOL_VERSION,
                project_root: project.root.display().to_string(),
                project_id: project.id.clone(),
                state_root: Some(state_root.display().to_string()),
                mode: ExecutionMode::Run,
                command: vec!["tool".into()],
                kind: ApprovalKind::FsExec,
                path: "/opt/tool".into(),
                policy_snapshot_id: None,
                prompt_environment: BTreeMap::new(),
                caller_env: BTreeMap::new(),
            }),
            HelperResponse::FilesystemAuthorization {
                decision: ApprovalDecision::Allow,
                reason: "allowed by stored filesystem approval".into(),
                cacheable: true,
                suggested_allow: None,
                cache_entries: Vec::new(),
            }
        );
    }

    #[test]
    fn filesystem_authorization_uses_policy_snapshot() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext::from_root(temp.path().to_path_buf()).unwrap();
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        let mut config = CondomConfig::default();
        config.filesystem.allow_read = vec!["/opt/sdk/**".into()];
        let snapshot = policy::write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();

        let response = handle_request(HelperRequest::AuthorizeFilesystem {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: project.root.display().to_string(),
            project_id: project.id.clone(),
            state_root: Some(state_root.display().to_string()),
            mode: ExecutionMode::Run,
            command: vec!["tool".into()],
            kind: ApprovalKind::FsRead,
            path: "/opt/sdk/include/header.h".into(),
            policy_snapshot_id: Some(snapshot.id.to_string()),
            prompt_environment: BTreeMap::new(),
            caller_env: BTreeMap::new(),
        });

        match response {
            HelperResponse::FilesystemAuthorization {
                decision,
                reason,
                cacheable,
                suggested_allow,
                cache_entries,
            } => {
                assert_eq!(decision, ApprovalDecision::Allow);
                assert!(reason.contains("policy snapshot pattern"));
                assert!(cacheable);
                assert_eq!(suggested_allow, None);
                assert!(cache_entries.is_empty());
            }
            other => panic!("expected filesystem authorization, got {other:?}"),
        }
    }

    #[test]
    fn filesystem_authorization_uses_request_project_id_for_snapshot_lookup() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: fs::canonicalize(temp.path()).unwrap(),
            id: "client-project-id".into(),
            origin: None,
        };
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        let mut config = CondomConfig::default();
        config.filesystem.allow_read = vec!["/opt/sdk/**".into()];
        let snapshot = policy::write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();

        let response = handle_request(HelperRequest::AuthorizeFilesystem {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: project.root.display().to_string(),
            project_id: project.id.clone(),
            state_root: Some(state_root.display().to_string()),
            mode: ExecutionMode::Run,
            command: vec!["tool".into()],
            kind: ApprovalKind::FsRead,
            path: "/opt/sdk/include/header.h".into(),
            policy_snapshot_id: Some(snapshot.id.to_string()),
            prompt_environment: BTreeMap::new(),
            caller_env: BTreeMap::new(),
        });

        match response {
            HelperResponse::FilesystemAuthorization {
                decision,
                reason,
                cacheable,
                suggested_allow,
                cache_entries,
            } => {
                assert_eq!(decision, ApprovalDecision::Allow);
                assert!(reason.contains("policy snapshot pattern"));
                assert!(cacheable);
                assert_eq!(suggested_allow, None);
                assert!(cache_entries.is_empty());
            }
            other => panic!("expected filesystem authorization, got {other:?}"),
        }
    }

    #[test]
    fn detects_missing_helper_capabilities() {
        assert_eq!(
            missing_required_capabilities(&[
                HelperCapability::MountIsolation,
                HelperCapability::ProcessRestrictions,
            ]),
            vec![HelperCapability::SyscallRestrictions]
        );
    }
}
