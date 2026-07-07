use std::fs;
use std::os::unix::fs::{FileTypeExt, PermissionsExt};
use std::path::Path;
use std::process::Command;

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};

use crate::app::helper::{self, HelperProbe};
use crate::auth::approvals::{ApprovalDecision, ApprovalKind};
use crate::auth::prompt;
use crate::model::config::{CondomConfig, ExecutionMode};
use crate::model::policy::{self, NetworkMediationSnapshot, TransparentProxySnapshot};
use crate::model::project::ProjectContext;
use crate::model::state::StatePaths;
use crate::sandbox::capture::{self, CaptureProbe};
use crate::sandbox::fence;

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum CheckStatus {
    Pass,
    Warn,
    Fail,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DoctorCheck {
    pub name: String,
    pub status: CheckStatus,
    pub message: String,
}

pub fn checks(
    project: &ProjectContext,
    state: &StatePaths,
    config: &CondomConfig,
) -> Vec<DoctorCheck> {
    let mut checks = Vec::new();
    checks.push(DoctorCheck {
        name: "project-config".into(),
        status: if state.project_config.exists() {
            CheckStatus::Pass
        } else {
            CheckStatus::Warn
        },
        message: if state.project_config.exists() {
            format!("loaded {}", state.project_config.display())
        } else {
            "project config is missing; run condom init".into()
        },
    });
    checks.push(DoctorCheck {
        name: "typed-config".into(),
        status: CheckStatus::Pass,
        message: format!("{} shim routes configured", config.shims.len()),
    });
    checks.push(DoctorCheck {
        name: "project-id".into(),
        status: CheckStatus::Pass,
        message: format!("{} for {}", project.id, project.root.display()),
    });
    checks.push(match fence::inspect_capabilities() {
        Ok(()) => DoctorCheck {
            name: "fence-backend".into(),
            status: CheckStatus::Pass,
            message: "fence is available for the current run backend".into(),
        },
        Err(error) => DoctorCheck {
            name: "fence-backend".into(),
            status: CheckStatus::Fail,
            message: format!("{error:#}"),
        },
    });
    let helper_probe = helper::probe_configured_helper();
    checks.push(helper_protocol_check(helper_probe.clone()));
    checks.push(helper_capabilities_check(helper_probe.clone()));
    checks.push(network_enforcement_check(helper_probe.clone()));
    checks.push(filesystem_approval_prompt_check());
    checks.push(filesystem_approval_gui_check());
    checks.push(filesystem_approval_mediation_check(&helper_probe));
    checks.push(capture_check(capture::probe_configured_capture_backend()));
    checks
}

fn filesystem_approval_prompt_check() -> DoctorCheck {
    match prompt::approval_prompt_readiness() {
        Ok(message) => DoctorCheck {
            name: "filesystem-approval-prompt".into(),
            status: CheckStatus::Pass,
            message,
        },
        Err(message) => DoctorCheck {
            name: "filesystem-approval-prompt".into(),
            status: CheckStatus::Fail,
            message,
        },
    }
}

fn filesystem_approval_gui_check() -> DoctorCheck {
    filesystem_approval_gui_check_from_readiness(prompt::approval_gui_readiness())
}

fn filesystem_approval_gui_check_from_readiness(
    readiness: std::result::Result<String, String>,
) -> DoctorCheck {
    match readiness {
        Ok(message) => DoctorCheck {
            name: "filesystem-approval-gui".into(),
            status: CheckStatus::Pass,
            message,
        },
        Err(message) if message == "desktop display is not configured" => DoctorCheck {
            name: "filesystem-approval-gui".into(),
            status: CheckStatus::Warn,
            message: "desktop display is not configured; terminal approval fallback is required"
                .into(),
        },
        Err(message) => DoctorCheck {
            name: "filesystem-approval-gui".into(),
            status: CheckStatus::Fail,
            message,
        },
    }
}

fn filesystem_approval_mediation_check(helper_probe: &HelperProbe) -> DoctorCheck {
    let helper_endpoint = helper_authorization_endpoint(helper_probe);
    match filesystem_approval_mediation_probe(helper_endpoint.as_ref()) {
        Ok(()) => DoctorCheck {
            name: "filesystem-approval-mediation".into(),
            status: CheckStatus::Pass,
            message: "filesystem approval mediation can authorize host reads".into(),
        },
        Err(error) => DoctorCheck {
            name: "filesystem-approval-mediation".into(),
            status: CheckStatus::Fail,
            message: format!("filesystem approval mediation failed: {error:#}"),
        },
    }
}

fn helper_authorization_endpoint(probe: &HelperProbe) -> Option<helper::HelperEndpoint> {
    let HelperProbe::Ready { path, .. } = probe else {
        return None;
    };
    if std::env::var_os(helper::HELPER_SOCKET_ENV).is_some() {
        return Some(helper::HelperEndpoint::Socket(path.clone()));
    }
    if std::env::var_os(helper::HELPER_ENV).is_some() {
        return Some(helper::HelperEndpoint::Binary(path.clone()));
    }
    let Ok(metadata) = fs::metadata(path) else {
        return Some(helper::HelperEndpoint::Binary(path.clone()));
    };
    if metadata.file_type().is_socket() {
        Some(helper::HelperEndpoint::Socket(path.clone()))
    } else {
        Some(helper::HelperEndpoint::Binary(path.clone()))
    }
}

fn filesystem_approval_mediation_probe(
    helper_endpoint: Option<&helper::HelperEndpoint>,
) -> Result<()> {
    let base = std::env::temp_dir().join(format!(
        "condom-doctor-fs-{}-{}",
        std::process::id(),
        uuid::Uuid::new_v4()
    ));
    let result = filesystem_approval_mediation_probe_in(&base, helper_endpoint);
    if let Err(error) = fs::remove_dir_all(&base) {
        crate::debug_log!("failed to remove doctor filesystem probe dir: {error}");
    }
    result
}

fn filesystem_approval_mediation_probe_in(
    base: &Path,
    helper_endpoint: Option<&helper::HelperEndpoint>,
) -> Result<()> {
    let project_root = base.join("project");
    let state_root = base.join("state");
    let prompt_bin = base.join("prompt-bin");
    fs::create_dir_all(&project_root)
        .with_context(|| format!("failed to create {}", project_root.display()))?;
    fs::create_dir_all(&prompt_bin)
        .with_context(|| format!("failed to create {}", prompt_bin.display()))?;
    let host_file = base.join("host-secret.txt");
    fs::write(&host_file, "doctor host read")
        .with_context(|| format!("failed to write {}", host_file.display()))?;
    let approval = prompt_bin.join("condom-approval");
    fs::write(&approval, "#!/bin/sh\nprintf '%s\\n' o\n")
        .with_context(|| format!("failed to write {}", approval.display()))?;
    fs::set_permissions(&approval, fs::Permissions::from_mode(0o755))
        .with_context(|| format!("failed to chmod {}", approval.display()))?;

    let project = ProjectContext::from_root(project_root)?;
    let state = StatePaths::from_base(&project, &state_root);
    let config = CondomConfig::default();
    let command = vec!["cat".into(), host_file.display().to_string()];
    let snapshot = policy::write_snapshot_with_network(
        &project,
        &state,
        &config,
        ExecutionMode::Run,
        &command,
        NetworkMediationSnapshot {
            allowed_loopback_ports: Vec::new(),
            proxy_listen_port: None,
            transparent_proxy: TransparentProxySnapshot {
                enabled: false,
                tcp_ports: Vec::new(),
                allowed_hosts: Vec::new(),
            },
        },
    )?;
    if let Some(helper_endpoint) = helper_endpoint {
        return helper_filesystem_authorization_probe(
            helper_endpoint,
            &project,
            &state,
            &command,
            &host_file,
            &prompt_bin,
            &snapshot,
        );
    }
    let mut command =
        Command::new(std::env::current_exe().context("failed to resolve current exe")?);
    command
        .env("CONDOM_APPROVAL_DISPLAY", ":condom-doctor")
        .env("CONDOM_APPROVAL_PATH", &prompt_bin);
    command
        .env_remove(helper::HELPER_ENV)
        .env_remove(helper::HELPER_SOCKET_ENV)
        .env(helper::DISABLE_HELPER_REENTRY_ENV, "1");
    let output = command
        .args(["__landlock-exec", "--policy-snapshot"])
        .arg(&snapshot.path)
        .args(["--", "cat"])
        .arg(&host_file)
        .output()
        .context("failed to run filesystem approval mediation probe")?;
    if !output.status.success() {
        bail!(
            "probe exited with status {:?}: {}{}",
            output.status.code(),
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
    }
    let stdout = String::from_utf8_lossy(&output.stdout);
    if stdout != "doctor host read" {
        bail!("probe returned unexpected output `{stdout}`");
    }
    Ok(())
}

fn helper_filesystem_authorization_probe(
    helper_endpoint: &helper::HelperEndpoint,
    project: &ProjectContext,
    state: &StatePaths,
    command: &[String],
    host_file: &Path,
    prompt_bin: &Path,
    snapshot: &policy::PolicySnapshot,
) -> Result<()> {
    let mut prompt_environment = prompt::approval_prompt_environment();
    prompt_environment.insert(prompt::APPROVAL_DISPLAY_ENV.into(), ":condom-doctor".into());
    prompt_environment.insert(
        prompt::APPROVAL_PATH_ENV.into(),
        prompt_bin.display().to_string(),
    );
    let response = helper::request_helper(
        helper_endpoint,
        &helper::HelperRequest::AuthorizeFilesystem {
            protocol_version: helper::HELPER_PROTOCOL_VERSION,
            project_root: project.root.display().to_string(),
            project_id: project.id.clone(),
            state_root: state_base_for_request(state),
            mode: ExecutionMode::Run,
            command: command.to_vec(),
            kind: ApprovalKind::FsRead,
            path: host_file.display().to_string(),
            policy_snapshot_id: Some(snapshot.id.to_string()),
            prompt_environment,
            caller_env: crate::app::env::current_user_environment(),
        },
    )
    .context("configured helper failed filesystem authorization probe")?;
    match response {
        helper::HelperResponse::FilesystemAuthorization {
            decision: ApprovalDecision::Allow,
            ..
        } => Ok(()),
        helper::HelperResponse::FilesystemAuthorization { reason, .. } => {
            bail!("configured helper denied filesystem authorization probe: {reason}")
        }
        other => bail!(
            "configured helper returned unexpected filesystem authorization response: {other:?}"
        ),
    }
}

fn state_base_for_request(state: &StatePaths) -> Option<String> {
    state
        .xdg_state_dir
        .parent()
        .and_then(Path::parent)
        .map(|path| path.display().to_string())
}

fn network_enforcement_check(probe: HelperProbe) -> DoctorCheck {
    match probe {
        HelperProbe::Ready { capabilities, .. }
            if capabilities.contains(&helper::HelperCapability::NetworkRouting) =>
        {
            DoctorCheck {
                name: "network-enforcement".into(),
                status: CheckStatus::Pass,
                message: "transparent proxy enforcement is active; run and review network access must pass through condom proxy policy".into(),
            }
        }
        HelperProbe::Ready { .. } => DoctorCheck {
            name: "network-enforcement".into(),
            status: CheckStatus::Fail,
            message: "transparent proxy enforcement is unavailable; run and review refuse to start networked sandboxes without it".into(),
        },
        HelperProbe::Missing { message, .. } | HelperProbe::Failed { message, .. } => {
            DoctorCheck {
                name: "network-enforcement".into(),
                status: CheckStatus::Fail,
                message: format!("transparent proxy enforcement unavailable: {message}"),
            }
        }
        HelperProbe::Incompatible { expected, actual, .. } => DoctorCheck {
            name: "network-enforcement".into(),
            status: CheckStatus::Fail,
            message: format!(
                "transparent proxy enforcement unavailable: helper protocol mismatch; helper expected {expected}, condom sent {actual}"
            ),
        },
    }
}

pub fn has_blocking_failures(checks: &[DoctorCheck]) -> bool {
    checks.iter().any(|check| check.status == CheckStatus::Fail)
}

fn helper_protocol_check(probe: HelperProbe) -> DoctorCheck {
    match probe {
        HelperProbe::Ready {
            path,
            helper_version,
            ..
        } => DoctorCheck {
            name: "nixos-root-helper".into(),
            status: CheckStatus::Pass,
            message: format!(
                "compatible condom-helper {} at {}",
                helper_version,
                path.display()
            ),
        },
        HelperProbe::Missing { path, message } => DoctorCheck {
            name: "nixos-root-helper".into(),
            status: CheckStatus::Fail,
            message: format!("{message}; set CONDOM_HELPER or install {}", path.display()),
        },
        HelperProbe::Incompatible {
            path,
            expected,
            actual,
        } => DoctorCheck {
            name: "nixos-root-helper".into(),
            status: CheckStatus::Fail,
            message: format!(
                "helper {} protocol mismatch; helper expected {}, condom sent {}",
                path.display(),
                expected,
                actual
            ),
        },
        HelperProbe::Failed { path, message } => DoctorCheck {
            name: "nixos-root-helper".into(),
            status: CheckStatus::Fail,
            message: format!("helper {} probe failed: {message}", path.display()),
        },
    }
}

fn helper_capabilities_check(probe: HelperProbe) -> DoctorCheck {
    match probe {
        HelperProbe::Ready {
            path,
            capabilities,
            ..
        } => {
            let missing = helper::missing_required_capabilities(&capabilities);
            if missing.is_empty() {
                return DoctorCheck {
                    name: "nixos-root-helper-capabilities".into(),
                    status: CheckStatus::Pass,
                    message: format!(
                        "helper {} advertises required supervisor capabilities",
                        path.display()
                    ),
                };
            }
            DoctorCheck {
                name: "nixos-root-helper-capabilities".into(),
                status: CheckStatus::Fail,
                message: format!(
                    "helper {} is missing supervisor capabilities: {}",
                    path.display(),
                    format_capabilities(&missing)
                ),
            }
        }
        HelperProbe::Missing { message, .. }
        | HelperProbe::Failed { message, .. } => DoctorCheck {
            name: "nixos-root-helper-capabilities".into(),
            status: CheckStatus::Fail,
            message: format!("helper capabilities unavailable: {message}"),
        },
        HelperProbe::Incompatible {
            expected, actual, ..
        } => DoctorCheck {
            name: "nixos-root-helper-capabilities".into(),
            status: CheckStatus::Fail,
            message: format!(
                "helper capabilities unavailable: protocol mismatch; helper expected {expected}, condom sent {actual}"
            ),
        },
    }
}

fn format_capabilities(capabilities: &[helper::HelperCapability]) -> String {
    capabilities
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>()
        .join(", ")
}

fn capture_check(probe: CaptureProbe) -> DoctorCheck {
    match probe {
        CaptureProbe::Ready { path } => DoctorCheck {
            name: "capture-backend".into(),
            status: CheckStatus::Pass,
            message: format!(
                "fuse-overlayfs capture backend is available at {}; review uses it for transparent captured writes",
                path.display()
            ),
        },
        CaptureProbe::MissingFuseDevice { message, .. } => DoctorCheck {
            name: "capture-backend".into(),
            status: CheckStatus::Fail,
            message,
        },
        CaptureProbe::MissingTool { path, message } => DoctorCheck {
            name: "capture-backend".into(),
            status: CheckStatus::Fail,
            message: format!(
                "{message}; set CONDOM_FUSE_OVERLAYFS or install {}",
                path.display()
            ),
        },
        CaptureProbe::Failed { path, message } => DoctorCheck {
            name: "capture-backend".into(),
            status: CheckStatus::Fail,
            message: format!("capture backend {} probe failed: {message}", path.display()),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filesystem_approval_gui_check_maps_probe_failure_to_failed_check() {
        let check = filesystem_approval_gui_check_from_readiness(Err(
            "approval GUI cannot open the display via /bin/condom-approval: display denied".into(),
        ));

        assert_eq!(check.status, CheckStatus::Fail);
        assert!(check
            .message
            .contains("approval GUI cannot open the display"));
        assert!(check.message.contains("display denied"));
    }

    #[test]
    fn filesystem_approval_gui_check_maps_missing_display_to_warning() {
        let check = filesystem_approval_gui_check_from_readiness(Err(
            "desktop display is not configured".into(),
        ));

        assert_eq!(check.status, CheckStatus::Warn);
        assert!(check
            .message
            .contains("terminal approval fallback is required"));
    }
}
