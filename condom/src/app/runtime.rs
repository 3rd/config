use std::collections::BTreeMap;

use anyhow::{bail, Context, Result};

use crate::auth::prompt;
use crate::model::config::{CondomConfig, ExecutionMode};
use crate::model::events::EventLog;
use crate::model::policy;
use crate::model::project::ProjectContext;
use crate::model::state::StatePaths;
use crate::net::proxy;
use crate::sandbox::capture;
use crate::sandbox::fence;
use crate::sandbox::review;

const FENCE_INTERNAL_PROXY_PORTS: &[u16] = &[3128, 1080];

pub fn run_guarded(
    project: &ProjectContext,
    state: &StatePaths,
    config: &CondomConfig,
    command: &[String],
    event_log: &EventLog,
) -> Result<i32> {
    ensure_command(command)?;
    let proxy_guard = proxy::start_proxy(
        config,
        project,
        state,
        ExecutionMode::Run,
        command,
        event_log,
    )?;
    crate::kernel::capabilities::drop_process_capabilities()
        .map_err(anyhow::Error::from)
        .context("failed to drop runtime capabilities after starting proxy listener")?;
    let proxy_port = proxy_guard.port();
    let mut proxy_env = prompt::approval_prompt_environment();
    proxy_env.extend(proxy::child_environment(
        project,
        state,
        proxy_guard.addr(),
        &config.proxy,
    )?);
    let mut proxy_ports = proxy_guard.allowed_network_ports();
    add_fence_internal_proxy_ports(&mut proxy_ports);
    let policy_snapshot = policy::write_snapshot_with_network(
        project,
        state,
        config,
        ExecutionMode::Run,
        command,
        policy::NetworkMediationSnapshot {
            allowed_loopback_ports: proxy_ports,
            proxy_listen_port: Some(proxy_port),
            transparent_proxy: proxy_guard.transparent_proxy_snapshot(),
        },
    )?;
    run_fence_with_helper_delegation(
        project,
        state,
        config,
        ExecutionMode::Run,
        command,
        event_log,
        fence::FenceRunOptions {
            extra_env: &proxy_env,
            policy_snapshot: &policy_snapshot,
            runner_path: None,
            runtime_path: None,
        },
    )
}

fn run_fence_with_helper_delegation(
    project: &ProjectContext,
    state: &StatePaths,
    config: &CondomConfig,
    mode: ExecutionMode,
    command: &[String],
    event_log: &EventLog,
    options: fence::FenceRunOptions<'_>,
) -> Result<i32> {
    if let Some(exit_code) = crate::app::helper::run_configured_socket_sandbox(
        project,
        state,
        mode,
        command,
        options.extra_env,
        options.policy_snapshot,
    )
    .context("configured helper socket failed sandbox execution; refusing execution")?
    {
        return Ok(exit_code);
    }
    if let Some(exit_code) = crate::app::helper::run_configured_binary_sandbox(
        project,
        state,
        mode,
        command,
        options.extra_env,
        options.policy_snapshot,
    )
    .context("configured helper failed sandbox execution; refusing execution")?
    {
        return Ok(exit_code);
    }
    crate::app::helper::prepare_configured_sandbox(project, state, options.policy_snapshot)
        .context("configured helper failed sandbox preflight; refusing execution")?;
    fence::run_with_fence_env(project, state, config, mode, command, event_log, options)
}

pub fn review_guarded(
    project: &ProjectContext,
    state: &StatePaths,
    config: &CondomConfig,
    command: &[String],
    ephemeral_overlays: &[capture::EphemeralOverlay],
    event_log: &EventLog,
) -> Result<i32> {
    ensure_command(command)?;
    let session = review::create_session();
    let runtime_dir = capture::bind_capture_runtime_project_dir(&session.session_dir);
    let review_state = state.with_runtime_dir(runtime_dir);
    review_guarded_with_session(
        project,
        &review_state,
        config,
        command,
        ephemeral_overlays,
        event_log,
        session,
    )
}

fn review_guarded_with_session(
    project: &ProjectContext,
    state: &StatePaths,
    config: &CondomConfig,
    command: &[String],
    ephemeral_overlays: &[capture::EphemeralOverlay],
    event_log: &EventLog,
    session: review::ReviewSession,
) -> Result<i32> {
    let result = (|| {
        let mut extra_env = prompt::approval_prompt_environment();
        let proxy_guard = proxy::start_proxy(
            config,
            project,
            state,
            ExecutionMode::Review,
            command,
            event_log,
        )?;
        crate::kernel::capabilities::drop_process_capabilities()
            .map_err(anyhow::Error::from)
            .context("failed to drop runtime capabilities after starting proxy listener")?;
        extra_env.extend(proxy::child_environment(
            project,
            state,
            proxy_guard.addr(),
            &config.proxy,
        )?);
        let mut proxy_ports = proxy_guard.allowed_network_ports();
        let proxy_listen_port = Some(proxy_guard.port());
        add_fence_internal_proxy_ports(&mut proxy_ports);
        forward_review_shell_env(&mut extra_env);
        let transparent_proxy = proxy_guard.transparent_proxy_snapshot();
        let policy_snapshot = policy::write_snapshot_with_network(
            project,
            state,
            config,
            ExecutionMode::Review,
            command,
            policy::NetworkMediationSnapshot {
                allowed_loopback_ports: proxy_ports,
                proxy_listen_port,
                transparent_proxy,
            },
        )?;
        // Review owns an interactive shell after the sandboxed command exits; helper
        // daemon execution cannot preserve the caller's controlling TTY for that.
        review::run_review_session_with_runner_in_session(
            session.clone(),
            project,
            state,
            config,
            ExecutionMode::Review,
            command,
            ephemeral_overlays,
            &extra_env,
            event_log,
            &policy_snapshot,
            None,
            None,
        )
    })();
    if result.is_err() {
        review::cleanup_session(&session);
    }
    result
}

fn ensure_command(command: &[String]) -> Result<()> {
    if command.is_empty() {
        bail!("missing command after --");
    }
    Ok(())
}

fn add_fence_internal_proxy_ports(ports: &mut Vec<u16>) {
    ports.extend(FENCE_INTERNAL_PROXY_PORTS);
    ports.sort_unstable();
    ports.dedup();
}

fn forward_review_shell_env(extra_env: &mut BTreeMap<String, String>) {
    forward_review_shell_env_from(extra_env, |key| std::env::var(key).ok());
}

fn forward_review_shell_env_from(
    extra_env: &mut BTreeMap<String, String>,
    env_value: impl Fn(&str) -> Option<String>,
) {
    for key in ["CONDOM_REVIEW_PAGER", "CONDOM_REVIEW_SHELL", "SHELL"] {
        if let Some(value) = env_value(key) {
            extra_env.insert(key.into(), value);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn review_shell_env_forwards_pager_shell_and_review_shell() {
        let mut extra_env = BTreeMap::new();
        forward_review_shell_env_from(&mut extra_env, |key| match key {
            "CONDOM_REVIEW_PAGER" => Some("cat".into()),
            "CONDOM_REVIEW_SHELL" => Some("condom diff".into()),
            "SHELL" => Some("fish".into()),
            _ => None,
        });

        assert_eq!(
            extra_env.get("CONDOM_REVIEW_PAGER").map(String::as_str),
            Some("cat")
        );
        assert_eq!(
            extra_env.get("CONDOM_REVIEW_SHELL").map(String::as_str),
            Some("condom diff")
        );
        assert_eq!(extra_env.get("SHELL").map(String::as_str), Some("fish"));
    }
}
