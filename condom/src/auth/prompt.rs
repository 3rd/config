use std::collections::BTreeMap;
use std::ffi::CString;
use std::fs::{self, File, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::os::fd::AsRawFd;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use anyhow::{anyhow, Context, Result};
use serde::{Deserialize, Serialize};

pub(crate) const PROMPT_TTY_FD_ENV: &str = "CONDOM_PROMPT_TTY_FD";
pub(crate) const PROMPT_TTY_PATH_ENV: &str = "CONDOM_PROMPT_TTY_PATH";
pub(crate) const APPROVAL_PATH_ENV: &str = "CONDOM_APPROVAL_PATH";
pub(crate) const APPROVAL_DISPLAY_ENV: &str = "CONDOM_APPROVAL_DISPLAY";
pub(crate) const APPROVAL_WAYLAND_DISPLAY_ENV: &str = "CONDOM_APPROVAL_WAYLAND_DISPLAY";
pub(crate) const APPROVAL_XAUTHORITY_ENV: &str = "CONDOM_APPROVAL_XAUTHORITY";
pub(crate) const APPROVAL_DBUS_SESSION_BUS_ADDRESS_ENV: &str =
    "CONDOM_APPROVAL_DBUS_SESSION_BUS_ADDRESS";
pub(crate) const APPROVAL_XDG_RUNTIME_DIR_ENV: &str = "CONDOM_APPROVAL_XDG_RUNTIME_DIR";
const APPROVAL_ENV_KEYS: &[&str] = &[
    crate::app::debug::FORWARDED_DEBUG_ENV,
    crate::app::debug::DEBUG_LOG_ENV,
    PROMPT_TTY_FD_ENV,
    PROMPT_TTY_PATH_ENV,
    APPROVAL_PATH_ENV,
    APPROVAL_DISPLAY_ENV,
    APPROVAL_WAYLAND_DISPLAY_ENV,
    APPROVAL_XAUTHORITY_ENV,
    APPROVAL_DBUS_SESSION_BUS_ADDRESS_ENV,
    APPROVAL_XDG_RUNTIME_DIR_ENV,
];
const APPROVAL_ENV_MAPPINGS: &[(&str, &str)] = &[
    (APPROVAL_PATH_ENV, "PATH"),
    (APPROVAL_DISPLAY_ENV, "DISPLAY"),
    (APPROVAL_WAYLAND_DISPLAY_ENV, "WAYLAND_DISPLAY"),
    (APPROVAL_XAUTHORITY_ENV, "XAUTHORITY"),
    (
        APPROVAL_DBUS_SESSION_BUS_ADDRESS_ENV,
        "DBUS_SESSION_BUS_ADDRESS",
    ),
    (APPROVAL_XDG_RUNTIME_DIR_ENV, "XDG_RUNTIME_DIR"),
];
const PROMPT_CHOICES: &str =
    "Choices: d=deny once, o=allow once, ai=allow instance, di=deny instance, aa=allow app/project, da=deny app/project, a=allow project, x=deny project";
static APPROVAL_PROMPT_QUEUE: std::sync::Mutex<()> = std::sync::Mutex::new(());

pub(crate) struct ApprovalPromptQueueGuard {
    _process_guard: std::sync::MutexGuard<'static, ()>,
    _file_guard: Option<ApprovalPromptFileGuard>,
}

struct ApprovalPromptFileGuard {
    file: File,
}

impl Drop for ApprovalPromptFileGuard {
    fn drop(&mut self) {
        let _ = unlock_approval_prompt_file(&self.file);
    }
}

pub const APPROVAL_PROMPT_PROTOCOL_VERSION: u32 = 1;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum PromptDecision {
    DenyOnce,
    AllowOnce,
    AllowInstance,
    DenyInstance,
    AllowAppProject,
    DenyAppProject,
    AllowProject,
    DenyProject,
}

impl PromptDecision {
    pub fn code(self) -> &'static str {
        match self {
            Self::DenyOnce => "d",
            Self::AllowOnce => "o",
            Self::AllowInstance => "ai",
            Self::DenyInstance => "di",
            Self::AllowAppProject => "aa",
            Self::DenyAppProject => "da",
            Self::AllowProject => "a",
            Self::DenyProject => "x",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum FilesystemAccessMode {
    Read,
    Write,
    ReadWrite,
}

impl FilesystemAccessMode {
    pub fn code(self) -> &'static str {
        match self {
            Self::Read => "read",
            Self::Write => "write",
            Self::ReadWrite => "read-write",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value.trim().to_ascii_lowercase().as_str() {
            "read" | "r" => Some(Self::Read),
            "write" | "w" => Some(Self::Write),
            "read-write" | "read+write" | "read/write" | "rw" => Some(Self::ReadWrite),
            _ => None,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PromptResult {
    pub decision: PromptDecision,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub subject: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub filesystem_access: Option<FilesystemAccessMode>,
}

impl PromptResult {
    pub fn new(decision: PromptDecision) -> Self {
        Self {
            decision,
            subject: None,
            filesystem_access: None,
        }
    }

    pub fn with_subject(decision: PromptDecision, subject: impl Into<String>) -> Self {
        Self::with_subject_and_access(decision, subject, None)
    }

    pub fn with_filesystem_access(
        decision: PromptDecision,
        filesystem_access: FilesystemAccessMode,
    ) -> Self {
        Self {
            decision,
            subject: None,
            filesystem_access: Some(filesystem_access),
        }
    }

    pub fn with_subject_and_access(
        decision: PromptDecision,
        subject: impl Into<String>,
        filesystem_access: Option<FilesystemAccessMode>,
    ) -> Self {
        let subject = subject.into();
        Self {
            decision,
            subject: (!subject.is_empty()).then_some(subject),
            filesystem_access,
        }
    }

    pub fn response_line(&self) -> String {
        let mut line = self.decision.code().to_string();
        if let Some(filesystem_access) = self.filesystem_access {
            line.push_str(" access=");
            line.push_str(filesystem_access.code());
        }
        if let Some(subject) = &self.subject {
            let subject = subject
                .chars()
                .filter(|character| *character != '\r' && *character != '\n')
                .collect::<String>();
            line.push_str(" subject=");
            line.push_str(&subject);
        }
        line
    }
}

impl From<PromptDecision> for PromptResult {
    fn from(decision: PromptDecision) -> Self {
        Self::new(decision)
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalPromptRequest {
    pub protocol_version: u32,
    pub title: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub fields: Vec<ApprovalPromptField>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub body: Vec<String>,
}

impl ApprovalPromptRequest {
    pub fn new(
        title: impl Into<String>,
        fields: Vec<ApprovalPromptField>,
        body: Vec<String>,
    ) -> Self {
        Self {
            protocol_version: APPROVAL_PROMPT_PROTOCOL_VERSION,
            title: title.into(),
            fields,
            body,
        }
    }

    pub fn message_text(&self) -> String {
        let mut lines = vec![self.title.clone()];
        lines.extend(
            self.fields
                .iter()
                .map(|field| format!("  {}: {}", field.name, field.value)),
        );
        lines.extend(self.body.iter().cloned());
        lines.join("\n")
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalPromptField {
    pub name: String,
    pub value: String,
}

impl ApprovalPromptField {
    pub fn new(name: impl Into<String>, value: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            value: value.into(),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalPromptResponse {
    pub protocol_version: u32,
    pub decision: PromptDecision,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub subject: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub filesystem_access: Option<FilesystemAccessMode>,
}

impl ApprovalPromptResponse {
    pub fn from_prompt_result(result: PromptResult) -> Self {
        Self {
            protocol_version: APPROVAL_PROMPT_PROTOCOL_VERSION,
            decision: result.decision,
            subject: result.subject,
            filesystem_access: result.filesystem_access,
        }
    }

    pub fn into_prompt_result(self) -> Option<PromptResult> {
        (self.protocol_version == APPROVAL_PROMPT_PROTOCOL_VERSION).then_some(PromptResult {
            decision: self.decision,
            subject: self.subject,
            filesystem_access: self.filesystem_access,
        })
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ProxyPrompt {
    pub host: String,
    pub port: u16,
    pub project_root: String,
    pub command: Vec<String>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FilesystemPrompt {
    pub action: String,
    pub path: String,
    pub project_root: String,
    pub command: Vec<String>,
}

pub fn prompt_proxy_destination(prompt: &ProxyPrompt) -> Result<Option<PromptDecision>> {
    prompt_decision_with_external_ui(proxy_prompt_request(prompt), None)
}

pub fn prompt_filesystem_access(prompt: &FilesystemPrompt) -> Result<Option<PromptResult>> {
    prompt_filesystem_access_with_environment(prompt, None)
}

pub fn prompt_filesystem_access_with_environment(
    prompt: &FilesystemPrompt,
    prompt_environment: Option<&BTreeMap<String, String>>,
) -> Result<Option<PromptResult>> {
    prompt_result_with_external_ui(filesystem_prompt_request(prompt), prompt_environment)
}

pub(crate) fn approval_prompt_environment() -> BTreeMap<String, String> {
    let mut environment = BTreeMap::new();
    for key in [PROMPT_TTY_PATH_ENV, PROMPT_TTY_FD_ENV] {
        if let Ok(value) = std::env::var(key) {
            if !value.is_empty() {
                environment.insert(key.into(), value);
            }
        }
    }
    if !environment.contains_key(PROMPT_TTY_PATH_ENV) {
        if let Some(path) = current_terminal_path() {
            environment.insert(PROMPT_TTY_PATH_ENV.into(), path);
        }
    }
    for (approval_key, host_key) in APPROVAL_ENV_MAPPINGS {
        let value = approval_prompt_environment_value(approval_key, host_key);
        if let Some((key, value)) = value {
            environment.insert(key, value);
        }
    }
    if crate::app::debug::enabled() {
        environment.insert(crate::app::debug::FORWARDED_DEBUG_ENV.into(), "1".into());
    }
    if let Some(path) = crate::app::debug::log_path() {
        environment.insert(
            crate::app::debug::DEBUG_LOG_ENV.into(),
            path.display().to_string(),
        );
    }
    crate::debug_log!(
        "approval prompt env captured tty_path={} tty_fd={} display={} wayland={} runtime_dir={} debug_log={}",
        environment.contains_key(PROMPT_TTY_PATH_ENV),
        environment.contains_key(PROMPT_TTY_FD_ENV),
        environment.contains_key(APPROVAL_DISPLAY_ENV),
        environment.contains_key(APPROVAL_WAYLAND_DISPLAY_ENV),
        environment.contains_key(APPROVAL_XDG_RUNTIME_DIR_ENV),
        environment.contains_key(crate::app::debug::DEBUG_LOG_ENV),
    );
    environment
}

fn approval_prompt_environment_value(
    approval_key: &str,
    host_key: &str,
) -> Option<(String, String)> {
    std::env::var(approval_key)
        .ok()
        .filter(|value| !value.is_empty())
        .map(|value| (approval_key.into(), value))
        .or_else(|| {
            std::env::var(host_key)
                .ok()
                .filter(|value| !value.is_empty())
                .map(|value| {
                    let key = if approval_key == APPROVAL_PATH_ENV {
                        host_key
                    } else {
                        approval_key
                    };
                    (key.into(), value)
                })
        })
}

pub(crate) fn remove_approval_prompt_environment(command: &mut Command) {
    for key in APPROVAL_ENV_KEYS {
        command.env_remove(key);
    }
}

pub(crate) fn clear_approval_prompt_environment_for_exec() {
    for key in APPROVAL_ENV_KEYS {
        let key = CString::new(*key).expect("approval environment key has no NUL bytes");
        unsafe {
            libc::unsetenv(key.as_ptr());
        }
    }
}

pub(crate) fn lock_approval_prompt_queue() -> ApprovalPromptQueueGuard {
    lock_approval_prompt_queue_with_environment(None)
}

pub(crate) fn lock_approval_prompt_queue_with_environment(
    prompt_environment: Option<&BTreeMap<String, String>>,
) -> ApprovalPromptQueueGuard {
    let process_guard = APPROVAL_PROMPT_QUEUE
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    ApprovalPromptQueueGuard {
        _process_guard: process_guard,
        _file_guard: lock_approval_prompt_file(prompt_environment),
    }
}

fn lock_approval_prompt_file(
    prompt_environment: Option<&BTreeMap<String, String>>,
) -> Option<ApprovalPromptFileGuard> {
    let path = approval_prompt_lock_path(prompt_environment);
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            crate::debug_log!(
                "approval prompt queue lock create-dir failed path={} error={error}",
                parent.display()
            );
            return None;
        }
    }
    crate::debug_log!(
        "approval prompt queue lock waiting path={} forwarded_env={}",
        path.display(),
        prompt_environment.is_some()
    );
    let file = match OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .open(path)
    {
        Ok(file) => file,
        Err(error) => {
            crate::debug_log!("approval prompt queue lock open failed error={error}");
            return None;
        }
    };
    match lock_approval_prompt_file_descriptor(&file) {
        Ok(()) => {
            crate::debug_log!("approval prompt queue lock acquired");
            Some(ApprovalPromptFileGuard { file })
        }
        Err(error) => {
            crate::debug_log!("approval prompt queue lock failed error={error}");
            None
        }
    }
}

fn approval_prompt_lock_path(prompt_environment: Option<&BTreeMap<String, String>>) -> PathBuf {
    prompt_env_value(
        prompt_environment,
        APPROVAL_XDG_RUNTIME_DIR_ENV,
        "XDG_RUNTIME_DIR",
    )
    .map(PathBuf::from)
    .unwrap_or_else(|| {
        std::env::temp_dir().join(format!("condom-runtime-{}", unsafe { libc::geteuid() }))
    })
    .join("condom")
    .join("approval.lock")
}

fn lock_approval_prompt_file_descriptor(file: &File) -> std::io::Result<()> {
    let result = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX) };
    if result == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error())
    }
}

fn unlock_approval_prompt_file(file: &File) -> std::io::Result<()> {
    let result = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_UN) };
    if result == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error())
    }
}

pub fn confirm_init_overwrite(config_path: &Path) -> Result<Option<bool>> {
    let Some(mut tty) = open_prompt_terminal()? else {
        return Ok(None);
    };
    let reader = BufReader::new(tty.try_clone()?);

    confirm_init_overwrite_with_io(config_path, reader, &mut tty).map(Some)
}

fn open_host_prompt_terminal() -> Option<std::fs::File> {
    OpenOptions::new()
        .read(true)
        .write(true)
        .open("/dev/tty")
        .ok()
}

fn open_prompt_terminal() -> Result<Option<std::fs::File>> {
    open_prompt_terminal_with_environment(None)
}

fn open_prompt_terminal_with_environment(
    prompt_environment: Option<&BTreeMap<String, String>>,
) -> Result<Option<std::fs::File>> {
    if prompt_environment.is_none() {
        if let Some(tty) = open_standard_prompt_terminal() {
            return Ok(Some(tty));
        }
    }
    if let Some(path) =
        prompt_env_value(prompt_environment, PROMPT_TTY_PATH_ENV, PROMPT_TTY_PATH_ENV)
    {
        match OpenOptions::new().read(true).write(true).open(path) {
            Ok(tty) => return Ok(Some(tty)),
            Err(error) => crate::debug_log!("approval prompt tty path open failed: {error}"),
        }
    }
    if let Some(fd) = prompt_env_value(prompt_environment, PROMPT_TTY_FD_ENV, PROMPT_TTY_FD_ENV) {
        match OpenOptions::new()
            .read(true)
            .write(true)
            .open(format!("/proc/self/fd/{fd}"))
        {
            Ok(tty) => return Ok(Some(tty)),
            Err(error) => crate::debug_log!("approval prompt tty fd open failed: {error}"),
        }
    }
    if prompt_environment.is_none() {
        return Ok(open_host_prompt_terminal());
    }
    Ok(None)
}

fn current_terminal_path() -> Option<String> {
    (unsafe { libc::isatty(libc::STDIN_FILENO) } == 1)
        .then(|| fs::read_link("/proc/self/fd/0").ok())
        .flatten()
        .filter(|path| path.is_absolute())
        .map(|path| path.display().to_string())
}

fn open_standard_prompt_terminal() -> Option<std::fs::File> {
    if unsafe { libc::isatty(libc::STDIN_FILENO) } != 1 {
        return None;
    }
    OpenOptions::new()
        .read(true)
        .write(true)
        .open("/proc/self/fd/0")
        .ok()
}

fn confirm_init_overwrite_with_io(
    config_path: &Path,
    mut reader: impl BufRead,
    mut writer: impl Write,
) -> Result<bool> {
    writeln!(writer, "condom init found an existing generated config:")?;
    writeln!(writer, "  {}", config_path.display())?;
    writeln!(writer, "Overwrite it and regenerate shims?")?;
    loop {
        write!(writer, "Decision [y/N]: ")?;
        writer.flush()?;

        let mut input = String::new();
        if reader.read_line(&mut input)? == 0 {
            return Ok(false);
        }
        match parse_confirm_decision(&input) {
            Some(decision) => return Ok(decision),
            None => writeln!(writer, "Please type `yes` or `no`.")?,
        }
    }
}

fn parse_prompt_result(input: &str) -> Option<PromptResult> {
    let answer = input.lines().next().unwrap_or_default().trim();
    let (before_subject, subject) = split_prompt_payload(answer, " subject=");
    let (decision_text, filesystem_access) = split_prompt_payload(before_subject, " access=");
    parse_prompt_decision_code(decision_text).map(|decision| PromptResult {
        decision,
        subject: subject.and_then(parse_prompt_subject),
        filesystem_access: filesystem_access.and_then(FilesystemAccessMode::parse),
    })
}

#[cfg(test)]
fn parse_prompt_decision(input: &str) -> Option<PromptDecision> {
    parse_prompt_result(input).map(|result| result.decision)
}

fn parse_prompt_decision_code(answer: &str) -> Option<PromptDecision> {
    let answer = answer.trim().to_ascii_lowercase();
    match answer.as_str() {
        "o" | "once" | "allow once" => Some(PromptDecision::AllowOnce),
        "ai" | "instance" | "allow instance" => Some(PromptDecision::AllowInstance),
        "di" | "deny instance" => Some(PromptDecision::DenyInstance),
        "aa" | "app" | "app/project" | "app project" | "allow app/project"
        | "allow app project" => Some(PromptDecision::AllowAppProject),
        "da" | "deny app/project" | "deny app project" => Some(PromptDecision::DenyAppProject),
        "a" | "project" | "allow project" => Some(PromptDecision::AllowProject),
        "x" | "deny project" => Some(PromptDecision::DenyProject),
        "d" | "deny" | "" => Some(PromptDecision::DenyOnce),
        _ => None,
    }
}

fn split_prompt_payload<'a>(input: &'a str, marker: &str) -> (&'a str, Option<&'a str>) {
    match input.split_once(marker) {
        Some((before, after)) => (before, Some(after)),
        None => (input, None),
    }
}

fn parse_prompt_subject(subject: &str) -> Option<String> {
    let subject = subject.trim();
    let subject = subject
        .strip_prefix('"')
        .and_then(|subject| subject.strip_suffix('"'))
        .or_else(|| {
            subject
                .strip_prefix('\'')
                .and_then(|subject| subject.strip_suffix('\''))
        })
        .unwrap_or(subject)
        .trim();
    (!subject.is_empty()).then(|| subject.into())
}

fn proxy_prompt_request(prompt: &ProxyPrompt) -> ApprovalPromptRequest {
    ApprovalPromptRequest::new(
        "condom blocked a proxy destination",
        vec![
            ApprovalPromptField::new("destination", format!("{}:{}", prompt.host, prompt.port)),
            ApprovalPromptField::new("app", prompt_app(&prompt.command)),
            ApprovalPromptField::new("project", &prompt.project_root),
            ApprovalPromptField::new("command", prompt.command.join(" ")),
        ],
        vec![PROMPT_CHOICES.into()],
    )
}

fn filesystem_prompt_request(prompt: &FilesystemPrompt) -> ApprovalPromptRequest {
    ApprovalPromptRequest::new(
        "condom blocked filesystem access",
        vec![
            ApprovalPromptField::new("action", &prompt.action),
            ApprovalPromptField::new("path", &prompt.path),
            ApprovalPromptField::new("app", prompt_app(&prompt.command)),
            ApprovalPromptField::new("project", &prompt.project_root),
            ApprovalPromptField::new("command", prompt.command.join(" ")),
        ],
        vec![PROMPT_CHOICES.into()],
    )
}

fn prompt_app(command: &[String]) -> String {
    crate::auth::approvals::command_app(command).unwrap_or_else(|| "unknown".into())
}

fn prompt_decision_with_external_ui(
    request: ApprovalPromptRequest,
    prompt_environment: Option<&BTreeMap<String, String>>,
) -> Result<Option<PromptDecision>> {
    prompt_result_with_external_ui(request, prompt_environment)
        .map(|result| result.map(|result| result.decision))
}

fn prompt_result_with_external_ui(
    request: ApprovalPromptRequest,
    prompt_environment: Option<&BTreeMap<String, String>>,
) -> Result<Option<PromptResult>> {
    prompt_result_with_external_ui_using(
        request,
        prompt_environment,
        prompt_result_with_terminal,
        prompt_result_with_approval_gui,
    )
}

fn prompt_result_with_external_ui_using(
    request: ApprovalPromptRequest,
    prompt_environment: Option<&BTreeMap<String, String>>,
    terminal_prompt: impl Fn(
        &ApprovalPromptRequest,
        Option<&BTreeMap<String, String>>,
    ) -> Result<Option<PromptResult>>,
    approval_gui_prompt: impl Fn(
        &ApprovalPromptRequest,
        Option<&BTreeMap<String, String>>,
    ) -> Result<PromptResult>,
) -> Result<Option<PromptResult>> {
    let has_terminal = prompt_environment_has_terminal(prompt_environment);
    let has_display = desktop_display_available(prompt_environment);
    crate::debug_log!(
        "approval prompt environment forwarded={} terminal={} desktop_display={}",
        prompt_environment.is_some(),
        has_terminal,
        has_display,
    );
    if has_display {
        crate::debug_log!("approval prompt backend=approval-gui");
        match approval_gui_prompt(&request, prompt_environment) {
            Ok(result) => return Ok(Some(result)),
            Err(error) => {
                crate::debug_log!("approval prompt approval-gui failed: {error:#}");
                return Err(error)
                    .context("approval GUI failed; terminal fallback disabled while desktop display is available");
            }
        }
    }
    crate::debug_log!("approval prompt backend=terminal");
    if let Some(result) = terminal_prompt(&request, prompt_environment)? {
        return Ok(Some(result));
    }
    crate::debug_log!("approval prompt terminal unavailable");
    if prompt_environment.is_some() {
        crate::debug_log!("approval prompt backend=none");
        return Ok(None);
    }
    crate::debug_log!("approval prompt backend=none");
    Ok(None)
}

fn prompt_environment_has_terminal(prompt_environment: Option<&BTreeMap<String, String>>) -> bool {
    prompt_environment
        .map(|environment| {
            [PROMPT_TTY_PATH_ENV, PROMPT_TTY_FD_ENV]
                .iter()
                .any(|key| environment.get(*key).is_some_and(|value| !value.is_empty()))
        })
        .unwrap_or(false)
}

pub(crate) fn approval_prompt_readiness() -> Result<String, String> {
    if desktop_display_available(None) {
        return approval_gui_readiness();
    }
    if prompt_terminal_ready() {
        return Ok("terminal prompt is available".into());
    }
    approval_gui_readiness()
}

pub(crate) fn approval_gui_readiness() -> Result<String, String> {
    if !desktop_display_available(None) {
        return Err("desktop display is not configured".into());
    }
    let environment = approval_prompt_environment();
    let Some(path) = resolve_first_party_program("condom-approval", Some(&environment)) else {
        return Err("desktop display is set but condom-approval is not available".into());
    };
    crate::debug_log!(
        "approval GUI probe path={} display={} wayland={} dbus={} runtime_dir={}",
        path.display(),
        prompt_env_value(Some(&environment), APPROVAL_DISPLAY_ENV, "DISPLAY").is_some(),
        prompt_env_value(
            Some(&environment),
            APPROVAL_WAYLAND_DISPLAY_ENV,
            "WAYLAND_DISPLAY"
        )
        .is_some(),
        prompt_env_value(
            Some(&environment),
            APPROVAL_DBUS_SESSION_BUS_ADDRESS_ENV,
            "DBUS_SESSION_BUS_ADDRESS",
        )
        .is_some(),
        prompt_env_value(
            Some(&environment),
            APPROVAL_XDG_RUNTIME_DIR_ENV,
            "XDG_RUNTIME_DIR"
        )
        .is_some(),
    );
    let mut command = Command::new(&path);
    command
        .arg("--probe-display")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped());
    apply_prompt_command_environment(&mut command, Some(&environment));
    let output = command
        .output()
        .map_err(|error| format!("failed to launch approval GUI probe: {error}"))?;
    if output.status.success() {
        return Ok(format!(
            "approval GUI can open the display via {}",
            path.display()
        ));
    }
    Err(format!(
        "approval GUI cannot open the display via {}: {}",
        path.display(),
        String::from_utf8_lossy(&output.stderr).trim()
    ))
}

fn prompt_terminal_ready() -> bool {
    open_prompt_terminal_with_environment(None)
        .ok()
        .flatten()
        .is_some()
}

fn prompt_result_with_terminal(
    request: &ApprovalPromptRequest,
    prompt_environment: Option<&BTreeMap<String, String>>,
) -> Result<Option<PromptResult>> {
    let Some(mut tty) = open_prompt_terminal_with_environment(prompt_environment)? else {
        return Ok(None);
    };
    let reader = BufReader::new(tty.try_clone()?);
    prompt_result_with_terminal_io(&request.message_text(), reader, &mut tty).map(Some)
}

fn prompt_result_with_terminal_io(
    message: &str,
    mut reader: impl BufRead,
    mut writer: impl Write,
) -> Result<PromptResult> {
    writeln!(writer, "{message}")?;
    writeln!(
        writer,
        "choices: o=allow once, a=allow project, d=deny once, x=deny project, \
         ai=allow instance, di=deny instance, aa=allow app/project, da=deny app/project"
    )?;
    loop {
        write!(writer, "decision: ")?;
        writer.flush()?;
        let mut input = String::new();
        if reader.read_line(&mut input)? == 0 {
            return Ok(PromptResult {
                decision: PromptDecision::DenyOnce,
                subject: None,
                filesystem_access: None,
            });
        }
        if let Some(result) = parse_prompt_result(&input) {
            return Ok(result);
        }
        writeln!(
            writer,
            "unrecognized; type a choice code (o/a/d/x/ai/di/aa/da)"
        )?;
    }
}

fn prompt_result_with_approval_gui(
    request: &ApprovalPromptRequest,
    prompt_environment: Option<&BTreeMap<String, String>>,
) -> Result<PromptResult> {
    let Some(approval_gui) = resolve_first_party_program("condom-approval", prompt_environment)
    else {
        return Err(anyhow!(
            "approval GUI unavailable: condom-approval not found"
        ));
    };
    crate::debug_log!(
        "approval GUI launch path={} display={} wayland={} dbus={} runtime_dir={}",
        approval_gui.display(),
        prompt_env_value(prompt_environment, APPROVAL_DISPLAY_ENV, "DISPLAY").is_some(),
        prompt_env_value(
            prompt_environment,
            APPROVAL_WAYLAND_DISPLAY_ENV,
            "WAYLAND_DISPLAY"
        )
        .is_some(),
        prompt_env_value(
            prompt_environment,
            APPROVAL_DBUS_SESSION_BUS_ADDRESS_ENV,
            "DBUS_SESSION_BUS_ADDRESS",
        )
        .is_some(),
        prompt_env_value(
            prompt_environment,
            APPROVAL_XDG_RUNTIME_DIR_ENV,
            "XDG_RUNTIME_DIR"
        )
        .is_some(),
    );
    let request_json =
        serde_json::to_string(request).context("failed to encode approval GUI request")?;
    let mut command = Command::new(&approval_gui);
    command
        .arg("--request-json")
        .arg(request_json)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    apply_prompt_command_environment(&mut command, prompt_environment);
    let output = command
        .output()
        .context("failed to launch condom approval GUI")?;
    if !output.status.success() {
        return Err(anyhow!(
            "approval GUI exited with status {}: {}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    if output.stdout.is_empty() {
        return Err(anyhow!("approval GUI exited without writing a decision"));
    }
    if let Some(result) = parse_approval_prompt_response(&output.stdout) {
        return Ok(result);
    }
    let response = String::from_utf8_lossy(&output.stdout);
    parse_prompt_result(&response).ok_or_else(|| {
        anyhow!(
            "approval GUI returned invalid decision `{}`",
            response.lines().next().unwrap_or_default()
        )
    })
}

#[cfg(test)]
fn legacy_prompt_request(message: &str) -> ApprovalPromptRequest {
    let mut lines = message.lines();
    let title = lines.next().unwrap_or("condom approval").to_string();
    ApprovalPromptRequest::new(title, Vec::new(), lines.map(str::to_string).collect())
}

fn parse_approval_prompt_response(output: &[u8]) -> Option<PromptResult> {
    serde_json::from_slice::<ApprovalPromptResponse>(output)
        .ok()?
        .into_prompt_result()
}

fn apply_prompt_command_environment(
    command: &mut Command,
    prompt_environment: Option<&BTreeMap<String, String>>,
) {
    for (approval_key, host_key) in APPROVAL_ENV_MAPPINGS {
        if let Some(value) = prompt_env_value(prompt_environment, approval_key, host_key) {
            command.env(host_key, value);
        }
    }
}

fn resolve_prompt_program(
    program: &str,
    prompt_environment: Option<&BTreeMap<String, String>>,
) -> Option<PathBuf> {
    if program.contains('/') {
        let path = PathBuf::from(program);
        return is_executable_file(&path).then_some(path);
    }
    prompt_env_value(prompt_environment, APPROVAL_PATH_ENV, "PATH").and_then(|path| {
        path.split(':')
            .filter(|entry| !entry.is_empty())
            .map(|entry| PathBuf::from(entry).join(program))
            .find(|candidate| is_executable_file(candidate))
    })
}

fn resolve_first_party_program(
    program: &str,
    prompt_environment: Option<&BTreeMap<String, String>>,
) -> Option<PathBuf> {
    if explicit_prompt_env_value(prompt_environment, APPROVAL_PATH_ENV).is_some() {
        return resolve_prompt_program(program, prompt_environment)
            .or_else(|| resolve_sibling_program(program));
    }
    resolve_sibling_program(program).or_else(|| resolve_prompt_program(program, prompt_environment))
}

fn resolve_sibling_program(program: &str) -> Option<PathBuf> {
    let current_exe = std::env::current_exe().ok()?;
    let candidate = current_exe.parent()?.join(program);
    is_executable_file(&candidate).then_some(candidate)
}

fn is_executable_file(path: &Path) -> bool {
    path.metadata()
        .map(|metadata| metadata.is_file() && metadata.permissions().mode() & 0o111 != 0)
        .unwrap_or(false)
}

fn prompt_env_value(
    prompt_environment: Option<&BTreeMap<String, String>>,
    approval_key: &str,
    host_key: &str,
) -> Option<String> {
    match prompt_environment {
        Some(environment) => environment
            .get(approval_key)
            .or_else(|| environment.get(host_key))
            .filter(|value| !value.is_empty())
            .cloned(),
        None => std::env::var(approval_key)
            .ok()
            .or_else(|| std::env::var(host_key).ok())
            .filter(|value| !value.is_empty()),
    }
}

fn explicit_prompt_env_value(
    prompt_environment: Option<&BTreeMap<String, String>>,
    key: &str,
) -> Option<String> {
    match prompt_environment {
        Some(environment) => environment
            .get(key)
            .filter(|value| !value.is_empty())
            .cloned(),
        None => std::env::var(key).ok().filter(|value| !value.is_empty()),
    }
}

fn desktop_display_available(prompt_environment: Option<&BTreeMap<String, String>>) -> bool {
    prompt_env_value(prompt_environment, APPROVAL_DISPLAY_ENV, "DISPLAY").is_some()
        || prompt_env_value(
            prompt_environment,
            APPROVAL_WAYLAND_DISPLAY_ENV,
            "WAYLAND_DISPLAY",
        )
        .is_some()
}

fn parse_confirm_decision(input: &str) -> Option<bool> {
    let answer = input
        .lines()
        .next()
        .unwrap_or_default()
        .trim()
        .to_ascii_lowercase();
    match answer.as_str() {
        "y" | "yes" => Some(true),
        "n" | "no" | "" => Some(false),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use std::sync::Mutex;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn parses_prompt_choices() {
        assert_eq!(
            parse_prompt_decision("o\n"),
            Some(PromptDecision::AllowOnce)
        );
        assert_eq!(
            parse_prompt_decision("aa\n"),
            Some(PromptDecision::AllowAppProject)
        );
        assert_eq!(
            parse_prompt_decision("ai\n"),
            Some(PromptDecision::AllowInstance)
        );
        assert_eq!(
            parse_prompt_decision("di\n"),
            Some(PromptDecision::DenyInstance)
        );
        assert_eq!(
            parse_prompt_decision("app/project\n"),
            Some(PromptDecision::AllowAppProject)
        );
        assert_eq!(
            parse_prompt_decision("da\n"),
            Some(PromptDecision::DenyAppProject)
        );
        assert_eq!(
            parse_prompt_decision("a\n"),
            Some(PromptDecision::AllowProject)
        );
        assert_eq!(
            parse_prompt_decision("x\n"),
            Some(PromptDecision::DenyProject)
        );
        assert_eq!(parse_prompt_decision("\n"), Some(PromptDecision::DenyOnce));
        assert_eq!(parse_prompt_decision("wat\n"), None);
    }

    #[test]
    fn parses_prompt_result_subject() {
        assert_eq!(
            parse_prompt_result("aa subject=/home/example/.agent/config.toml\n"),
            Some(PromptResult::with_subject(
                PromptDecision::AllowAppProject,
                "/home/example/.agent/config.toml"
            ))
        );
        assert_eq!(
            parse_prompt_result("a subject='/home/example/My Project'\n"),
            Some(PromptResult::with_subject(
                PromptDecision::AllowProject,
                "/home/example/My Project"
            ))
        );
    }

    #[test]
    fn parses_prompt_result_filesystem_access() {
        assert_eq!(
            parse_prompt_result("aa access=read-write subject=/home/example/.agent\n"),
            Some(PromptResult::with_subject_and_access(
                PromptDecision::AllowAppProject,
                "/home/example/.agent",
                Some(FilesystemAccessMode::ReadWrite)
            ))
        );
        assert_eq!(
            parse_prompt_result("a access=write\n"),
            Some(PromptResult::with_filesystem_access(
                PromptDecision::AllowProject,
                FilesystemAccessMode::Write
            ))
        );
    }

    #[test]
    fn parses_confirm_choices() {
        assert_eq!(parse_confirm_decision("yes\n"), Some(true));
        assert_eq!(parse_confirm_decision("y\n"), Some(true));
        assert_eq!(parse_confirm_decision("no\n"), Some(false));
        assert_eq!(parse_confirm_decision("\n"), Some(false));
        assert_eq!(parse_confirm_decision("later\n"), None);
    }

    #[test]
    fn confirm_init_overwrite_retries_invalid_answer() {
        let mut output = Vec::new();
        let decision = confirm_init_overwrite_with_io(
            Path::new("/project/.condom/config.toml"),
            BufReader::new("maybe\nyes\n".as_bytes()),
            &mut output,
        )
        .unwrap();

        assert!(decision);
        let output = String::from_utf8(output).unwrap();
        assert!(output.contains("condom init found an existing generated config"));
        assert!(output.contains("Please type `yes` or `no`."));
    }

    #[test]
    fn confirm_init_overwrite_treats_eof_as_no() {
        let mut output = Vec::new();
        let decision = confirm_init_overwrite_with_io(
            Path::new("/project/.condom/config.toml"),
            BufReader::new("".as_bytes()),
            &mut output,
        )
        .unwrap();

        assert!(!decision);
    }

    #[test]
    fn terminal_prompt_parses_decision_code() {
        let mut output = Vec::new();
        let result = prompt_result_with_terminal_io(
            "allow net-domain example.test?",
            BufReader::new("a\n".as_bytes()),
            &mut output,
        )
        .unwrap();

        assert_eq!(result.decision, PromptDecision::AllowProject);
        let output = String::from_utf8(output).unwrap();
        assert!(output.contains("allow net-domain example.test?"));
        assert!(output.contains("decision:"));
    }

    #[test]
    fn terminal_prompt_retries_unrecognized_then_accepts() {
        let mut output = Vec::new();
        let result = prompt_result_with_terminal_io(
            "allow fs-write /etc/hosts?",
            BufReader::new("bogus\no\n".as_bytes()),
            &mut output,
        )
        .unwrap();

        assert_eq!(result.decision, PromptDecision::AllowOnce);
        let output = String::from_utf8(output).unwrap();
        assert!(output.contains("unrecognized"));
    }

    #[test]
    fn terminal_prompt_treats_eof_as_deny_once() {
        let mut output = Vec::new();
        let result = prompt_result_with_terminal_io(
            "allow net-domain example.test?",
            BufReader::new("".as_bytes()),
            &mut output,
        )
        .unwrap();

        assert_eq!(result.decision, PromptDecision::DenyOnce);
    }

    #[test]
    fn external_prompt_returns_none_without_provider() {
        let environment = BTreeMap::new();

        let decision = prompt_decision_with_external_ui(
            legacy_prompt_request("condom blocked filesystem access"),
            Some(&environment),
        )
        .unwrap();

        assert_eq!(decision, None);
    }

    #[test]
    fn approval_prompt_environment_includes_desktop_values() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_display = std::env::var_os(APPROVAL_DISPLAY_ENV);
        let previous_runtime_dir = std::env::var_os(APPROVAL_XDG_RUNTIME_DIR_ENV);
        std::env::set_var(APPROVAL_DISPLAY_ENV, ":99");
        std::env::set_var(APPROVAL_XDG_RUNTIME_DIR_ENV, "/run/user/123");

        let environment = approval_prompt_environment();

        restore_env(APPROVAL_DISPLAY_ENV, previous_display);
        restore_env(APPROVAL_XDG_RUNTIME_DIR_ENV, previous_runtime_dir);
        assert_eq!(environment.get(APPROVAL_DISPLAY_ENV), Some(&":99".into()));
        assert_eq!(
            environment.get(APPROVAL_XDG_RUNTIME_DIR_ENV),
            Some(&"/run/user/123".into())
        );
    }

    #[test]
    fn approval_prompt_environment_includes_prompt_tty_path() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_tty_path = std::env::var_os(PROMPT_TTY_PATH_ENV);
        std::env::set_var(PROMPT_TTY_PATH_ENV, "/dev/pts/123");

        let environment = approval_prompt_environment();

        restore_env(PROMPT_TTY_PATH_ENV, previous_tty_path);
        assert_eq!(
            environment.get(PROMPT_TTY_PATH_ENV),
            Some(&"/dev/pts/123".into())
        );
    }

    #[test]
    fn approval_prompt_lock_path_uses_forwarded_runtime_dir() {
        let mut environment = BTreeMap::new();
        environment.insert(APPROVAL_XDG_RUNTIME_DIR_ENV.into(), "/run/user/123".into());

        assert_eq!(
            approval_prompt_lock_path(Some(&environment)),
            PathBuf::from("/run/user/123/condom/approval.lock")
        );
    }

    #[test]
    fn approval_prompt_environment_keeps_host_path_as_path_without_explicit_override() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_approval_path = std::env::var_os(APPROVAL_PATH_ENV);
        let previous_path = std::env::var_os("PATH");
        std::env::remove_var(APPROVAL_PATH_ENV);
        std::env::set_var("PATH", "/tmp/bin:/usr/bin");

        let environment = approval_prompt_environment();

        restore_env(APPROVAL_PATH_ENV, previous_approval_path);
        restore_env("PATH", previous_path);
        assert_eq!(environment.get("PATH"), Some(&"/tmp/bin:/usr/bin".into()));
        assert!(!environment.contains_key(APPROVAL_PATH_ENV));
    }

    #[test]
    fn approval_prompt_environment_forwards_debug_flag() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_debug = std::env::var_os("DEBUG");
        let previous_forwarded = std::env::var_os(crate::app::debug::FORWARDED_DEBUG_ENV);
        let previous_log = std::env::var_os(crate::app::debug::DEBUG_LOG_ENV);
        std::env::set_var("DEBUG", "1");
        std::env::remove_var(crate::app::debug::FORWARDED_DEBUG_ENV);
        std::env::set_var(crate::app::debug::DEBUG_LOG_ENV, "/tmp/condom-debug.log");

        let environment = approval_prompt_environment();

        restore_env("DEBUG", previous_debug);
        restore_env(crate::app::debug::FORWARDED_DEBUG_ENV, previous_forwarded);
        restore_env(crate::app::debug::DEBUG_LOG_ENV, previous_log);
        assert_eq!(
            environment.get(crate::app::debug::FORWARDED_DEBUG_ENV),
            Some(&"1".into())
        );
        assert_eq!(
            environment.get(crate::app::debug::DEBUG_LOG_ENV),
            Some(&"/tmp/condom-debug.log".into())
        );
    }

    #[test]
    fn approval_gui_readiness_reports_probe_failure() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_display = std::env::var_os(APPROVAL_DISPLAY_ENV);
        let previous_path = std::env::var_os(APPROVAL_PATH_ENV);
        let temp = tempfile::tempdir().unwrap();
        let bin_dir = temp.path().join("bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let approval = bin_dir.join("condom-approval");
        fs::write(
            &approval,
            "#!/bin/sh\nif [ \"$1\" = \"--probe-display\" ]; then printf '%s\\n' 'display denied' >&2; exit 17; fi\nprintf '%s\\n' a\n",
        )
        .unwrap();
        fs::set_permissions(&approval, fs::Permissions::from_mode(0o755)).unwrap();
        std::env::set_var(APPROVAL_DISPLAY_ENV, ":99");
        std::env::set_var(APPROVAL_PATH_ENV, bin_dir.display().to_string());

        let message = approval_gui_readiness().unwrap_err();

        restore_env(APPROVAL_DISPLAY_ENV, previous_display);
        restore_env(APPROVAL_PATH_ENV, previous_path);
        assert!(message.contains("approval GUI cannot open the display"));
        assert!(message.contains("display denied"));
    }

    #[test]
    fn external_prompt_reads_decision_from_approval_gui_provider() {
        let temp = tempfile::tempdir().unwrap();
        let bin_dir = fake_approval_gui_bin(&temp, "aa", None);
        let mut environment = BTreeMap::new();
        environment.insert(APPROVAL_DISPLAY_ENV.into(), ":99".into());
        environment.insert(
            APPROVAL_PATH_ENV.into(),
            format!(
                "{}:{}",
                bin_dir.display(),
                std::env::var("PATH").unwrap_or_default()
            ),
        );

        let decision = prompt_decision_with_external_ui(
            legacy_prompt_request("condom blocked filesystem access"),
            Some(&environment),
        )
        .unwrap();

        assert_eq!(decision, Some(PromptDecision::AllowAppProject));
    }

    #[test]
    fn external_prompt_reads_json_decision_from_approval_gui_provider() {
        let temp = tempfile::tempdir().unwrap();
        let response = serde_json::to_string(&ApprovalPromptResponse::from_prompt_result(
            PromptResult::with_subject_and_access(
                PromptDecision::AllowAppProject,
                "/home/example/.agent",
                Some(FilesystemAccessMode::ReadWrite),
            ),
        ))
        .unwrap();
        let bin_dir = fake_approval_gui_bin(&temp, &response, None);
        let mut environment = BTreeMap::new();
        environment.insert(APPROVAL_DISPLAY_ENV.into(), ":99".into());
        environment.insert(APPROVAL_PATH_ENV.into(), bin_dir.display().to_string());

        let result = prompt_filesystem_access_with_environment(
            &FilesystemPrompt {
                action: "read".into(),
                path: "/home/example/.agent/config.toml".into(),
                project_root: "/project".into(),
                command: vec!["agent".into()],
            },
            Some(&environment),
        )
        .unwrap();

        assert_eq!(
            result,
            Some(PromptResult::with_subject_and_access(
                PromptDecision::AllowAppProject,
                "/home/example/.agent",
                Some(FilesystemAccessMode::ReadWrite)
            ))
        );
    }

    #[test]
    fn filesystem_prompt_reads_subject_from_approval_gui_provider() {
        let temp = tempfile::tempdir().unwrap();
        let bin_dir = fake_approval_gui_bin(&temp, "aa subject=/home/example/.agent", None);
        let mut environment = BTreeMap::new();
        environment.insert(APPROVAL_DISPLAY_ENV.into(), ":99".into());
        environment.insert(APPROVAL_PATH_ENV.into(), bin_dir.display().to_string());

        let result = prompt_filesystem_access_with_environment(
            &FilesystemPrompt {
                action: "read".into(),
                path: "/home/example/.agent/config.toml".into(),
                project_root: "/project".into(),
                command: vec!["agent".into()],
            },
            Some(&environment),
        )
        .unwrap();

        assert_eq!(
            result,
            Some(PromptResult::with_subject(
                PromptDecision::AllowAppProject,
                "/home/example/.agent"
            ))
        );
    }

    #[test]
    fn proxy_prompt_uses_external_approval_gui_provider() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_path = std::env::var_os(APPROVAL_PATH_ENV);
        let previous_display = std::env::var_os(APPROVAL_DISPLAY_ENV);
        let temp = tempfile::tempdir().unwrap();
        let bin_dir = fake_approval_gui_bin(&temp, "o", None);
        std::env::set_var(
            APPROVAL_PATH_ENV,
            format!(
                "{}:{}",
                bin_dir.display(),
                std::env::var("PATH").unwrap_or_default()
            ),
        );
        std::env::set_var(APPROVAL_DISPLAY_ENV, ":99");

        let decision = prompt_proxy_destination(&ProxyPrompt {
            host: "example.test".into(),
            port: 443,
            project_root: "/project".into(),
            command: vec!["curl".into(), "example.test".into()],
        })
        .unwrap();

        restore_env(APPROVAL_PATH_ENV, previous_path);
        restore_env(APPROVAL_DISPLAY_ENV, previous_display);
        assert_eq!(decision, Some(PromptDecision::AllowOnce));
    }

    #[test]
    fn approval_gui_receives_prompt_context() {
        let temp = tempfile::tempdir().unwrap();
        let args_path = temp.path().join("approval-args");
        let bin_dir = fake_approval_gui_bin(&temp, "a", Some(&args_path));
        let mut environment = BTreeMap::new();
        environment.insert(APPROVAL_DISPLAY_ENV.into(), ":99".into());
        environment.insert(APPROVAL_PATH_ENV.into(), bin_dir.display().to_string());

        let result = prompt_filesystem_access_with_environment(
            &FilesystemPrompt {
                action: "read".into(),
                path: "/etc/issue".into(),
                project_root: "/project".into(),
                command: vec!["cat".into(), "/etc/issue".into()],
            },
            Some(&environment),
        )
        .unwrap();

        assert_eq!(result.unwrap().decision, PromptDecision::AllowProject);
        let args = fs::read_to_string(args_path).unwrap();
        assert!(args.contains("--request-json"));
        assert!(args.contains("condom blocked filesystem access"));
        assert!(args.contains("/etc/issue"));
    }

    #[test]
    fn desktop_prompt_reports_failing_approval_gui_provider() {
        let temp = tempfile::tempdir().unwrap();
        let bin_dir = temp.path().join("bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let approval = bin_dir.join("condom-approval");
        fs::write(
            &approval,
            "#!/bin/sh\nprintf '%s\\n' 'display denied' >&2\nexit 17\n",
        )
        .unwrap();
        fs::set_permissions(&approval, fs::Permissions::from_mode(0o755)).unwrap();
        let mut environment = BTreeMap::new();
        environment.insert(APPROVAL_DISPLAY_ENV.into(), ":99".into());
        environment.insert(APPROVAL_PATH_ENV.into(), bin_dir.display().to_string());

        let error = prompt_decision_with_external_ui(
            legacy_prompt_request("condom blocked filesystem access"),
            Some(&environment),
        )
        .unwrap_err();
        let message = format!("{error:#}");

        assert!(message.contains("approval GUI failed; terminal fallback disabled"));
        assert!(message.contains("approval GUI exited with status"));
        assert!(message.contains("display denied"));
    }

    #[test]
    fn desktop_prompt_does_not_fall_back_to_terminal_when_approval_gui_fails() {
        let mut environment = BTreeMap::new();
        environment.insert(APPROVAL_DISPLAY_ENV.into(), ":99".into());
        environment.insert(PROMPT_TTY_PATH_ENV.into(), "/dev/pts/123".into());
        let terminal_called = Cell::new(false);

        let error = prompt_result_with_external_ui_using(
            legacy_prompt_request("condom blocked filesystem access"),
            Some(&environment),
            |_, _| {
                terminal_called.set(true);
                Ok(Some(PromptResult::new(PromptDecision::AllowOnce)))
            },
            |_, _| Err(anyhow!("gui failed")),
        )
        .unwrap_err();
        let message = format!("{error:#}");

        assert!(!terminal_called.get());
        assert!(message.contains("approval GUI failed; terminal fallback disabled"));
        assert!(message.contains("gui failed"));
    }

    #[test]
    fn desktop_prompt_ignores_terminal_popup_provider() {
        let temp = tempfile::tempdir().unwrap();
        let bin_dir = fake_approval_gui_bin(&temp, "a", None);
        let tmux = bin_dir.join("tmux");
        fs::write(&tmux, "#!/bin/sh\nprintf '%s\\n' d\n").unwrap();
        fs::set_permissions(&tmux, fs::Permissions::from_mode(0o755)).unwrap();
        let mut environment = BTreeMap::new();
        environment.insert(APPROVAL_DISPLAY_ENV.into(), ":99".into());
        environment.insert(APPROVAL_PATH_ENV.into(), bin_dir.display().to_string());
        environment.insert("TMUX".into(), "fake".into());

        let decision = prompt_decision_with_external_ui(
            legacy_prompt_request("condom blocked filesystem access"),
            Some(&environment),
        )
        .unwrap();

        assert_eq!(decision, Some(PromptDecision::AllowProject));
    }

    fn fake_approval_gui_bin(
        temp: &tempfile::TempDir,
        decision: &str,
        args_path: Option<&Path>,
    ) -> PathBuf {
        let bin_dir = temp.path().join("bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let approval = bin_dir.join("condom-approval");
        let capture_args = args_path
            .map(|path| {
                format!(
                    "printf '%s\\n' \"$@\" > {}\n",
                    shell_quote(&path.display().to_string())
                )
            })
            .unwrap_or_default();
        fs::write(
            &approval,
            format!(
                "#!/bin/sh\n{}printf '%s\\n' {}\n",
                capture_args,
                shell_quote(decision)
            ),
        )
        .unwrap();
        fs::set_permissions(&approval, fs::Permissions::from_mode(0o755)).unwrap();
        bin_dir
    }

    fn shell_quote(value: &str) -> String {
        format!("'{}'", value.replace('\'', "'\\''"))
    }

    fn restore_env(key: &str, value: Option<std::ffi::OsString>) {
        if let Some(value) = value {
            std::env::set_var(key, value);
        } else {
            std::env::remove_var(key);
        }
    }
}
