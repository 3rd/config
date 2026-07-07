use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{bail, Context, Result};
use serde_json::{json, Value};

use crate::app::env::{current_environment, sanitized_environment};
use crate::app::helper;
use crate::kernel::seccomp;
use crate::model::config::{CondomConfig, ExecutionMode, PromptMode};
use crate::model::events::{Event, EventLog};
use crate::model::policy::{self, PolicySnapshot};
use crate::model::project::ProjectContext;
use crate::model::state::StatePaths;
use crate::sandbox::landlock;

const REQUIRED_FENCE_FLAGS: &[&str] = &["-m", "--fence-log-file", "--settings", "--shell"];

pub(crate) struct FenceRunOptions<'a> {
    pub extra_env: &'a BTreeMap<String, String>,
    pub policy_snapshot: &'a PolicySnapshot,
    pub runner_path: Option<&'a Path>,
    pub runtime_path: Option<&'a str>,
}

pub(crate) fn run_with_fence_env(
    project: &ProjectContext,
    state: &StatePaths,
    config: &CondomConfig,
    mode: ExecutionMode,
    command: &[String],
    event_log: &EventLog,
    options: FenceRunOptions<'_>,
) -> Result<i32> {
    ensure_runtime_dirs(state)?;
    run_prepared_with_fence_env(project, state, config, mode, command, event_log, options)
}

pub(crate) fn run_prepared_with_fence_env(
    project: &ProjectContext,
    state: &StatePaths,
    config: &CondomConfig,
    mode: ExecutionMode,
    command: &[String],
    event_log: &EventLog,
    options: FenceRunOptions<'_>,
) -> Result<i32> {
    ensure_runtime_dirs(state)?;
    ensure_fence_capabilities()?;
    let settings_path = write_settings(state, mode, options.policy_snapshot, options.runner_path)?;
    let log_path = create_log_file(state, mode)?;
    if config.events.require_logging {
        event_log.append(&Event::runtime_started(project, mode, command))?;
    }

    let source_env = current_environment();
    let mut env = sanitized_environment(&source_env, mode, project, state, &config.environment);
    env.extend(options.extra_env.clone());
    if std::env::var_os(helper::DISABLE_HELPER_REENTRY_ENV).is_some() {
        env.insert(helper::DISABLE_HELPER_REENTRY_ENV.into(), "1".into());
    }
    env.insert(
        "CONDOM_POLICY_SNAPSHOT_ID".into(),
        options.policy_snapshot.id.to_string(),
    );
    env.insert(
        "CONDOM_POLICY_SNAPSHOT".into(),
        options.policy_snapshot.path.display().to_string(),
    );
    let runtime_path = options
        .runtime_path
        .or_else(|| env.get("PATH").map(String::as_str));
    let interactive_pty = stdio_is_tty();
    let landlocked_command = if let Some(runner_path) = options.runner_path {
        if interactive_pty {
            landlock::wrap_interactive_command_with_runner_path(
                runner_path,
                options.policy_snapshot,
                command,
                runtime_path,
            )
        } else {
            landlock::wrap_command_with_runner_path(
                runner_path,
                options.policy_snapshot,
                command,
                runtime_path,
            )
        }
    } else {
        if interactive_pty {
            landlock::wrap_interactive_command_path(options.policy_snapshot, command, runtime_path)
        } else {
            landlock::wrap_command_path(options.policy_snapshot, command, runtime_path)
        }
    }
    .context("failed to prepare Landlock command wrapper")?;
    let mut fence_command = Command::new("fence");
    fence_command
        .current_dir(&project.root)
        .arg("-m")
        .arg("--shell")
        .arg("default")
        .arg("--fence-log-file")
        .arg(&log_path)
        .arg("--settings")
        .arg(&settings_path);
    fence_command
        .arg("--")
        .args(&landlocked_command)
        .env_clear()
        .envs(env);
    seccomp::install_socket_filter(
        &mut fence_command,
        seccomp::SocketFilterPolicy {
            deny_internet_udp: policy::network_mediation_required(&options.policy_snapshot.network),
        },
    );
    let status = fence_command.status().context("failed to start fence")?;
    let code = status.code().unwrap_or(1);

    if config.events.require_logging {
        event_log.append(&Event::runtime_finished(project, mode, command, code))?;
    }
    Ok(code)
}

pub fn inspect_capabilities() -> Result<()> {
    let output = Command::new("fence")
        .arg("--help")
        .output()
        .context("failed to inspect fence capabilities")?;
    let help = format!(
        "{}\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let missing = missing_capabilities(&help);
    if !missing.is_empty() {
        bail!(
            "fence is missing required capabilities: {}",
            missing.join(", ")
        );
    }
    Ok(())
}

pub fn missing_capabilities(help: &str) -> Vec<&'static str> {
    REQUIRED_FENCE_FLAGS
        .iter()
        .copied()
        .filter(|flag| !help.contains(flag))
        .collect()
}

fn ensure_fence_capabilities() -> Result<()> {
    inspect_capabilities().context("fence is required for run enforcement; refusing execution")
}

fn stdio_is_tty() -> bool {
    unsafe { libc::isatty(libc::STDIN_FILENO) == 1 && libc::isatty(libc::STDOUT_FILENO) == 1 }
}

fn write_settings(
    state: &StatePaths,
    mode: ExecutionMode,
    policy_snapshot: &PolicySnapshot,
    runner_path: Option<&Path>,
) -> Result<PathBuf> {
    state.ensure_state_dir()?;
    let path = state.xdg_state_dir.join(format!(
        "{}-{}-fence.json",
        mode.as_str(),
        std::process::id()
    ));
    let settings = render_settings_from_snapshot(policy_snapshot, runner_path);
    fs::write(&path, serde_json::to_string_pretty(&settings)?)
        .with_context(|| format!("failed to write {}", path.display()))?;
    Ok(path)
}

#[cfg(test)]
fn render_settings(policy_snapshot: &PolicySnapshot) -> Value {
    render_settings_from_snapshot(policy_snapshot, None)
}

fn render_settings_from_snapshot(
    policy_snapshot: &PolicySnapshot,
    runner_path: Option<&Path>,
) -> Value {
    let allow_loopback = policy_snapshot.network.allow_loopback;
    let proxy_running = !policy_snapshot.allowed_loopback_ports.is_empty();
    let allowed_domains = if policy_snapshot.proxy_listen_port.is_some() {
        Vec::new()
    } else if proxy_running && policy_snapshot.prompt.mode != PromptMode::Deny {
        vec!["*".into()]
    } else if proxy_running {
        proxy_allowed_hosts(policy_snapshot)
    } else {
        Vec::new()
    };
    let mut allow_read = policy_snapshot.filesystem.allow_read.clone();
    allow_read.extend(landlock::fence_support_read_paths(
        policy_snapshot,
        runner_path,
    ));
    // Fence owns mount visibility; the hidden runner owns the path decision.
    // Exposing `/` lets seccomp/Landlock prompt or deny unknown paths instead
    // of hiding them before the runner can inspect the syscall.
    allow_read.push("/".into());
    let mut allow_write = policy_snapshot.filesystem.allow_write.clone();
    allow_write.push("/".into());
    let mut allow_execute = policy_snapshot.filesystem.allow_execute.clone();
    allow_execute.extend(landlock::fence_support_execute_paths());
    allow_execute.push("/".into());
    let deny_read = policy_snapshot.filesystem.deny_read.clone();
    // Parent-side ptrace mediation conflicts with Fence runtime exec monitors.
    let mut network = json!({
        "allowedDomains": allowed_domains,
        "allowLocalBinding": allow_loopback,
        "allowLocalOutbound": allow_loopback,
        "allowLocalOutboundPorts": policy_snapshot.allowed_loopback_ports.clone()
    });
    if let Some(port) = policy_snapshot.proxy_listen_port {
        network["defaultAction"] = json!("proxy");
        network["upstreamProxy"] = json!(format!("http://127.0.0.1:{port}"));
    }
    json!({
        "network": network,
        "filesystem": {
            "defaultDenyRead": true,
            "allowRead": allow_read,
            "allowWrite": allow_write,
            "allowExecute": allow_execute,
            "denyRead": deny_read,
            "denyWrite": policy_snapshot.filesystem.deny_write.clone()
        },
        "devices": {
            "mode": "minimal"
        },
        "command": {
            "runtimeExecPolicy": "path",
            "useDefaults": false,
            "allow": [],
            "deny": []
        }
    })
}

fn proxy_allowed_hosts(policy_snapshot: &PolicySnapshot) -> Vec<String> {
    let mut hosts = policy_snapshot.proxy.allowed_hosts.clone();
    hosts.sort();
    hosts.dedup();
    hosts
}

fn ensure_runtime_dirs(state: &StatePaths) -> Result<()> {
    for path in [
        state.runtime_dir.join("home"),
        state.runtime_dir.join("tmp"),
        state.runtime_dir.join("xdg/cache"),
        state.runtime_dir.join("xdg/config"),
        state.runtime_dir.join("xdg/data"),
        state.runtime_dir.join("xdg/state"),
    ] {
        fs::create_dir_all(&path)
            .with_context(|| format!("failed to create {}", path.display()))?;
    }
    state.ensure_state_dir()
}

fn create_log_file(state: &StatePaths, mode: ExecutionMode) -> Result<PathBuf> {
    state.ensure_state_dir()?;
    let path = state.xdg_state_dir.join(format!(
        "{}-{}-fence.log",
        mode.as_str(),
        std::process::id()
    ));
    fs::OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(&path)
        .with_context(|| format!("failed to create {}", path.display()))?;
    Ok(path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::auth::approvals::{
        Approval, ApprovalDecision, ApprovalKind, ApprovalScope, ApprovalStore, NewApproval,
    };
    use crate::model::policy::{
        resolve_filesystem_policy, PolicySnapshot, PromptChoice, PromptPolicySnapshot,
        TransparentProxySnapshot, POLICY_SNAPSHOT_SCHEMA_VERSION,
    };
    use chrono::Utc;
    use uuid::Uuid;

    fn project() -> ProjectContext {
        ProjectContext::from_root(PathBuf::from("/tmp/app")).unwrap()
    }

    fn state() -> StatePaths {
        StatePaths::from_base(&project(), &PathBuf::from("/tmp/state"))
    }

    fn snapshot(
        project: &ProjectContext,
        state: &StatePaths,
        config: &CondomConfig,
        mode: ExecutionMode,
        ports: Vec<u16>,
    ) -> PolicySnapshot {
        PolicySnapshot {
            schema_version: POLICY_SNAPSHOT_SCHEMA_VERSION,
            id: Uuid::nil(),
            created_at: Utc::now(),
            project_id: project.id.clone(),
            project_root: project.root.display().to_string(),
            mode,
            command: Vec::new(),
            configured_filesystem: config.filesystem.clone(),
            filesystem: resolve_filesystem_policy(project, state, config, &[]).unwrap(),
            exec: config.exec.clone(),
            prompt: PromptPolicySnapshot {
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
            },
            network: config.network.clone(),
            proxy: config.proxy.clone(),
            review: config.review.clone(),
            events: config.events.clone(),
            allowed_loopback_ports: ports,
            proxy_listen_port: None,
            transparent_proxy: TransparentProxySnapshot::default(),
            path: state.policy_dir.join("test-policy.json"),
        }
    }

    #[test]
    fn detects_missing_fence_capability_flags() {
        assert_eq!(
            missing_capabilities("usage: fence -m --settings CONFIG --shell user"),
            vec!["--fence-log-file"]
        );
        assert!(missing_capabilities(
            "usage: fence -m --settings CONFIG --fence-log-file LOG --shell user"
        )
        .is_empty());
    }

    #[test]
    fn rendered_settings_allow_project_writes_and_protect_condom_metadata() {
        let project = project();
        let state = state();
        let config = CondomConfig::default();
        let policy_snapshot = snapshot(&project, &state, &config, ExecutionMode::Run, Vec::new());
        let settings = render_settings(&policy_snapshot);

        assert!(settings["filesystem"]["allowWrite"]
            .as_array()
            .unwrap()
            .contains(&json!("/tmp/app")));
        assert!(settings["filesystem"]["denyWrite"]
            .as_array()
            .unwrap()
            .contains(&json!("/tmp/app/.condom/config.toml")));
        assert!(policy_snapshot.exec.deny.is_empty());
        assert_eq!(settings["command"]["deny"], json!([]));
        assert_eq!(settings["command"]["useDefaults"], json!(false));
    }

    #[test]
    fn rendered_settings_include_configured_exec_policy() {
        let mut config = CondomConfig::default();
        config.exec.allow = vec!["cargo test".into()];
        config.exec.deny = vec!["cargo publish".into(), "gh secret".into()];
        let project = project();
        let state = state();
        let policy_snapshot = snapshot(&project, &state, &config, ExecutionMode::Run, Vec::new());
        let settings = render_settings(&policy_snapshot);

        assert_eq!(policy_snapshot.exec.allow, vec!["cargo test"]);
        assert_eq!(
            policy_snapshot.exec.deny,
            vec!["cargo publish", "gh secret"]
        );
        assert_eq!(settings["command"]["allow"], json!([]));
        assert_eq!(settings["command"]["deny"], json!([]));
        assert_eq!(settings["command"]["useDefaults"], json!(false));
    }

    #[test]
    fn rendered_settings_include_proxy_loopback_ports() {
        let project = project();
        let state = state();
        let config = CondomConfig::default();
        let mut policy_snapshot = snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            vec![1080, 3128, 32123],
        );
        policy_snapshot.proxy_listen_port = Some(32123);
        let settings = render_settings(&policy_snapshot);

        assert_eq!(settings["network"]["allowLocalOutbound"], json!(true));
        assert_eq!(
            settings["network"]["allowLocalOutboundPorts"],
            json!([1080, 3128, 32123])
        );
        assert_eq!(settings["network"]["allowedDomains"], json!([]));
        assert_eq!(settings["network"]["defaultAction"], json!("proxy"));
        assert_eq!(
            settings["network"]["upstreamProxy"],
            json!("http://127.0.0.1:32123")
        );
    }

    #[test]
    fn rendered_settings_allow_proxy_domains_to_reach_prompting_proxy() {
        let project = project();
        let state = state();
        let mut config = CondomConfig::default();
        config.proxy.allowed_hosts = vec![
            "registry.example.test".into(),
            "*.packages.example.test".into(),
        ];
        let mut policy_snapshot = snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            vec![1080, 3128, 15080],
        );
        policy_snapshot.proxy_listen_port = Some(15080);
        policy_snapshot.transparent_proxy = TransparentProxySnapshot {
            enabled: true,
            tcp_ports: vec![80, 443],
            allowed_hosts: config.proxy.allowed_hosts.clone(),
        };
        let settings = render_settings(&policy_snapshot);

        assert_eq!(settings["network"]["allowedDomains"], json!([]));
        assert_eq!(settings["network"]["defaultAction"], json!("proxy"));
        assert_eq!(
            settings["network"]["upstreamProxy"],
            json!("http://127.0.0.1:15080")
        );
    }

    #[test]
    fn rendered_settings_limit_proxy_domains_when_prompt_mode_denies() {
        let project = project();
        let state = state();
        let mut config = CondomConfig::default();
        config.defaults.prompt_mode = PromptMode::Deny;
        config.proxy.allowed_hosts = vec![
            "registry.example.test".into(),
            "*.packages.example.test".into(),
        ];
        let mut policy_snapshot = snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            vec![1080, 3128, 15080],
        );
        policy_snapshot.proxy_listen_port = Some(15080);
        policy_snapshot.transparent_proxy = TransparentProxySnapshot {
            enabled: true,
            tcp_ports: vec![80, 443],
            allowed_hosts: config.proxy.allowed_hosts.clone(),
        };
        let settings = render_settings(&policy_snapshot);

        assert_eq!(settings["network"]["allowedDomains"], json!([]));
        assert_eq!(settings["network"]["defaultAction"], json!("proxy"));
        assert_eq!(
            settings["network"]["upstreamProxy"],
            json!("http://127.0.0.1:15080")
        );
    }

    #[test]
    fn rendered_settings_include_active_filesystem_approvals() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let store = ApprovalStore::new(state.approvals_file.clone());
        for approval in [
            crate::auth::approvals::NewApproval {
                decision: ApprovalDecision::Allow,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsRead,
                subject: "/opt/sdk".into(),
                ttl: None,
                once: false,
                reason: None,
            },
            crate::auth::approvals::NewApproval {
                decision: ApprovalDecision::Allow,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsWrite,
                subject: "/tmp/cache".into(),
                ttl: None,
                once: false,
                reason: None,
            },
            crate::auth::approvals::NewApproval {
                decision: ApprovalDecision::Allow,
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
        let config = CondomConfig::default();
        let policy_snapshot = snapshot(&project, &state, &config, ExecutionMode::Run, Vec::new());
        let settings = render_settings(&policy_snapshot);

        assert!(settings["filesystem"]["allowRead"]
            .as_array()
            .unwrap()
            .contains(&json!("/opt/sdk")));
        assert!(settings["filesystem"]["allowWrite"]
            .as_array()
            .unwrap()
            .contains(&json!("/tmp/cache")));
        assert!(settings["filesystem"]["allowExecute"]
            .as_array()
            .unwrap()
            .contains(&json!("/opt/tool/bin/tool")));
    }

    #[test]
    fn rendered_settings_include_configured_filesystem_policy() {
        let mut config = CondomConfig::default();
        config.filesystem.allow_read = vec!["/opt/sdk".into()];
        config.filesystem.allow_write = vec!["/tmp/cache".into()];
        config.filesystem.allow_execute = vec!["/opt/tool/bin/tool".into()];
        config.filesystem.deny_read = vec!["/mnt/private/**".into()];
        config.filesystem.deny_write = vec!["/tmp/cache/secrets/**".into()];
        let project = project();
        let state = state();
        let policy_snapshot = snapshot(&project, &state, &config, ExecutionMode::Run, Vec::new());
        let settings = render_settings(&policy_snapshot);

        assert!(settings["filesystem"]["allowRead"]
            .as_array()
            .unwrap()
            .contains(&json!("/opt/sdk")));
        assert!(settings["filesystem"]["allowRead"]
            .as_array()
            .unwrap()
            .contains(&json!("/")));
        assert!(settings["filesystem"]["allowWrite"]
            .as_array()
            .unwrap()
            .contains(&json!("/tmp/cache")));
        assert!(settings["filesystem"]["allowWrite"]
            .as_array()
            .unwrap()
            .contains(&json!("/")));
        assert!(settings["filesystem"]["allowExecute"]
            .as_array()
            .unwrap()
            .contains(&json!("/opt/tool/bin/tool")));
        assert!(settings["filesystem"]["allowExecute"]
            .as_array()
            .unwrap()
            .contains(&json!("/")));
        assert!(settings["filesystem"]["denyRead"]
            .as_array()
            .unwrap()
            .contains(&json!("/mnt/private/**")));
        assert!(settings["filesystem"]["denyWrite"]
            .as_array()
            .unwrap()
            .contains(&json!("/tmp/cache/secrets/**")));
        assert!(settings["filesystem"]["denyWrite"]
            .as_array()
            .unwrap()
            .contains(&json!("/tmp/app/.condom/config.toml")));
    }

    #[test]
    fn filesystem_approvals_consume_once_and_keep_later_deny_precedence() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let store = ApprovalStore::new(state.approvals_file.clone());
        for approval in [
            crate::auth::approvals::NewApproval {
                decision: ApprovalDecision::Allow,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsRead,
                subject: "/tmp/once".into(),
                ttl: None,
                once: true,
                reason: None,
            },
            crate::auth::approvals::NewApproval {
                decision: ApprovalDecision::Allow,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsRead,
                subject: "/tmp/blocked".into(),
                ttl: None,
                once: false,
                reason: None,
            },
            crate::auth::approvals::NewApproval {
                decision: ApprovalDecision::Deny,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsRead,
                subject: "/tmp/blocked".into(),
                ttl: None,
                once: false,
                reason: None,
            },
        ] {
            store
                .add(Approval::new(&project, approval).unwrap())
                .unwrap();
        }

        let config = CondomConfig::default();
        let first = snapshot(&project, &state, &config, ExecutionMode::Run, Vec::new());
        let second = snapshot(&project, &state, &config, ExecutionMode::Run, Vec::new());

        assert!(first.filesystem.allow_read.contains(&"/tmp/once".into()));
        assert!(!first.filesystem.allow_read.contains(&"/tmp/blocked".into()));
        assert!(first.filesystem.deny_read.contains(&"/tmp/blocked".into()));
        assert!(!second.filesystem.allow_read.contains(&"/tmp/once".into()));
    }

    #[test]
    fn filesystem_read_approvals_are_rendered_without_builtin_read_denies() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let store = ApprovalStore::new(state.approvals_file.clone());
        store
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::FsRead,
                        subject: "~/.ssh/**".into(),
                        ttl: None,
                        once: false,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();
        let config = CondomConfig::default();
        let policy_snapshot = snapshot(&project, &state, &config, ExecutionMode::Run, Vec::new());
        let settings = render_settings(&policy_snapshot);

        assert!(settings["filesystem"]["allowRead"]
            .as_array()
            .unwrap()
            .contains(&json!("~/.ssh/**")));
        assert!(!settings["filesystem"]["denyRead"]
            .as_array()
            .unwrap()
            .contains(&json!("~/.ssh/**")));
    }
}
