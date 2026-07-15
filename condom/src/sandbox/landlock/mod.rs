use std::collections::BTreeMap;
use std::ffi::CString;
use std::fs;
use std::io;
use std::mem::size_of;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd, RawFd};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::net::UnixStream;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Mutex;

use anyhow::{bail, Context, Result};

use crate::app::helper::{self, HelperEndpoint, HelperRequest, HELPER_PROTOCOL_VERSION};
use crate::auth::approvals::{ApprovalDecision, ApprovalKind};
use crate::auth::filesystem::{
    authorize_filesystem_access, FilesystemAuthorization, FilesystemAuthorizationCacheEntry,
    FilesystemAuthorizationContext,
};
use crate::auth::prompt;
use crate::auth::redacted;
use crate::kernel::seccomp::{self, FilesystemNotificationResponse};
use crate::model::config::{default_global_config_path, CondomConfig};
use crate::model::events::{Decision, Event, EventLog};
use crate::model::policy::{self, PolicySnapshot};
use crate::model::policy_pattern::{expand_home, policy_pattern_matches};
use crate::model::project::ProjectContext;
use crate::model::runtime_support::{path_is_blocked_by_patterns, plan_runtime_read_paths};
use crate::model::state::StatePaths;

mod mediate;
mod syscall;
mod wrap;

use mediate::*;
use syscall::*;
use wrap::*;
pub use wrap::*;

fn remove_internal_control_environment(command: &mut Command) {
    command.env_remove(helper::DISABLE_HELPER_REENTRY_ENV);
    command.env_remove(helper::AUTH_HELPER_SOCKET_ENV);
}

fn clear_internal_control_environment_for_exec() {
    for key in [
        helper::DISABLE_HELPER_REENTRY_ENV,
        helper::AUTH_HELPER_SOCKET_ENV,
    ] {
        let key = CString::new(key).expect("control environment key has no NUL bytes");
        unsafe {
            libc::unsetenv(key.as_ptr());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::auth::approvals::{Approval, ApprovalScope, ApprovalStore, NewApproval};
    use crate::model::config::{CondomConfig, ExecutionMode};
    use crate::model::policy::{
        write_snapshot, write_snapshot_with_network, NetworkMediationSnapshot,
        TransparentProxySnapshot,
    };
    use crate::model::project::ProjectContext;
    use crate::model::state::StatePaths;
    use std::io::{Read, Write};
    use std::os::unix::net::UnixListener;
    use std::sync::{Mutex, MutexGuard};
    use std::{ffi::OsString, thread};

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    struct ApprovalEnvGuard {
        _lock: MutexGuard<'static, ()>,
        previous: Vec<(&'static str, Option<OsString>)>,
    }

    impl Drop for ApprovalEnvGuard {
        fn drop(&mut self) {
            for (key, value) in self.previous.drain(..) {
                if let Some(value) = value {
                    std::env::set_var(key, value);
                } else {
                    std::env::remove_var(key);
                }
            }
        }
    }

    fn without_approval_prompt_ui() -> ApprovalEnvGuard {
        let lock = ENV_LOCK.lock().unwrap();
        let keys = [
            "TMUX",
            "DISPLAY",
            "WAYLAND_DISPLAY",
            helper::HELPER_ENV,
            helper::HELPER_SOCKET_ENV,
            helper::DISABLE_HELPER_REENTRY_ENV,
            helper::AUTH_HELPER_SOCKET_ENV,
            crate::auth::prompt::APPROVAL_PATH_ENV,
            crate::auth::prompt::APPROVAL_DISPLAY_ENV,
            crate::auth::prompt::APPROVAL_WAYLAND_DISPLAY_ENV,
        ];
        let previous = keys
            .into_iter()
            .map(|key| {
                let value = std::env::var_os(key);
                std::env::remove_var(key);
                (key, value)
            })
            .collect();
        ApprovalEnvGuard {
            _lock: lock,
            previous,
        }
    }

    #[test]
    fn wrapped_command_carries_runtime_path_before_user_command() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["agent".into()],
            &[],
        )
        .unwrap();

        let wrapped = wrap_command_with_runner_path(
            Path::new("/home/me/.local/bin/condom"),
            &snapshot,
            &["agent".into()],
            Some("/home/me/.local/bin:/run/current-system/sw/bin"),
        )
        .unwrap();

        let separator = wrapped.iter().position(|arg| arg == "--").unwrap();
        assert_eq!(wrapped[1], "__landlock-exec");
        assert_eq!(wrapped[4], RUNTIME_PATH_ARG);
        assert_eq!(wrapped[5], "/home/me/.local/bin:/run/current-system/sw/bin");
        assert_eq!(wrapped[separator + 1], "agent");
    }

    #[test]
    fn interactive_wrapped_command_carries_pty_flag_before_user_command() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["fish".into()],
            &[],
        )
        .unwrap();

        let wrapped = wrap_interactive_command_with_runner_path(
            Path::new("/home/me/.local/bin/condom"),
            &snapshot,
            &["fish".into()],
            Some("/home/me/.local/bin:/run/current-system/sw/bin"),
        )
        .unwrap();

        let separator = wrapped.iter().position(|arg| arg == "--").unwrap();
        assert!(wrapped[..separator]
            .iter()
            .any(|arg| arg == INTERACTIVE_PTY_ARG));
        assert_eq!(wrapped[separator + 1], "fish");
        assert!(wrapped[separator + 2..].is_empty());
    }

    #[test]
    fn trims_glob_suffixes_and_skips_non_concrete_patterns() {
        assert_eq!(
            concrete_policy_path("/tmp/cache/**"),
            Some(PathBuf::from("/tmp/cache"))
        );
        assert_eq!(
            concrete_policy_path("/tmp/cache/*"),
            Some(PathBuf::from("/tmp/cache"))
        );
        assert_eq!(concrete_policy_path("/tmp/*/secret"), None);
        assert_eq!(concrete_policy_path("relative/path"), None);
    }

    #[test]
    fn project_parent_directory_support_is_exact() {
        let project_root = Path::new("/home/example/brain/config/dotfiles/nvim");

        assert!(is_project_parent_directory(project_root, "/home"));
        assert!(is_project_parent_directory(
            project_root,
            "/home/example/brain/config"
        ));
        assert!(!is_project_parent_directory(
            project_root,
            "/home/example/.ssh"
        ));
        assert!(is_project_parent_directory(project_root, "/"));
        assert!(!is_project_parent_directory(
            project_root,
            project_root.to_str().unwrap()
        ));
    }

    #[test]
    fn support_parent_directory_match_is_exact() {
        assert!(is_parent_directory(
            Path::new("/nix/store"),
            Path::new("/nix")
        ));
        assert!(is_parent_directory(
            Path::new("/etc/ssl"),
            Path::new("/etc")
        ));
        assert!(!is_parent_directory(
            Path::new("/nix/store"),
            Path::new("/nix/var")
        ));
        assert!(!is_parent_directory(
            Path::new("/nix/store"),
            Path::new("/nix/store")
        ));
    }

    #[test]
    fn planned_landlock_rules_include_policy_and_runtime_paths() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        std::fs::create_dir_all(&state.xdg_state_dir).unwrap();
        let mut config = CondomConfig::default();
        config.filesystem.allow_read = vec![temp.path().join("sdk").display().to_string()];
        config.filesystem.allow_write = vec![temp.path().join("cache").display().to_string()];
        config.filesystem.allow_execute = vec![temp.path().join("tool").display().to_string()];
        for path in ["sdk", "cache", "tool"] {
            std::fs::create_dir_all(temp.path().join(path)).unwrap();
        }
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["sh".into()],
            &[],
        )
        .unwrap();

        let plan = LandlockPlan::from_snapshot(&snapshot).unwrap();

        assert!(plan
            .rules
            .iter()
            .any(|rule| rule.allowed_access & READ_ACCESS == READ_ACCESS));
        assert!(plan.rules.iter().any(|rule| {
            rule.allowed_access
                & (WRITE_ACCESS_BASE | abi_write_extensions(landlock_abi().unwrap()))
                != 0
        }));
        assert!(plan
            .rules
            .iter()
            .any(|rule| rule.allowed_access & LANDLOCK_ACCESS_FS_EXECUTE != 0));
    }

    #[test]
    fn runtime_support_rules_respect_snapshot_read_write_and_redaction_protections() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let mut config = CondomConfig::default();
        config.filesystem.deny_read = vec!["/etc/resolv.conf".into()];
        config.filesystem.redact_read = vec!["/sys/devices/system/cpu/online".into()];
        config.filesystem.deny_write = vec!["/dev/tty".into()];
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["sh".into()],
            &[],
        )
        .unwrap();

        let rules = runtime_support_rules_from(&snapshot, &BTreeMap::new(), None);

        assert!(rules.iter().any(|(path, _)| path == "/etc/hosts"));
        assert!(!rules.iter().any(|(path, _)| path == "/etc/resolv.conf"));
        assert!(!rules
            .iter()
            .any(|(path, _)| path == "/sys/devices/system/cpu/online"));
        assert!(rules
            .iter()
            .any(|(path, access)| { path == "/dev/null" && access & WRITE_ACCESS_BASE != 0 }));
        assert!(!rules.iter().any(|(path, _)| path == "/dev/tty"));
    }

    #[test]
    fn planned_landlock_network_rules_follow_network_mediation() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        std::fs::create_dir_all(&state.xdg_state_dir).unwrap();
        let config = CondomConfig::default();
        let default_snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["sh".into()],
            &[],
        )
        .unwrap();
        let proxy_snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["sh".into()],
            &[32123, 32123, 32124],
        )
        .unwrap();

        let default_plan = LandlockPlan::from_snapshot(&default_snapshot).unwrap();
        assert_eq!(
            default_plan.handled_access_net,
            LANDLOCK_ACCESS_NET_CONNECT_TCP
        );
        assert!(default_plan.network_rules.is_empty());

        let proxy_plan = LandlockPlan::from_snapshot(&proxy_snapshot).unwrap();
        assert_eq!(
            proxy_plan.handled_access_net,
            LANDLOCK_ACCESS_NET_CONNECT_TCP
        );
        assert_eq!(
            proxy_plan
                .network_rules
                .iter()
                .map(|rule| rule.port)
                .collect::<Vec<_>>(),
            vec![32123, 32124]
        );
        assert_eq!(
            proxy_plan.scoped,
            LANDLOCK_SCOPE_ABSTRACT_UNIX_SOCKET | LANDLOCK_SCOPE_SIGNAL
        );
    }

    #[test]
    fn planned_landlock_network_rules_include_transparent_proxy_ports() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        std::fs::create_dir_all(&state.xdg_state_dir).unwrap();
        let config = CondomConfig::default();
        let proxy_snapshot = write_snapshot_with_network(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["sh".into()],
            NetworkMediationSnapshot {
                allowed_loopback_ports: vec![15080],
                proxy_listen_port: None,
                transparent_proxy: TransparentProxySnapshot {
                    enabled: true,
                    tcp_ports: vec![443, 80, 443],
                    allowed_hosts: vec!["registry.example.test".into()],
                },
            },
        )
        .unwrap();

        let proxy_plan = LandlockPlan::from_snapshot(&proxy_snapshot).unwrap();
        assert_eq!(
            proxy_plan
                .network_rules
                .iter()
                .map(|rule| rule.port)
                .collect::<Vec<_>>(),
            vec![80, 443, 15080]
        );
    }

    #[test]
    fn filesystem_authorizer_uses_policy_snapshot_project_id_for_state() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "client-project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        let config = CondomConfig::default();
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();

        let authorizer = FilesystemNotificationAuthorizer::new(&snapshot).unwrap();

        assert_eq!(authorizer.project.id, "client-project-id");
        assert_eq!(authorizer.state.xdg_state_dir, state.xdg_state_dir);
    }

    #[test]
    fn filesystem_authorizer_uses_explicit_supervisor_auth_socket_under_reentry_guard() {
        let _approval_env = without_approval_prompt_ui();
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        let config = CondomConfig::default();
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let socket = temp.path().join("helper.sock");
        std::env::set_var(helper::HELPER_SOCKET_ENV, &socket);
        std::env::set_var(helper::DISABLE_HELPER_REENTRY_ENV, "1");

        let helper_authorizer = FilesystemNotificationAuthorizer::new(&snapshot).unwrap();
        assert!(helper_authorizer.helper_endpoint.is_none());

        std::env::set_var(helper::AUTH_HELPER_SOCKET_ENV, &socket);
        let supervisor_authorizer = FilesystemNotificationAuthorizer::new(&snapshot).unwrap();

        assert!(matches!(
            supervisor_authorizer.helper_endpoint.as_ref(),
            Some(HelperEndpoint::Socket(path)) if path == &socket
        ));
    }

    #[test]
    fn filesystem_authorizer_uses_helper_socket_decision() {
        let _approval_env = without_approval_prompt_ui();
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        let config = CondomConfig::default();
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let socket = temp.path().join("helper.sock");
        let helper = accept_helper_authorization(
            &socket,
            helper::HelperResponse::FilesystemAuthorization {
                decision: ApprovalDecision::Deny,
                reason: "denied by helper socket".into(),
                cacheable: false,
                suggested_allow: None,
                cache_entries: Vec::new(),
            },
        );
        let authorizer = FilesystemNotificationAuthorizer {
            project: project.clone(),
            state,
            state_root: Some(state_root),
            config,
            event_log: EventLog::new(temp.path().join("events.jsonl")),
            helper_endpoint: Some(HelperEndpoint::Socket(socket)),
            runtime_rules: runtime_support_rules(&snapshot),
            authorization_cache: Mutex::new(Vec::new()),
        };

        let allowed = authorizer
            .authorize(
                &snapshot,
                &FilesystemAccess {
                    kind: ApprovalKind::FsWrite,
                    path: temp.path().join("outside").display().to_string(),
                },
            )
            .unwrap();
        let request = helper.join().unwrap();

        assert!(!allowed);
        assert!(matches!(
            request,
            HelperRequest::AuthorizeFilesystem {
                kind: ApprovalKind::FsWrite,
                policy_snapshot_id: Some(_),
                ..
            }
        ));
    }

    #[test]
    fn filesystem_authorizer_prefers_helper_over_local_stored_approval() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        let store = ApprovalStore::new(state.approvals_file.clone());
        let outside = temp.path().join("outside").display().to_string();
        store
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::FsWrite,
                        subject: outside.clone(),
                        ttl: None,
                        once: false,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();
        let config = CondomConfig::default();
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let socket = temp.path().join("helper.sock");
        let helper = accept_helper_authorization(
            &socket,
            helper::HelperResponse::FilesystemAuthorization {
                decision: ApprovalDecision::Deny,
                reason: "denied by helper socket".into(),
                cacheable: false,
                suggested_allow: None,
                cache_entries: Vec::new(),
            },
        );
        let authorizer = FilesystemNotificationAuthorizer {
            project: project.clone(),
            state,
            state_root: Some(state_root),
            config,
            event_log: EventLog::new(temp.path().join("events.jsonl")),
            helper_endpoint: Some(HelperEndpoint::Socket(socket)),
            runtime_rules: runtime_support_rules(&snapshot),
            authorization_cache: Mutex::new(Vec::new()),
        };

        let allowed = authorizer
            .authorize(
                &snapshot,
                &FilesystemAccess {
                    kind: ApprovalKind::FsWrite,
                    path: outside,
                },
            )
            .unwrap();
        let request = helper.join().unwrap();

        assert!(!allowed);
        assert!(matches!(
            request,
            HelperRequest::AuthorizeFilesystem {
                kind: ApprovalKind::FsWrite,
                ..
            }
        ));
    }

    #[test]
    fn filesystem_authorizer_caches_helper_stored_approval_decision() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        let config = CondomConfig::default();
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let socket = temp.path().join("helper.sock");
        let helper = accept_helper_authorization(
            &socket,
            helper::HelperResponse::FilesystemAuthorization {
                decision: ApprovalDecision::Allow,
                reason: "allowed by stored filesystem approval".into(),
                cacheable: true,
                suggested_allow: None,
                cache_entries: Vec::new(),
            },
        );
        let authorizer = FilesystemNotificationAuthorizer {
            project: project.clone(),
            state,
            state_root: Some(state_root),
            config,
            event_log: EventLog::new(temp.path().join("events.jsonl")),
            helper_endpoint: Some(HelperEndpoint::Socket(socket)),
            runtime_rules: runtime_support_rules(&snapshot),
            authorization_cache: Mutex::new(Vec::new()),
        };
        let cached = temp.path().join("cached");
        std::fs::write(&cached, "cached").unwrap();
        let access = FilesystemAccess {
            kind: ApprovalKind::FsRead,
            path: cached.display().to_string(),
        };

        let first = authorizer.authorize(&snapshot, &access).unwrap();
        let second = authorizer.authorize(&snapshot, &access).unwrap();
        let request = helper.join().unwrap();

        assert!(first);
        assert!(second);
        assert!(matches!(
            request,
            HelperRequest::AuthorizeFilesystem {
                kind: ApprovalKind::FsRead,
                ..
            }
        ));
    }

    #[test]
    fn filesystem_authorizer_caches_helper_instance_approval_subject() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state_root = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_root);
        let config = CondomConfig::default();
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let cache_dir = temp.path().join("cache");
        std::fs::create_dir_all(&cache_dir).unwrap();
        let first_path = cache_dir.join("first.json");
        let second_path = cache_dir.join("second.json");
        std::fs::write(&first_path, "first").unwrap();
        std::fs::write(&second_path, "second").unwrap();
        let socket = temp.path().join("helper.sock");
        let helper = accept_helper_authorization(
            &socket,
            helper::HelperResponse::FilesystemAuthorization {
                decision: ApprovalDecision::Allow,
                reason: "allowed for instance by filesystem prompt".into(),
                cacheable: true,
                suggested_allow: None,
                cache_entries: vec![FilesystemAuthorizationCacheEntry {
                    kind: ApprovalKind::FsRead,
                    subject: cache_dir.display().to_string(),
                }],
            },
        );
        let authorizer = FilesystemNotificationAuthorizer {
            project: project.clone(),
            state,
            state_root: Some(state_root),
            config,
            event_log: EventLog::new(temp.path().join("events.jsonl")),
            helper_endpoint: Some(HelperEndpoint::Socket(socket)),
            runtime_rules: runtime_support_rules(&snapshot),
            authorization_cache: Mutex::new(Vec::new()),
        };

        let first = authorizer
            .authorize(
                &snapshot,
                &FilesystemAccess {
                    kind: ApprovalKind::FsRead,
                    path: first_path.display().to_string(),
                },
            )
            .unwrap();
        let second = authorizer
            .authorize(
                &snapshot,
                &FilesystemAccess {
                    kind: ApprovalKind::FsRead,
                    path: second_path.display().to_string(),
                },
            )
            .unwrap();
        let request = helper.join().unwrap();

        assert!(first);
        assert!(second);
        assert!(matches!(
            request,
            HelperRequest::AuthorizeFilesystem {
                path,
                ..
            } if path == first_path.display().to_string()
        ));
    }

    fn accept_helper_authorization(
        socket: &Path,
        response: helper::HelperResponse,
    ) -> thread::JoinHandle<HelperRequest> {
        let listener = UnixListener::bind(socket).unwrap();
        thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let mut input = String::new();
            stream.read_to_string(&mut input).unwrap();
            let request = serde_json::from_str(&input).unwrap();
            helper::write_response(stream, &response).unwrap();
            request
        })
    }

    #[test]
    fn handled_access_tracks_landlock_abi_extensions() {
        assert_eq!(handled_filesystem_access(1) & LANDLOCK_ACCESS_FS_REFER, 0);
        assert_eq!(
            handled_filesystem_access(2) & LANDLOCK_ACCESS_FS_REFER,
            LANDLOCK_ACCESS_FS_REFER
        );
        assert_eq!(
            handled_filesystem_access(2) & LANDLOCK_ACCESS_FS_TRUNCATE,
            0
        );
        assert_eq!(
            handled_filesystem_access(3) & LANDLOCK_ACCESS_FS_TRUNCATE,
            LANDLOCK_ACCESS_FS_TRUNCATE
        );
    }

    #[test]
    fn handled_network_access_fails_closed_without_landlock_network_abi() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();
        let mediated_snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["sh".into()],
            &[],
        )
        .unwrap();
        let loopback_port_snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["sh".into()],
            &[32123],
        )
        .unwrap();

        assert!(handled_network_access(3, &mediated_snapshot).is_err());
        assert!(handled_network_access(3, &loopback_port_snapshot).is_err());
        assert_eq!(
            handled_network_access(4, &mediated_snapshot).unwrap(),
            LANDLOCK_ACCESS_NET_CONNECT_TCP
        );
        assert_eq!(
            handled_network_access(4, &loopback_port_snapshot).unwrap(),
            LANDLOCK_ACCESS_NET_CONNECT_TCP
        );
    }

    #[test]
    fn scoped_restrictions_fail_closed_without_landlock_scope_abi() {
        assert!(scoped_restrictions(5).is_err());
        assert_eq!(
            scoped_restrictions(6).unwrap(),
            LANDLOCK_SCOPE_ABSTRACT_UNIX_SOCKET | LANDLOCK_SCOPE_SIGNAL
        );
    }

    #[test]
    fn filesystem_notifications_survive_execvp() {
        if !seccomp::filesystem_notification_supported() {
            return;
        }
        if Command::new("cat").arg("--version").output().is_err() {
            return;
        }
        let (parent_socket, child_socket) = UnixStream::pair().unwrap();
        let parent_fd = parent_socket.as_raw_fd();
        let child_fd = child_socket.as_raw_fd();
        let command = vec!["cat".into(), "/etc/hostname".into()];
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();
        let snapshot =
            write_snapshot(&project, &state, &config, ExecutionMode::Run, &command, &[]).unwrap();
        let landlock_plan =
            LandlockPlan::from_snapshot_for_filesystem_notifications(&snapshot).unwrap();
        let child =
            fork_mediated_child(&command, None, parent_fd, child_fd, &landlock_plan).unwrap();
        drop(child_socket);
        let listener = recv_fd(parent_socket.as_raw_fd()).unwrap();
        let mut saw_hostname = false;
        let mut seen_paths = Vec::new();
        for _ in 0..256 {
            if !poll_fd(listener.as_raw_fd(), 250).unwrap() {
                break;
            }
            let notification = seccomp::receive_filesystem_notification(&listener).unwrap();
            let accesses = filesystem_accesses_for_notification(&notification).unwrap();
            seen_paths.extend(accesses.iter().map(|access| access.path.clone()));
            saw_hostname |= accesses.iter().any(|access| access.path == "/etc/hostname");
            seccomp::respond_filesystem_notification(
                &listener,
                &notification,
                FilesystemNotificationResponse::Continue,
            )
            .unwrap();
            if saw_hostname {
                break;
            }
        }
        kill_and_reap_child(child);

        assert!(saw_hostname, "seen paths: {seen_paths:?}");
    }

    #[test]
    fn decoded_open_remains_usable_after_child_becomes_nondumpable() {
        let (mut parent_socket, mut child_socket) = UnixStream::pair().unwrap();
        let child = unsafe { libc::fork() };
        assert!(child >= 0);
        if child == 0 {
            drop(parent_socket);
            let path = CString::new("/etc/hostname").unwrap();
            child_socket
                .write_all(&(path.as_ptr() as usize).to_ne_bytes())
                .unwrap();
            let mut signal = [0_u8; 1];
            child_socket.read_exact(&mut signal).unwrap();
            let changed = unsafe { libc::prctl(libc::PR_SET_DUMPABLE, 0, 0, 0, 0) } == 0;
            child_socket.write_all(&[u8::from(changed)]).unwrap();
            child_socket.read_exact(&mut signal).ok();
            unsafe {
                libc::_exit(0);
            }
        }
        drop(child_socket);
        let mut address = [0_u8; size_of::<usize>()];
        parent_socket.read_exact(&mut address).unwrap();
        let mut notification = unsafe { std::mem::zeroed::<libc::seccomp_notif>() };
        notification.pid = child as u32;
        notification.data.nr = libc::SYS_openat as i32;
        notification.data.args[0] = libc::AT_FDCWD as u64;
        notification.data.args[1] = usize::from_ne_bytes(address) as u64;
        notification.data.args[2] = libc::O_RDONLY as u64;

        let decoded = decode_filesystem_notification(&notification).unwrap();
        assert_eq!(decoded.accesses[0].path, "/etc/hostname");
        parent_socket.write_all(&[1]).unwrap();
        let mut changed = [0_u8; 1];
        parent_socket.read_exact(&mut changed).unwrap();
        assert_eq!(changed, [1]);

        let response = authorized_open_response_for_notification(decoded.open.as_ref());
        kill_and_reap_child(child);

        assert!(matches!(
            response,
            Some(FilesystemNotificationResponse::AddFd { .. })
        ));
    }

    #[test]
    fn undecodable_notification_is_denied_without_authorization() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();
        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let landlock_plan =
            LandlockPlan::from_snapshot_for_filesystem_notifications(&snapshot).unwrap();
        let authorizer = FilesystemNotificationAuthorizer::new(&snapshot).unwrap();
        let mut notification = unsafe { std::mem::zeroed::<libc::seccomp_notif>() };
        notification.pid = std::process::id();
        notification.data.nr = libc::SYS_openat as i32;
        notification.data.args[0] = libc::AT_FDCWD as u64;
        notification.data.args[1] = 0;
        notification.data.args[2] = libc::O_RDONLY as u64;

        let response =
            filesystem_notification_response(&notification, &snapshot, &landlock_plan, &authorizer)
                .unwrap();

        assert!(matches!(
            response,
            FilesystemNotificationResponse::Deny(libc::EACCES)
        ));
    }
}
