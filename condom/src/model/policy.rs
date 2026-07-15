use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::auth::approvals::{command_app, ApprovalDecision, ApprovalKind, ApprovalStores};
use crate::model::config::{
    EventsConfig, ExecConfig, ExecutionMode, FilesystemConfig, NetworkConfig, PromptMode,
    ProxyConfig, ReviewConfig,
};
use crate::model::events::redact_command;
use crate::model::project::ProjectContext;
use crate::model::runtime_support::{path_is_blocked_by_patterns, resolve_executable_target};
use crate::model::state::StatePaths;

pub const POLICY_SNAPSHOT_SCHEMA_VERSION: u32 = 7;

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PolicySnapshot {
    pub schema_version: u32,
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
    pub project_id: String,
    pub project_root: String,
    pub mode: ExecutionMode,
    pub command: Vec<String>,
    pub configured_filesystem: FilesystemConfig,
    pub filesystem: ResolvedFilesystemPolicy,
    pub exec: ExecConfig,
    pub prompt: PromptPolicySnapshot,
    pub network: NetworkConfig,
    pub proxy: ProxyConfig,
    pub review: ReviewConfig,
    pub events: EventsConfig,
    pub allowed_loopback_ports: Vec<u16>,
    #[serde(default)]
    pub proxy_listen_port: Option<u16>,
    #[serde(default)]
    pub transparent_proxy: TransparentProxySnapshot,
    #[serde(skip)]
    pub path: PathBuf,
}

#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
#[serde(default, rename_all = "camelCase")]
pub struct TransparentProxySnapshot {
    pub enabled: bool,
    pub tcp_ports: Vec<u16>,
    pub allowed_hosts: Vec<String>,
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct NetworkMediationSnapshot {
    pub allowed_loopback_ports: Vec<u16>,
    pub proxy_listen_port: Option<u16>,
    pub transparent_proxy: TransparentProxySnapshot,
}

pub fn write_snapshot(
    project: &ProjectContext,
    state: &StatePaths,
    config: &crate::model::config::CondomConfig,
    mode: ExecutionMode,
    command: &[String],
    allowed_loopback_ports: &[u16],
) -> Result<PolicySnapshot> {
    write_snapshot_with_network(
        project,
        state,
        config,
        mode,
        command,
        NetworkMediationSnapshot {
            allowed_loopback_ports: allowed_loopback_ports.to_vec(),
            proxy_listen_port: None,
            transparent_proxy: TransparentProxySnapshot::default(),
        },
    )
}

pub fn write_snapshot_with_network(
    project: &ProjectContext,
    state: &StatePaths,
    config: &crate::model::config::CondomConfig,
    mode: ExecutionMode,
    command: &[String],
    network: NetworkMediationSnapshot,
) -> Result<PolicySnapshot> {
    fs::create_dir_all(&state.policy_dir)
        .with_context(|| format!("failed to create {}", state.policy_dir.display()))?;
    let id = Uuid::new_v4();
    let path = snapshot_path(state, id);
    let filesystem = resolve_filesystem_policy(project, state, config, command)?;
    let snapshot = PolicySnapshot {
        schema_version: POLICY_SNAPSHOT_SCHEMA_VERSION,
        id,
        created_at: Utc::now(),
        project_id: project.id.clone(),
        project_root: project.root.display().to_string(),
        mode,
        command: redact_command(command),
        configured_filesystem: config.filesystem.clone(),
        filesystem,
        exec: config.exec.clone(),
        prompt: PromptPolicySnapshot::from_config(config),
        network: config.network.clone(),
        proxy: config.proxy.clone(),
        review: config.review.clone(),
        events: config.events.clone(),
        allowed_loopback_ports: network.allowed_loopback_ports,
        proxy_listen_port: network.proxy_listen_port,
        transparent_proxy: network.transparent_proxy,
        path,
    };
    fs::write(&snapshot.path, serde_json::to_string_pretty(&snapshot)?)
        .with_context(|| format!("failed to write {}", snapshot.path.display()))?;
    Ok(snapshot)
}

pub fn snapshot_path(state: &StatePaths, id: Uuid) -> PathBuf {
    state.policy_dir.join(format!("{id}.json"))
}

pub fn network_mediation_required(_network: &NetworkConfig) -> bool {
    true
}

pub fn read_snapshot(path: &Path) -> Result<PolicySnapshot> {
    let content =
        fs::read_to_string(path).with_context(|| format!("failed to read {}", path.display()))?;
    let mut snapshot: PolicySnapshot = serde_json::from_str(&content)
        .with_context(|| format!("failed to parse {}", path.display()))?;
    if snapshot.schema_version != POLICY_SNAPSHOT_SCHEMA_VERSION {
        bail!(
            "unsupported policy snapshot schema version {}; expected {}",
            snapshot.schema_version,
            POLICY_SNAPSHOT_SCHEMA_VERSION
        );
    }
    snapshot.path = path.to_path_buf();
    Ok(snapshot)
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ResolvedFilesystemPolicy {
    pub allow_read: Vec<String>,
    pub allow_write: Vec<String>,
    pub allow_execute: Vec<String>,
    pub deny_read: Vec<String>,
    pub deny_write: Vec<String>,
    pub deny_execute: Vec<String>,
    #[serde(default)]
    pub redact_read: Vec<String>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PromptPolicySnapshot {
    pub mode: PromptMode,
    pub deny_without_approval_ui: bool,
    pub choices: Vec<PromptChoice>,
}

impl PromptPolicySnapshot {
    fn from_config(config: &crate::model::config::CondomConfig) -> Self {
        Self {
            mode: config.defaults.prompt_mode,
            deny_without_approval_ui: true,
            choices: vec![
                PromptChoice::DenyOnce,
                PromptChoice::AllowOnce,
                PromptChoice::AllowAppProject,
                PromptChoice::DenyAppProject,
                PromptChoice::AllowProject,
                PromptChoice::DenyProject,
            ],
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum PromptChoice {
    DenyOnce,
    AllowOnce,
    AllowAppProject,
    DenyAppProject,
    AllowProject,
    DenyProject,
}

pub fn resolve_filesystem_policy(
    project: &ProjectContext,
    state: &StatePaths,
    config: &crate::model::config::CondomConfig,
    command: &[String],
) -> Result<ResolvedFilesystemPolicy> {
    let path =
        std::env::var_os(crate::app::env::ORIGINAL_PATH_ENV).or_else(|| std::env::var_os("PATH"));
    resolve_filesystem_policy_with_path(project, state, config, command, path.as_deref())
}

fn resolve_filesystem_policy_with_path(
    project: &ProjectContext,
    state: &StatePaths,
    config: &crate::model::config::CondomConfig,
    command: &[String],
    path: Option<&OsStr>,
) -> Result<ResolvedFilesystemPolicy> {
    let project_root = path_string(&project.root);
    let runtime_dir = path_string(&state.runtime_dir);
    let stores = ApprovalStores::from_state(state);
    let read_approvals =
        filesystem_approval_rules(&stores, project, command, ApprovalKind::FsRead)?;
    let write_approvals =
        filesystem_approval_rules(&stores, project, command, ApprovalKind::FsWrite)?;
    let execute_approvals =
        filesystem_approval_rules(&stores, project, command, ApprovalKind::FsExec)?;

    let mut allow_read = vec![
        project_root.clone(),
        path_string(&state.xdg_state_dir),
        format!("{runtime_dir}/home"),
        format!("{runtime_dir}/tmp"),
        format!("{runtime_dir}/xdg"),
    ];
    let path_dirs = executable_search_paths(path);
    let executable_target = resolve_executable_target(command, path);
    extend_unique(&mut allow_read, path_dirs.clone());
    allow_read.extend(config.filesystem.allow_read.clone());
    allow_read.extend(read_approvals.allow);

    let mut allow_write = vec![
        project_root,
        path_string(&state.xdg_state_dir),
        format!("{runtime_dir}/home"),
        format!("{runtime_dir}/tmp"),
        format!("{runtime_dir}/xdg"),
    ];
    extend_unique(&mut allow_write, terminal_integration_write_paths());
    allow_write.extend(config.filesystem.allow_write.clone());
    allow_write.extend(write_approvals.allow);

    let mut allow_execute = config.filesystem.allow_execute.clone();
    extend_unique(&mut allow_execute, path_dirs);
    allow_execute.extend(execute_approvals.allow);

    let mut deny_read = config.filesystem.deny_read.clone();
    deny_read.extend(read_approvals.deny);

    let mut deny_write = internal_write_protection_paths(state);
    deny_write.extend(config.filesystem.deny_write.clone());
    deny_write.extend(write_approvals.deny);

    let deny_execute = execute_approvals.deny;
    if let Some(path) = executable_target {
        let blocked_read_patterns = deny_read.iter().chain(config.filesystem.redact_read.iter());
        if !path_is_blocked_by_patterns(&path, blocked_read_patterns.clone()) {
            push_unique(&mut allow_read, path.clone());
        }
        let blocked_execute_patterns = deny_execute
            .iter()
            .chain(deny_read.iter())
            .chain(config.filesystem.redact_read.iter());
        if !path_is_blocked_by_patterns(&path, blocked_execute_patterns.clone()) {
            push_unique(&mut allow_execute, path);
        }
    }

    Ok(ResolvedFilesystemPolicy {
        allow_read,
        allow_write,
        allow_execute,
        deny_read,
        deny_write,
        deny_execute,
        redact_read: config.filesystem.redact_read.clone(),
    })
}

fn terminal_integration_write_paths() -> Vec<String> {
    vec![format!("/tmp/tmux-{}", unsafe { libc::geteuid() })]
}

fn executable_search_paths(path: Option<&OsStr>) -> Vec<String> {
    let Some(path) = path else {
        return Vec::new();
    };
    let mut paths = Vec::new();
    for path in std::env::split_paths(path).filter(|path| path.is_absolute()) {
        push_unique(&mut paths, path.display().to_string());
    }
    paths
}

fn extend_unique(paths: &mut Vec<String>, additions: impl IntoIterator<Item = String>) {
    for path in additions {
        push_unique(paths, path);
    }
}

fn push_unique(paths: &mut Vec<String>, path: String) {
    if !paths.iter().any(|existing| existing == &path) {
        paths.push(path);
    }
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
struct FilesystemApprovalRules {
    allow: Vec<String>,
    deny: Vec<String>,
}

fn filesystem_approval_rules(
    store: &ApprovalStores,
    project: &ProjectContext,
    command: &[String],
    kind: ApprovalKind,
) -> Result<FilesystemApprovalRules> {
    let mut rules = FilesystemApprovalRules::default();
    let app = command_app(command);
    for (subject, decision) in
        store.resolve_active_decisions_for_app(project, app.as_deref(), kind)?
    {
        match decision {
            ApprovalDecision::Allow => rules.allow.push(subject),
            ApprovalDecision::Deny => rules.deny.push(subject),
        }
    }
    Ok(rules)
}

pub(crate) fn internal_write_protection_paths(state: &StatePaths) -> Vec<String> {
    let project_dir = path_string(&state.project_dir);
    let runtime_dir = path_string(&state.runtime_dir);
    let state_dir = path_string(&state.xdg_state_dir);
    vec![
        format!("{project_dir}/config.toml"),
        format!("{project_dir}/bin/**"),
        format!("{runtime_dir}/proxy-cache/**"),
        format!("{project_dir}/proxy-cache/**"),
        format!("{state_dir}/proxy-cache/**"),
    ]
}

fn path_string(path: &Path) -> String {
    path.display().to_string()
}

#[cfg(test)]
mod tests {
    use std::os::unix::fs::PermissionsExt;

    use super::*;
    use crate::auth::approvals::{Approval, ApprovalScope, ApprovalStore, NewApproval};
    use crate::model::config::{CondomConfig, ExecutionMode};

    #[test]
    fn network_mediation_is_always_required() {
        assert!(network_mediation_required(&NetworkConfig::default()));
    }

    #[test]
    fn writes_redacted_policy_snapshot() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"))
            .with_runtime_dir(temp.path().join("review-runtime/.condom"));
        let mut config = CondomConfig::default();
        config.exec.allow = vec!["cargo test".into()];
        config.exec.deny = vec!["cargo publish".into()];
        config.filesystem.redact_read = vec!["/run/secret/token".into()];

        let snapshot = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["npm".into(), "--token".into(), "secret".into()],
            &[32123],
        )
        .unwrap();

        assert!(snapshot.path.starts_with(&state.policy_dir));
        let value: serde_json::Value =
            serde_json::from_str(&fs::read_to_string(snapshot.path).unwrap()).unwrap();
        assert_eq!(value["schemaVersion"], POLICY_SNAPSHOT_SCHEMA_VERSION);
        assert_eq!(value["projectId"], "project-id");
        assert_eq!(value["mode"], serde_json::json!("run"));
        assert_eq!(
            value["command"],
            serde_json::json!(["npm", "--token", "<redacted>"])
        );
        assert_eq!(value["allowedLoopbackPorts"], serde_json::json!([32123]));
        assert_eq!(value["exec"]["allow"], serde_json::json!(["cargo test"]));
        assert_eq!(value["exec"]["deny"], serde_json::json!(["cargo publish"]));
        assert_eq!(value["prompt"]["mode"], serde_json::json!("tty"));
        assert_eq!(
            value["filesystem"]["redactRead"],
            serde_json::json!(["/run/secret/token"])
        );
        assert!(value["prompt"]["choices"]
            .as_array()
            .unwrap()
            .contains(&serde_json::json!("allow-app-project")));
    }

    #[test]
    fn executable_search_paths_keep_absolute_unique_entries() {
        let joined = std::env::join_paths([
            PathBuf::from("/home/me/.local/bin"),
            PathBuf::from("relative-bin"),
            PathBuf::from("/run/current-system/sw/bin"),
            PathBuf::from("/home/me/.local/bin"),
        ])
        .unwrap();

        assert_eq!(
            executable_search_paths(Some(joined.as_os_str())),
            vec![
                "/home/me/.local/bin".to_string(),
                "/run/current-system/sw/bin".to_string(),
            ]
        );
    }

    #[test]
    fn resolved_policy_limits_selected_executable_support_to_its_exact_target() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let bin = temp.path().join("bin");
        let install_dir = temp.path().join("tools/example");
        fs::create_dir_all(&bin).unwrap();
        fs::create_dir_all(&install_dir).unwrap();
        let target = install_dir.join("tool");
        fs::write(&target, "#!/bin/sh\n").unwrap();
        fs::set_permissions(&target, fs::Permissions::from_mode(0o755)).unwrap();
        std::os::unix::fs::symlink(&target, bin.join("tool")).unwrap();
        let path = std::env::join_paths([&bin]).unwrap();

        let policy = resolve_filesystem_policy_with_path(
            &project,
            &state,
            &CondomConfig::default(),
            &["tool".into(), "--help".into()],
            Some(path.as_os_str()),
        )
        .unwrap();
        let target = target.display().to_string();

        assert!(policy.allow_read.contains(&target));
        assert!(policy.allow_execute.contains(&target));
        assert!(!policy
            .allow_read
            .contains(&install_dir.display().to_string()));
        assert!(!policy
            .allow_execute
            .contains(&install_dir.display().to_string()));
        assert!(!policy
            .allow_write
            .contains(&install_dir.display().to_string()));
    }

    #[test]
    fn selected_executable_target_does_not_override_read_protection() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let bin = temp.path().join("bin");
        let install_dir = temp.path().join("tools/example");
        fs::create_dir_all(&bin).unwrap();
        fs::create_dir_all(&install_dir).unwrap();
        let target = install_dir.join("tool");
        fs::write(&target, "#!/bin/sh\n").unwrap();
        fs::set_permissions(&target, fs::Permissions::from_mode(0o755)).unwrap();
        std::os::unix::fs::symlink(&target, bin.join("tool")).unwrap();
        let path = std::env::join_paths([&bin]).unwrap();
        let mut config = CondomConfig::default();
        config.filesystem.deny_read = vec![target.display().to_string()];

        let policy = resolve_filesystem_policy_with_path(
            &project,
            &state,
            &config,
            &["tool".into()],
            Some(path.as_os_str()),
        )
        .unwrap();

        let target = target.display().to_string();
        assert!(!policy.allow_read.contains(&target));
        assert!(!policy.allow_execute.contains(&target));
    }

    #[test]
    fn internal_write_protections_are_limited_to_condom_owned_paths() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));

        assert_eq!(
            internal_write_protection_paths(&state),
            vec![
                format!("{}/config.toml", state.project_dir.display()),
                format!("{}/bin/**", state.project_dir.display()),
                format!("{}/proxy-cache/**", state.runtime_dir.display()),
                format!("{}/proxy-cache/**", state.project_dir.display()),
                format!("{}/proxy-cache/**", state.xdg_state_dir.display()),
            ]
        );
    }

    #[test]
    fn resolved_filesystem_policy_has_no_builtin_host_read_support_paths() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();

        let policy =
            resolve_filesystem_policy(&project, &state, &config, &["tool".into()]).unwrap();

        assert!(policy
            .allow_read
            .contains(&state.xdg_state_dir.display().to_string()));
        assert!(policy
            .allow_write
            .contains(&state.xdg_state_dir.display().to_string()));
        assert!(!policy.allow_read.iter().any(|path| path == "/tmp"));
        assert!(!policy.allow_read.iter().any(|path| path == "/etc/profile"));
        assert!(!policy.allow_read.iter().any(|path| path == "/etc/gai.conf"));
        assert!(!policy.allow_read.iter().any(|path| path == "/etc/passwd"));
        assert!(!policy.allow_read.iter().any(|path| path == "/etc/xdg"));
        for path in terminal_integration_write_paths() {
            assert!(policy.allow_write.iter().any(|allowed| allowed == &path));
        }
        assert!(!policy
            .allow_read
            .iter()
            .any(|path| path == "/sys/fs/cgroup"));
        assert!(!policy
            .allow_read
            .iter()
            .any(|path| path == "/sys/devices/system/cpu"));
    }

    #[test]
    fn snapshots_resolved_filesystem_policy_and_consumes_once_approvals() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let store = ApprovalStore::new(state.approvals_file.clone());
        for approval in [
            NewApproval {
                decision: ApprovalDecision::Allow,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsRead,
                subject: "/opt/sdk".into(),
                ttl: None,
                once: true,
                reason: None,
            },
            NewApproval {
                decision: ApprovalDecision::Allow,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsRead,
                subject: "~/.ssh/**".into(),
                ttl: None,
                once: false,
                reason: None,
            },
            NewApproval {
                decision: ApprovalDecision::Allow,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsRead,
                subject: "/tmp/blocked".into(),
                ttl: None,
                once: false,
                reason: None,
            },
            NewApproval {
                decision: ApprovalDecision::Deny,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsRead,
                subject: "/tmp/blocked".into(),
                ttl: None,
                once: false,
                reason: None,
            },
            NewApproval {
                decision: ApprovalDecision::Deny,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsWrite,
                subject: "/tmp/cache".into(),
                ttl: None,
                once: false,
                reason: None,
            },
            NewApproval {
                decision: ApprovalDecision::Deny,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsExec,
                subject: "/opt/tool/bin/tool".into(),
                ttl: None,
                once: false,
                reason: None,
            },
        ] {
            store
                .add(Approval::new(&project, approval).unwrap())
                .unwrap();
        }

        let mut config = CondomConfig::default();
        config.filesystem.allow_write = vec!["/var/tmp/project-cache".into()];
        config.filesystem.deny_read = vec!["/mnt/private/**".into()];
        config.filesystem.redact_read = vec!["/run/secret/token".into()];
        let first = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["npm".into(), "install".into()],
            &[],
        )
        .unwrap();
        let second = write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["npm".into(), "test".into()],
            &[],
        )
        .unwrap();

        assert!(first.filesystem.allow_read.contains(&"/opt/sdk".into()));
        assert!(first.filesystem.allow_read.contains(&"~/.ssh/**".into()));
        assert!(first
            .filesystem
            .allow_write
            .contains(&"/var/tmp/project-cache".into()));
        assert!(first
            .filesystem
            .deny_read
            .contains(&"/mnt/private/**".into()));
        assert_eq!(first.filesystem.redact_read, vec!["/run/secret/token"]);
        assert!(first.filesystem.deny_read.contains(&"/tmp/blocked".into()));
        assert!(first.filesystem.deny_write.contains(&"/tmp/cache".into()));
        assert!(first
            .filesystem
            .deny_write
            .contains(&format!("{}/proxy-cache/**", state.runtime_dir.display())));
        assert!(first
            .filesystem
            .deny_write
            .contains(&format!("{}/proxy-cache/**", state.project_dir.display())));
        assert!(first
            .filesystem
            .deny_write
            .contains(&format!("{}/proxy-cache/**", state.xdg_state_dir.display())));
        assert!(first
            .filesystem
            .deny_execute
            .contains(&"/opt/tool/bin/tool".into()));
        assert!(!second.filesystem.allow_read.contains(&"/opt/sdk".into()));
    }

    #[test]
    fn default_filesystem_policy_has_no_builtin_read_denies() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();

        let policy =
            resolve_filesystem_policy(&project, &state, &config, &["tool".into()]).unwrap();

        assert!(policy.deny_read.is_empty());
    }
}
