use std::ffi::OsString;
use std::fs;
use std::os::unix::ffi::{OsStrExt, OsStringExt};
use std::path::{Path, PathBuf};
use std::process::Command as ProcessCommand;

use anyhow::{bail, Context, Result};
use chrono::{DateTime, Utc};
use clap::{ArgAction, Args, Parser, Subcommand};
use serde::Serialize;
use uuid::Uuid;

use crate::app::doctor;
use crate::app::runtime;
use crate::app::shims;
use crate::auth::approvals::{
    Approval, ApprovalDecision, ApprovalKind, ApprovalScope, ApprovalStores, NewApproval,
};
use crate::auth::prompt;
use crate::model::config::{
    default_global_config_path, validate_environment_key, CondomConfig, EnvironmentConfig,
    ExecutionMode,
};
use crate::model::events::{Decision, Event, EventLog, EventType};
use crate::model::project::ProjectContext;
use crate::model::state::StatePaths;
use crate::net::tproxy;
use crate::sandbox::capture;
use crate::sandbox::landlock;

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
#[cfg(unix)]
use std::os::unix::process::CommandExt;

const STATUS_RECENT_LIMIT: usize = 5;
const STATUS_APPROVAL_TEXT_LIMIT: usize = 12;
const RUNTIME_WRAPPER_PATH: &str = "/run/wrappers/bin/condom-tproxy";
const ORIGINAL_PATH_ARG: &str = "--__original-path";
const ORIGINAL_USER_ENV_ARG: &str = "--__original-user-env";
const RUNTIME_WRAPPER_ARG: &str = "--__runtime-wrapper";

#[derive(Debug, Parser)]
#[command(
    name = "condom",
    version,
    about = "Linux-first developer safety wrapper",
    after_help = "Examples:
  condom init
  condom doctor
  condom status
  condom run -- npm test
  condom review -- npm update
condom allow add fs-read ~/.agent --scope app-project --app agent
condom events --json"
)]
pub struct Cli {
    #[arg(
        long = "__original-path",
        hide = true,
        global = true,
        value_name = "PATH"
    )]
    original_path: Option<OsString>,
    #[arg(
        long = "__runtime-wrapper",
        hide = true,
        global = true,
        action = ArgAction::SetTrue
    )]
    runtime_wrapper: bool,
    #[arg(
        long = "__original-user-env",
        hide = true,
        global = true,
        value_name = "KEY=VALUE"
    )]
    original_user_env: Vec<OsString>,
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    #[command(about = "Initialize Condom in a project")]
    Init(InitArgs),
    #[command(about = "Check host and project readiness")]
    Doctor(JsonRootArgs),
    #[command(about = "Show project state")]
    Status(JsonRootArgs),
    #[command(about = "Run a command with condom enforcement")]
    Run(RunArgs),
    #[command(about = "Run a command with captured writes for review")]
    Review(ReviewArgs),
    #[command(about = "Manage project approvals")]
    Allow(AllowArgs),
    #[command(about = "Manage project environment passthrough policy")]
    Env(EnvArgs),
    #[command(about = "Show recent structured events")]
    Events(EventsArgs),
    #[command(name = "__landlock-exec", hide = true)]
    LandlockExec(LandlockExecArgs),
    #[command(name = "__review-ui", hide = true)]
    ReviewUi(ReviewUiArgs),
}

#[derive(Debug, Args)]
struct InitArgs {
    #[arg(long, value_name = "PATH")]
    root: Option<PathBuf>,
    #[arg(short, long)]
    force: bool,
}

#[derive(Debug, Args)]
struct JsonRootArgs {
    #[arg(long, value_name = "PATH")]
    root: Option<PathBuf>,
    #[arg(short, long)]
    json: bool,
}

#[derive(Debug, Args)]
struct RunArgs {
    #[arg(long, value_name = "PATH")]
    root: Option<PathBuf>,
    #[arg(
        value_name = "COMMAND",
        trailing_var_arg = true,
        allow_hyphen_values = true,
        required = true
    )]
    command: Vec<String>,
}

#[derive(Debug, Args)]
struct ReviewArgs {
    #[arg(long, value_name = "PATH")]
    root: Option<PathBuf>,
    #[arg(
        long = "ephemeral-overlay",
        value_name = "SOURCE=DESTINATION",
        value_parser = parse_ephemeral_overlay,
        hide = true
    )]
    ephemeral_overlays: Vec<capture::EphemeralOverlay>,
    #[arg(
        value_name = "COMMAND",
        trailing_var_arg = true,
        allow_hyphen_values = true,
        required = true
    )]
    command: Vec<String>,
}

#[derive(Debug, Args)]
struct LandlockExecArgs {
    #[arg(long, value_name = "PATH")]
    policy_snapshot: PathBuf,
    #[arg(long = "runtime-path", value_name = "PATH", hide = true)]
    runtime_path: Option<String>,
    #[arg(long = "interactive-pty", hide = true, action = ArgAction::SetTrue)]
    interactive_pty: bool,
    #[arg(
        value_name = "COMMAND",
        trailing_var_arg = true,
        allow_hyphen_values = true,
        required = true
    )]
    command: Vec<String>,
}

#[derive(Debug, Args)]
struct ReviewUiArgs {
    #[arg(long, value_name = "MODE")]
    mode: String,
    #[arg(long, value_name = "PATH")]
    session: PathBuf,
}

#[derive(Debug, Args)]
struct AllowArgs {
    #[arg(long, value_name = "PATH")]
    root: Option<PathBuf>,
    #[command(subcommand)]
    command: AllowCommand,
}

#[derive(Debug, Subcommand)]
enum AllowCommand {
    #[command(about = "Add an allow or deny decision")]
    Add(AllowAddArgs),
    #[command(name = "ls", about = "List approvals")]
    Ls(JsonArgs),
    #[command(name = "rm", about = "Remove an approval by id")]
    Rm(AllowRmArgs),
    #[command(about = "Remove expired or consumed approvals")]
    Gc,
}

#[derive(Debug, Args)]
struct AllowAddArgs {
    #[arg(value_enum)]
    kind: ApprovalKind,
    subject: String,
    #[arg(long, value_name = "APP")]
    app: Option<String>,
    #[arg(long, value_enum, default_value = "project")]
    scope: ApprovalScope,
    #[arg(long, value_name = "DURATION", default_value = "15m")]
    ttl: String,
    #[arg(long)]
    once: bool,
    #[arg(long)]
    deny: bool,
    #[arg(long)]
    reason: Option<String>,
}

#[derive(Debug, Args)]
struct AllowRmArgs {
    id: Uuid,
}

#[derive(Debug, Args)]
struct EnvArgs {
    #[arg(long, value_name = "PATH")]
    root: Option<PathBuf>,
    #[command(subcommand)]
    command: EnvCommand,
}

#[derive(Debug, Subcommand)]
enum EnvCommand {
    #[command(about = "Allow an environment variable to pass through")]
    Allow(EnvKeyArgs),
    #[command(about = "Deny an environment variable from passing through")]
    Deny(EnvKeyArgs),
    #[command(name = "ls", about = "List environment passthrough policy")]
    Ls(JsonArgs),
    #[command(name = "rm", about = "Remove an environment variable rule")]
    Rm(EnvKeyArgs),
}

#[derive(Debug, Args)]
struct EnvKeyArgs {
    name: String,
}

#[derive(Debug, Args)]
struct JsonArgs {
    #[arg(short, long)]
    json: bool,
}

#[derive(Debug, Args)]
struct EventsArgs {
    #[arg(long, value_name = "PATH")]
    root: Option<PathBuf>,
    #[arg(short, long)]
    json: bool,
    #[arg(long)]
    last: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct StatusView {
    project_root: String,
    project_id: String,
    initialized: bool,
    shim_count: usize,
    active_approval_count: usize,
    active_approvals: Vec<StatusApprovalView>,
    event_count: usize,
    recent_block_count: usize,
    recent_blocks: Vec<StatusEventView>,
    recent_prompt_failure_count: usize,
    recent_prompt_failures: Vec<StatusEventView>,
    proxy_status: ProxyStatusView,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct StatusApprovalView {
    id: Uuid,
    decision: ApprovalDecision,
    scope: ApprovalScope,
    app: Option<String>,
    kind: ApprovalKind,
    subject: String,
    created_at: DateTime<Utc>,
    expires_at: Option<DateTime<Utc>>,
    once: bool,
    reason: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ProxyStatusView {
    configured: bool,
    adapters: Vec<String>,
    last_decision: Option<StatusEventView>,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct StatusEventView {
    timestamp: DateTime<Utc>,
    event_type: EventType,
    decision: Decision,
    mode: ExecutionMode,
    subject: String,
    reason: String,
    suggested_allow: Option<String>,
}

pub fn run() -> Result<i32> {
    let cli = Cli::parse();
    restore_original_user_env(&cli.original_user_env)?;
    if let Some(path) = cli.original_path {
        std::env::set_var(crate::app::env::ORIGINAL_PATH_ENV, path);
    }
    if cli.runtime_wrapper {
        std::env::set_var(crate::app::env::WRAPPER_REEXEC_ENV, "1");
    }
    if command_uses_runtime(&cli.command) {
        maybe_reexec_transparent_proxy_wrapper()?;
    }
    match cli.command {
        Command::Init(args) => {
            init(args)?;
            Ok(0)
        }
        Command::Doctor(args) => doctor_cmd(args),
        Command::Status(args) => {
            status_cmd(args)?;
            Ok(0)
        }
        Command::Run(args) => run_cmd(args),
        Command::Review(args) => review_cmd(args),
        Command::Allow(args) => {
            allow_cmd(args)?;
            Ok(0)
        }
        Command::Env(args) => {
            env_cmd(args)?;
            Ok(0)
        }
        Command::Events(args) => {
            events_cmd(args)?;
            Ok(0)
        }
        Command::LandlockExec(args) => landlock_exec_cmd(args),
        Command::ReviewUi(args) => {
            crate::sandbox::review::run_review_ui_command(&args.mode, &args.session)
        }
    }
}

fn command_uses_runtime(command: &Command) -> bool {
    matches!(command, Command::Run(_) | Command::Review(_))
}

fn maybe_reexec_transparent_proxy_wrapper() -> Result<()> {
    if !tproxy::routing_configured(std::env::var_os(tproxy::ROUTING_ENV).as_deref())
        || std::env::var_os(crate::app::env::WRAPPER_REEXEC_ENV).is_some()
        || crate::kernel::capabilities::has_effective_cap_net_admin()
    {
        return Ok(());
    }
    let current_exe = std::env::current_exe().unwrap_or_default();
    let wrapper = match transparent_proxy_wrapper_reexec_path(&current_exe) {
        Some(wrapper) => wrapper,
        None => return Ok(()),
    };

    let mut command = ProcessCommand::new(wrapper);
    let original_path =
        std::env::var_os(crate::app::env::ORIGINAL_PATH_ENV).or_else(|| std::env::var_os("PATH"));
    command
        .args(wrapper_reexec_args(
            original_path,
            original_user_environment(),
            std::env::args_os().skip(1),
        ))
        .env(crate::app::env::WRAPPER_REEXEC_ENV, "1");
    if std::env::var_os(crate::app::env::ORIGINAL_PATH_ENV).is_none() {
        if let Some(path) = std::env::var_os("PATH") {
            command.env(crate::app::env::ORIGINAL_PATH_ENV, path);
        }
    }
    let error = command.exec();
    Err(error).with_context(|| format!("failed to exec {}", wrapper.display()))
}

fn wrapper_reexec_args(
    original_path: Option<OsString>,
    original_user_env: Vec<(&'static str, OsString)>,
    args: impl IntoIterator<Item = OsString>,
) -> Vec<OsString> {
    let mut wrapper_args = Vec::new();
    wrapper_args.push(RUNTIME_WRAPPER_ARG.into());
    if let Some(path) = original_path {
        wrapper_args.push(ORIGINAL_PATH_ARG.into());
        wrapper_args.push(path);
    }
    for (key, value) in original_user_env {
        wrapper_args.push(ORIGINAL_USER_ENV_ARG.into());
        wrapper_args.push(original_user_env_assignment(key, value));
    }
    wrapper_args.extend(args);
    wrapper_args
}

fn original_user_environment() -> Vec<(&'static str, OsString)> {
    crate::app::env::USER_ENV_KEYS
        .iter()
        .filter_map(|key| std::env::var_os(key).map(|value| (*key, value)))
        .collect()
}

fn original_user_env_assignment(key: &str, value: OsString) -> OsString {
    let mut assignment = key.as_bytes().to_vec();
    assignment.push(b'=');
    assignment.extend(value.as_os_str().as_bytes());
    OsString::from_vec(assignment)
}

fn restore_original_user_env(assignments: &[OsString]) -> Result<()> {
    for assignment in assignments {
        let (key, value) = parse_original_user_env_assignment(assignment)?;
        if !crate::app::env::USER_ENV_KEYS.contains(&key.as_str()) {
            bail!("invalid preserved wrapper environment key `{key}`");
        }
        std::env::set_var(key, value);
    }
    Ok(())
}

fn parse_original_user_env_assignment(assignment: &OsString) -> Result<(String, OsString)> {
    let bytes = assignment.as_os_str().as_bytes();
    let Some(separator) = bytes.iter().position(|byte| *byte == b'=') else {
        bail!("invalid preserved wrapper environment assignment");
    };
    let key = std::str::from_utf8(&bytes[..separator])
        .context("invalid preserved wrapper environment key")?
        .to_string();
    let value = OsString::from_vec(bytes[separator + 1..].to_vec());
    Ok((key, value))
}

fn transparent_proxy_wrapper_reexec_path(current_exe: &Path) -> Option<&'static Path> {
    let wrapper = Path::new(RUNTIME_WRAPPER_PATH);
    (current_exe != wrapper && is_executable_file(wrapper)).then_some(wrapper)
}

fn is_executable_file(path: &Path) -> bool {
    path.is_file()
        && path
            .metadata()
            .map(|metadata| metadata.permissions().mode() & 0o111 != 0)
            .unwrap_or(false)
}

fn init(args: InitArgs) -> Result<()> {
    let requested_root = args.root.unwrap_or(std::env::current_dir()?);
    let root = requested_root.canonicalize().unwrap_or(requested_root);
    let project = ProjectContext::from_root(root)?;
    let state = StatePaths::from_environment(&project);
    state.ensure_project_dirs()?;
    if state.project_config.exists() && !args.force {
        match prompt::confirm_init_overwrite(&state.project_config)? {
            Some(true) => {}
            Some(false) => bail!(
                "initialization cancelled; existing config left unchanged at {}",
                state.project_config.display()
            ),
            None => bail!(
                "{} already exists; rerun from an interactive terminal to confirm overwrite or pass --force",
                state.project_config.display()
            ),
        }
    }
    CondomConfig::write_default(&state.project_config)?;
    let config = CondomConfig::load(&project.root, global_config().as_deref())?;
    let written = shims::write_shims(&config, &state.shim_dir, true)?;
    let wrote_envrc = shims::ensure_direnv_shim_path(&project.root)?;
    println!("initialized {}", project.root.display());
    println!("wrote {}", state.project_config.display());
    if wrote_envrc {
        println!("wrote {}", project.root.join(".envrc").display());
    }
    println!(
        "wrote {} shim(s) in {}",
        written.len(),
        state.shim_dir.display()
    );
    Ok(())
}

fn doctor_cmd(args: JsonRootArgs) -> Result<i32> {
    let (project, state, config) = load_project(args.root)?;
    let checks = doctor::checks(&project, &state, &config);
    let has_failures = doctor::has_blocking_failures(&checks);
    if args.json {
        println!("{}", serde_json::to_string_pretty(&checks)?);
    } else {
        for check in &checks {
            println!("{:<22} {:?}: {}", check.name, check.status, check.message);
        }
    }
    Ok(if has_failures { 1 } else { 0 })
}

fn status_cmd(args: JsonRootArgs) -> Result<()> {
    let (project, state, config) = load_project(args.root)?;
    let approvals = ApprovalStores::from_state(&state).load()?;
    let event_log = EventLog::new(state.events_file.clone());
    let event_count = event_log.count()?;
    let now = chrono::Utc::now();
    let active_approvals = active_approval_views(&approvals, now);
    let recent_block_events =
        event_log.list_recent_matching(STATUS_RECENT_LIMIT, status_block_event)?;
    let recent_blocks = recent_block_events
        .iter()
        .map(StatusEventView::from)
        .collect::<Vec<_>>();
    let recent_prompt_failure_events =
        event_log.list_recent_matching(STATUS_RECENT_LIMIT, status_prompt_failure_event)?;
    let recent_prompt_failures = recent_prompt_failure_events
        .iter()
        .map(StatusEventView::from)
        .collect::<Vec<_>>();
    let latest_proxy_event =
        event_log.list_recent_matching(1, |event| matches!(&event.event_type, EventType::Proxy))?;
    let view = StatusView {
        project_root: project.root.display().to_string(),
        project_id: project.id,
        initialized: state.project_config.exists(),
        shim_count: config.shims.len(),
        active_approval_count: active_approvals.len(),
        active_approvals,
        event_count,
        recent_block_count: recent_blocks.len(),
        recent_blocks,
        recent_prompt_failure_count: recent_prompt_failures.len(),
        recent_prompt_failures,
        proxy_status: proxy_status(&config, latest_proxy_event.last()),
    };
    if args.json {
        println!("{}", serde_json::to_string_pretty(&view)?);
    } else {
        println!("project: {}", view.project_root);
        println!("project id: {}", view.project_id);
        println!("initialized: {}", view.initialized);
        println!("shims: {}", view.shim_count);
        println!("active approvals: {}", view.active_approval_count);
        for approval in view
            .active_approvals
            .iter()
            .take(STATUS_APPROVAL_TEXT_LIMIT)
        {
            println!(
                "  {:?} {:?} {:?} app={} {} id={}{}",
                approval.decision,
                approval.scope,
                approval.kind,
                approval.app.as_deref().unwrap_or("-"),
                approval.subject,
                approval.id,
                status_approval_flags(approval)
            );
        }
        if view.active_approval_count > STATUS_APPROVAL_TEXT_LIMIT {
            println!(
                "  ... {} more",
                view.active_approval_count - STATUS_APPROVAL_TEXT_LIMIT
            );
        }
        println!("events: {}", view.event_count);
        println!("recent blocks: {}", view.recent_block_count);
        for block in &view.recent_blocks {
            println!(
                "  {:?} {:?} {}: {}",
                block.event_type,
                block.decision,
                block.subject,
                display_reason(&block.reason)
            );
        }
        println!(
            "recent prompt failures: {}",
            view.recent_prompt_failure_count
        );
        for failure in &view.recent_prompt_failures {
            println!(
                "  {:?} {:?} {}: {}",
                failure.event_type,
                failure.decision,
                failure.subject,
                display_reason(&failure.reason)
            );
        }
        if view.proxy_status.configured {
            println!("proxy adapters: {}", view.proxy_status.adapters.join(", "));
        } else {
            println!("proxy adapters: none");
        }
        if let Some(event) = &view.proxy_status.last_decision {
            println!(
                "last proxy decision: {:?} {}: {}",
                event.decision,
                event.subject,
                display_reason(&event.reason)
            );
        } else {
            println!("last proxy decision: none");
        }
    }
    Ok(())
}

#[cfg(test)]
fn recent_block_events(events: &[Event], limit: usize) -> Vec<StatusEventView> {
    events
        .iter()
        .rev()
        .filter(|event| status_block_event(event))
        .take(limit)
        .map(StatusEventView::from)
        .collect()
}

fn active_approval_views(approvals: &[Approval], now: DateTime<Utc>) -> Vec<StatusApprovalView> {
    let mut active = approvals
        .iter()
        .filter(|approval| approval.active(now))
        .collect::<Vec<_>>();
    active.sort_by_key(|approval| std::cmp::Reverse(approval.created_at));
    active.into_iter().map(StatusApprovalView::from).collect()
}

fn status_block_event(event: &Event) -> bool {
    matches!(&event.decision, Decision::Denied | Decision::Rejected)
        || (event.decision == Decision::Failed && !matches!(&event.event_type, EventType::Runtime))
}

fn status_prompt_failure_event(event: &Event) -> bool {
    matches!(&event.event_type, EventType::Prompt)
        && matches!(
            &event.decision,
            Decision::Denied | Decision::Rejected | Decision::Failed
        )
        && (event.reason.contains("failed to prompt")
            || event.reason.contains("approval GUI")
            || event.reason.contains("approval prompt")
            || event.reason.contains("no approval UI available")
            || event.reason.contains("terminal fallback"))
}

fn proxy_status(config: &CondomConfig, latest_proxy_event: Option<&Event>) -> ProxyStatusView {
    ProxyStatusView {
        configured: !config.proxy.adapters.is_empty(),
        adapters: config.proxy.adapters.clone(),
        last_decision: latest_proxy_event.map(StatusEventView::from),
    }
}

impl From<&Approval> for StatusApprovalView {
    fn from(approval: &Approval) -> Self {
        Self {
            id: approval.id,
            decision: approval.decision,
            scope: approval.scope,
            app: approval.app.clone(),
            kind: approval.kind,
            subject: approval.subject.clone(),
            created_at: approval.created_at,
            expires_at: approval.expires_at,
            once: approval.once,
            reason: approval.reason.clone(),
        }
    }
}

impl From<&Event> for StatusEventView {
    fn from(event: &Event) -> Self {
        Self {
            timestamp: event.timestamp,
            event_type: event.event_type.clone(),
            decision: event.decision.clone(),
            mode: event.mode,
            subject: event.subject.clone(),
            reason: event.reason.clone(),
            suggested_allow: event.suggested_allow.clone(),
        }
    }
}

fn status_approval_flags(approval: &StatusApprovalView) -> String {
    let mut flags = Vec::new();
    if approval.once {
        flags.push("once".to_string());
    }
    if let Some(expires_at) = approval.expires_at {
        flags.push(format!("expires {expires_at}"));
    }
    if flags.is_empty() {
        String::new()
    } else {
        format!(" ({})", flags.join(", "))
    }
}

fn display_reason(reason: &str) -> String {
    reason
        .trim_end_matches(['\r', '\n'])
        .replace('\r', "\\r")
        .replace('\n', "\\n")
}

fn run_cmd(args: RunArgs) -> Result<i32> {
    let (project, state, config) = load_project(args.root)?;
    let event_log = EventLog::new(state.events_file.clone());
    runtime::run_guarded(&project, &state, &config, &args.command, &event_log)
}

fn review_cmd(args: ReviewArgs) -> Result<i32> {
    let (project, state, config) = load_project(args.root)?;
    let event_log = EventLog::new(state.events_file.clone());
    runtime::review_guarded(
        &project,
        &state,
        &config,
        &args.command,
        &args.ephemeral_overlays,
        &event_log,
    )
}

fn parse_ephemeral_overlay(value: &str) -> std::result::Result<capture::EphemeralOverlay, String> {
    let (source, destination) = value
        .split_once('=')
        .ok_or_else(|| "expected SOURCE=DESTINATION".to_string())?;
    if source.is_empty() {
        return Err("ephemeral overlay source cannot be empty".into());
    }
    if destination.is_empty() {
        return Err("ephemeral overlay destination cannot be empty".into());
    }
    Ok(capture::EphemeralOverlay {
        source: PathBuf::from(source),
        destination: PathBuf::from(destination),
    })
}

fn landlock_exec_cmd(args: LandlockExecArgs) -> Result<i32> {
    landlock::exec_with_snapshot(
        &args.policy_snapshot,
        &args.command,
        args.runtime_path.as_deref(),
        args.interactive_pty,
    )
}

fn allow_cmd(args: AllowArgs) -> Result<()> {
    let (project, state, _config) = load_project(args.root)?;
    let store = ApprovalStores::from_state(&state);
    match args.command {
        AllowCommand::Add(add) => {
            if add.scope == ApprovalScope::AppProject && add.app.as_deref().unwrap_or("").is_empty()
            {
                bail!("--app is required when --scope app-project");
            }
            let approval = Approval::new_for_app(
                &project,
                NewApproval {
                    decision: if add.deny {
                        ApprovalDecision::Deny
                    } else {
                        ApprovalDecision::Allow
                    },
                    scope: add.scope,
                    kind: add.kind,
                    subject: add.subject,
                    ttl: Some(add.ttl),
                    once: add.once,
                    reason: add.reason,
                },
                add.app,
            )?;
            let id = approval.id;
            store.add(approval)?;
            println!("{id}");
        }
        AllowCommand::Ls(args) => {
            let approvals = store.load()?;
            if args.json {
                println!("{}", serde_json::to_string_pretty(&approvals)?);
            } else if approvals.is_empty() {
                println!("no approvals");
            } else {
                for approval in approvals {
                    println!(
                        "{} {:?} {:?} {:?} app={} {}",
                        approval.id,
                        approval.decision,
                        approval.scope,
                        approval.kind,
                        approval.app.as_deref().unwrap_or("-"),
                        approval.subject
                    );
                }
            }
        }
        AllowCommand::Rm(args) => {
            if store.remove(args.id)? {
                println!("removed {}", args.id);
            } else {
                bail!("approval {} not found", args.id);
            }
        }
        AllowCommand::Gc => {
            let removed = store.gc()?;
            println!("removed {removed} expired approval(s)");
        }
    }
    Ok(())
}

fn env_cmd(args: EnvArgs) -> Result<()> {
    let EnvArgs { root, command } = args;
    match command {
        EnvCommand::Allow(args) => {
            let (_project, state) = load_project_state(root)?;
            let environment =
                update_project_environment_config(&state.project_config, |environment| {
                    move_environment_key(&mut environment.deny, &mut environment.allow, args.name)
                })?;
            print_environment_config(&environment, false)?;
        }
        EnvCommand::Deny(args) => {
            let (_project, state) = load_project_state(root)?;
            let environment =
                update_project_environment_config(&state.project_config, |environment| {
                    move_environment_key(&mut environment.allow, &mut environment.deny, args.name)
                })?;
            print_environment_config(&environment, false)?;
        }
        EnvCommand::Ls(args) => {
            let (_project, _state, config) = load_project(root)?;
            print_environment_config(&config.environment, args.json)?;
        }
        EnvCommand::Rm(args) => {
            let (_project, state) = load_project_state(root)?;
            let environment =
                update_project_environment_config(&state.project_config, |environment| {
                    remove_environment_key(environment, &args.name)
                })?;
            print_environment_config(&environment, false)?;
        }
    }
    Ok(())
}

fn update_project_environment_config(
    path: &Path,
    update: impl FnOnce(&mut EnvironmentConfig) -> Result<()>,
) -> Result<EnvironmentConfig> {
    if !path.exists() {
        bail!("{} does not exist; run `condom init` first", path.display());
    }
    let content =
        fs::read_to_string(path).with_context(|| format!("failed to read {}", path.display()))?;
    let mut value = if content.trim().is_empty() {
        toml::Value::Table(toml::map::Map::new())
    } else {
        toml::from_str(&content).with_context(|| format!("failed to parse {}", path.display()))?
    };
    let table = value
        .as_table_mut()
        .context("project config root must be a TOML table")?;
    let mut environment = table
        .get("environment")
        .cloned()
        .map(toml::Value::try_into)
        .transpose()
        .context("failed to parse [environment]")?
        .unwrap_or_default();

    update(&mut environment)?;
    environment.validate()?;
    table.insert(
        "environment".into(),
        toml::Value::try_from(&environment).context("failed to render [environment]")?,
    );
    let rendered = toml::to_string_pretty(&value).context("failed to render project config")?;
    fs::write(path, rendered).with_context(|| format!("failed to write {}", path.display()))?;
    Ok(environment)
}

fn move_environment_key(
    source: &mut Vec<String>,
    destination: &mut Vec<String>,
    key: String,
) -> Result<()> {
    validate_environment_key(&key)?;
    source.retain(|value| value != &key);
    if !destination.iter().any(|value| value == &key) {
        destination.push(key);
        destination.sort();
    }
    Ok(())
}

fn remove_environment_key(environment: &mut EnvironmentConfig, key: &str) -> Result<()> {
    let old_allow_len = environment.allow.len();
    let old_deny_len = environment.deny.len();
    environment.allow.retain(|value| value != key);
    environment.deny.retain(|value| value != key);
    if environment.allow.len() == old_allow_len && environment.deny.len() == old_deny_len {
        bail!("environment variable `{key}` has no rule");
    }
    Ok(())
}

fn print_environment_config(environment: &EnvironmentConfig, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(environment)?);
        return Ok(());
    }
    if environment.allow.is_empty() {
        println!("allow: none");
    } else {
        println!("allow: {}", environment.allow.join(", "));
    }
    if environment.deny.is_empty() {
        println!("deny: none");
    } else {
        println!("deny: {}", environment.deny.join(", "));
    }
    Ok(())
}

fn events_cmd(args: EventsArgs) -> Result<()> {
    let (_project, state, _config) = load_project(args.root)?;
    let event_log = EventLog::new(state.events_file);
    let events = if args.last {
        event_log.list_recent(1)?
    } else {
        event_log.list()?
    };
    if args.json {
        println!("{}", serde_json::to_string_pretty(&events)?);
    } else if events.is_empty() {
        println!("no events");
    } else {
        for event in events {
            println!(
                "{} {:?} {:?} {}: {}",
                event.timestamp,
                event.event_type,
                event.decision,
                event.subject,
                display_reason(&event.reason)
            );
            if let Some(suggested_allow) = event.suggested_allow {
                println!("  suggested: {suggested_allow}");
            }
        }
    }
    Ok(())
}

fn load_project(root: Option<PathBuf>) -> Result<(ProjectContext, StatePaths, CondomConfig)> {
    let (project, state) = load_project_state(root)?;
    let config = CondomConfig::load(&project.root, global_config().as_deref())?;
    Ok((project, state, config))
}

fn load_project_state(root: Option<PathBuf>) -> Result<(ProjectContext, StatePaths)> {
    let project = ProjectContext::discover(root)?;
    let state = StatePaths::from_environment(&project);
    Ok((project, state))
}

fn global_config() -> Option<PathBuf> {
    default_global_config_path(
        std::env::var_os("XDG_CONFIG_HOME").map(PathBuf::from),
        std::env::var_os("HOME").map(PathBuf::from),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn project() -> ProjectContext {
        ProjectContext {
            root: PathBuf::from("/tmp/project"),
            id: "project-id".into(),
            origin: None,
        }
    }

    #[test]
    fn recent_block_events_include_denied_and_rejected_decisions() {
        let project = project();
        let events = vec![
            Event::runtime_finished(&project, ExecutionMode::Run, &["sh".into()], 7),
            Event::runtime_denied(
                &project,
                ExecutionMode::Run,
                &["sh".into()],
                "blocked token=secret",
            ),
            Event::prompt_decision(
                &project,
                ExecutionMode::Run,
                &["npm".into()],
                "example.test",
                Decision::Rejected,
                "denied once by prompt",
            ),
        ];

        let blocks = recent_block_events(&events, 5);

        assert_eq!(blocks.len(), 2);
        assert_eq!(blocks[0].subject, "example.test");
        assert_eq!(blocks[1].subject, "runtime-exec");
        assert_eq!(blocks[1].reason, "blocked token=<redacted>");
    }

    #[test]
    fn active_approval_views_include_visible_rows_newest_first() {
        let project = project();
        let now = chrono::Utc::now();
        let mut older = Approval::new_for_app(
            &project,
            NewApproval {
                decision: ApprovalDecision::Allow,
                scope: ApprovalScope::AppProject,
                kind: ApprovalKind::FsRead,
                subject: "/home/example/.agent".into(),
                ttl: None,
                once: false,
                reason: Some("needed by agent".into()),
            },
            Some("agent".into()),
        )
        .unwrap();
        let mut newer = Approval::new(
            &project,
            NewApproval {
                decision: ApprovalDecision::Deny,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsWrite,
                subject: "/tmp/blocked".into(),
                ttl: None,
                once: false,
                reason: None,
            },
        )
        .unwrap();
        older.created_at = now - chrono::Duration::minutes(2);
        newer.created_at = now - chrono::Duration::minutes(1);

        let views = active_approval_views(&[older, newer], now);

        assert_eq!(views.len(), 2);
        assert_eq!(views[0].subject, "/tmp/blocked");
        assert_eq!(views[1].app.as_deref(), Some("agent"));
    }

    #[test]
    fn status_prompt_failure_event_matches_prompt_backend_failures() {
        let project = project();
        let prompt_failure = Event::prompt_decision_for_kind(
            &project,
            ExecutionMode::Run,
            &["agent".into()],
            ApprovalKind::FsRead,
            "/home/example/.agent/config.toml",
            Decision::Denied,
            "failed to prompt for filesystem access: approval GUI failed; terminal fallback disabled while desktop display is available",
        );
        let stored_deny = Event::approval_decision(
            &project,
            ExecutionMode::Run,
            &["agent".into()],
            "/home/example/.agent/config.toml",
            Decision::Denied,
            "denied by stored filesystem approval",
        );

        assert!(status_prompt_failure_event(&prompt_failure));
        assert!(!status_prompt_failure_event(&stored_deny));
    }

    #[test]
    fn display_reason_keeps_text_output_single_line() {
        assert_eq!(
            display_reason("approval GUI failed\nextra detail\n"),
            "approval GUI failed\\nextra detail"
        );
    }

    #[test]
    fn transparent_proxy_wrapper_reexec_skips_current_executable() {
        let wrapper = Path::new(RUNTIME_WRAPPER_PATH);

        assert_ne!(
            transparent_proxy_wrapper_reexec_path(wrapper),
            Some(wrapper)
        );
    }

    #[test]
    fn transparent_proxy_wrapper_reexec_uses_configured_wrapper() {
        let current = Path::new("/home/me/.local/bin/condom");
        let wrapper = transparent_proxy_wrapper_reexec_path(current);

        if is_executable_file(Path::new(RUNTIME_WRAPPER_PATH)) {
            assert_eq!(wrapper, Some(Path::new(RUNTIME_WRAPPER_PATH)));
        } else {
            assert_eq!(wrapper, None);
        }
    }

    #[test]
    fn wrapper_reexec_args_preserve_original_path_as_hidden_cli_arg() {
        let args = wrapper_reexec_args(
            Some("/home/me/.local/bin:/run/current-system/sw/bin".into()),
            Vec::new(),
            [
                OsString::from("run"),
                OsString::from("--"),
                OsString::from("agent"),
            ],
        );

        assert_eq!(args[0], RUNTIME_WRAPPER_ARG);
        assert_eq!(args[1], ORIGINAL_PATH_ARG);
        assert_eq!(args[2], "/home/me/.local/bin:/run/current-system/sw/bin");
        assert_eq!(args[3], "run");
    }

    #[test]
    fn wrapper_reexec_args_preserve_original_user_environment_as_hidden_cli_args() {
        let args = wrapper_reexec_args(
            None,
            vec![
                ("HOME", OsString::from("/home/me")),
                ("XDG_CONFIG_HOME", OsString::from("/home/me/.config")),
            ],
            [
                OsString::from("run"),
                OsString::from("--"),
                OsString::from("agent"),
            ],
        );

        assert_eq!(args[0], RUNTIME_WRAPPER_ARG);
        assert_eq!(args[1], ORIGINAL_USER_ENV_ARG);
        assert_eq!(args[2], "HOME=/home/me");
        assert_eq!(args[3], ORIGINAL_USER_ENV_ARG);
        assert_eq!(args[4], "XDG_CONFIG_HOME=/home/me/.config");
        assert_eq!(args[5], "run");
    }

    #[test]
    fn cli_accepts_hidden_wrapper_args() {
        let cli = Cli::parse_from([
            "condom",
            RUNTIME_WRAPPER_ARG,
            ORIGINAL_PATH_ARG,
            "/home/me/.local/bin:/run/current-system/sw/bin",
            ORIGINAL_USER_ENV_ARG,
            "HOME=/home/me",
            "run",
            "--",
            "agent",
        ]);

        assert_eq!(
            cli.original_path.as_deref(),
            Some(std::ffi::OsStr::new(
                "/home/me/.local/bin:/run/current-system/sw/bin"
            ))
        );
        assert_eq!(cli.original_user_env, vec![OsString::from("HOME=/home/me")]);
        assert!(cli.runtime_wrapper);
    }

    #[test]
    fn cli_accepts_multiple_hidden_wrapper_env_args_before_runtime_command() {
        let cli = Cli::parse_from([
            "condom",
            RUNTIME_WRAPPER_ARG,
            ORIGINAL_PATH_ARG,
            "/home/me/.local/bin:/run/current-system/sw/bin",
            ORIGINAL_USER_ENV_ARG,
            "HOME=/home/me",
            ORIGINAL_USER_ENV_ARG,
            "USER=me",
            ORIGINAL_USER_ENV_ARG,
            "LOGNAME=me",
            ORIGINAL_USER_ENV_ARG,
            "SHELL=/run/current-system/sw/bin/fish",
            "run",
            "--",
            "sh",
            "-c",
            "printf 'HOME=%s\\n' \"$HOME\"",
        ]);

        assert_eq!(
            cli.original_user_env,
            vec![
                OsString::from("HOME=/home/me"),
                OsString::from("USER=me"),
                OsString::from("LOGNAME=me"),
                OsString::from("SHELL=/run/current-system/sw/bin/fish"),
            ]
        );
        assert!(cli.runtime_wrapper);
    }

    #[test]
    fn restore_original_user_env_rejects_unowned_keys() {
        let error = restore_original_user_env(&[OsString::from("LD_PRELOAD=/tmp/hook.so")])
            .expect_err("unowned env key should be rejected");

        assert!(format!("{error:#}").contains("invalid preserved wrapper environment key"));
    }

    #[test]
    fn only_runtime_commands_use_runtime_wrapper() {
        let run = Cli::parse_from(["condom", "run", "--", "true"]);
        let doctor = Cli::parse_from(["condom", "doctor"]);

        assert!(command_uses_runtime(&run.command));
        assert!(!command_uses_runtime(&doctor.command));
    }

    #[test]
    fn run_command_captures_command_arguments() {
        let cli = Cli::parse_from(["condom", "run", "--", "agent", "--model", "large"]);

        let Command::Run(args) = cli.command else {
            panic!("expected run command");
        };
        assert_eq!(args.command, vec!["agent", "--model", "large"]);
    }

    #[test]
    fn proxy_status_uses_latest_proxy_event() {
        let project = project();
        let mut config = CondomConfig::default();
        config.proxy.adapters = vec!["npm".into(), "cargo".into()];
        let events = [
            Event::proxy_decision(
                &project,
                ExecutionMode::Run,
                &["npm".into()],
                "old.example",
                Decision::Denied,
                "old deny",
            ),
            Event::runtime_started(&project, ExecutionMode::Run, &["true".into()]),
            Event::proxy_decision(
                &project,
                ExecutionMode::Run,
                &["npm".into()],
                "registry.example.test:443",
                Decision::Proxied,
                "proxied request",
            ),
        ];

        let status = proxy_status(&config, Some(&events[2]));

        assert!(status.configured);
        assert_eq!(status.adapters, vec!["npm", "cargo"]);
        assert_eq!(
            status.last_decision.map(|event| event.subject),
            Some("registry.example.test:443".into())
        );
    }
}
