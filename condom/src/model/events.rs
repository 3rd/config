use std::fs::{self, OpenOptions};
use std::io::{self, BufRead, BufReader, Read, Seek, SeekFrom, Write};
#[cfg(unix)]
use std::os::fd::AsRawFd;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::auth::approvals::ApprovalKind;
use crate::model::config::ExecutionMode;
use crate::model::project::ProjectContext;

pub const EVENT_SCHEMA_VERSION: u32 = 2;
const EVENT_LOG_TAIL_CHUNK_BYTES: u64 = 8192;

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum EventType {
    Filesystem,
    Network,
    Exec,
    Proxy,
    Prompt,
    Approval,
    ReviewApply,
    Runtime,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Decision {
    Allowed,
    Denied,
    Prompted,
    Redacted,
    Proxied,
    Injected,
    Accepted,
    Rejected,
    Failed,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum DecisionSource {
    Default,
    Config,
    Approval,
    Prompt,
    Proxy,
    Helper,
    Runtime,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Event {
    pub schema_version: u32,
    pub timestamp: DateTime<Utc>,
    pub event_type: EventType,
    pub project_id: String,
    pub project_root: String,
    pub mode: ExecutionMode,
    pub command: Vec<String>,
    pub subject: String,
    pub decision: Decision,
    pub decision_source: DecisionSource,
    pub suggested_allow: Option<String>,
    pub reason: String,
}

impl Event {
    pub fn runtime_started(
        project: &ProjectContext,
        mode: ExecutionMode,
        command: &[String],
    ) -> Self {
        Self {
            schema_version: EVENT_SCHEMA_VERSION,
            timestamp: Utc::now(),
            event_type: EventType::Runtime,
            project_id: project.id.clone(),
            project_root: project.root.display().to_string(),
            mode,
            command: redact_command(command),
            subject: "runtime-exec".into(),
            decision: Decision::Allowed,
            decision_source: DecisionSource::Runtime,
            suggested_allow: None,
            reason: "starting command through fence".into(),
        }
    }

    pub fn runtime_finished(
        project: &ProjectContext,
        mode: ExecutionMode,
        command: &[String],
        code: i32,
    ) -> Self {
        Self {
            schema_version: EVENT_SCHEMA_VERSION,
            timestamp: Utc::now(),
            event_type: EventType::Runtime,
            project_id: project.id.clone(),
            project_root: project.root.display().to_string(),
            mode,
            command: redact_command(command),
            subject: "runtime-exec".into(),
            decision: if code == 0 {
                Decision::Allowed
            } else {
                Decision::Failed
            },
            decision_source: DecisionSource::Runtime,
            suggested_allow: None,
            reason: format!("command exited with status {code}"),
        }
    }

    pub fn runtime_denied(
        project: &ProjectContext,
        mode: ExecutionMode,
        command: &[String],
        reason: &str,
    ) -> Self {
        Self {
            schema_version: EVENT_SCHEMA_VERSION,
            timestamp: Utc::now(),
            event_type: EventType::Runtime,
            project_id: project.id.clone(),
            project_root: project.root.display().to_string(),
            mode,
            command: redact_command(command),
            subject: "runtime-exec".into(),
            decision: Decision::Denied,
            decision_source: DecisionSource::Runtime,
            suggested_allow: None,
            reason: redact_reason(reason),
        }
    }

    pub fn proxy_decision(
        project: &ProjectContext,
        mode: ExecutionMode,
        command: &[String],
        subject: &str,
        decision: Decision,
        reason: &str,
    ) -> Self {
        Self {
            schema_version: EVENT_SCHEMA_VERSION,
            timestamp: Utc::now(),
            event_type: EventType::Proxy,
            project_id: project.id.clone(),
            project_root: project.root.display().to_string(),
            mode,
            command: redact_command(command),
            subject: subject.to_string(),
            decision,
            decision_source: DecisionSource::Proxy,
            suggested_allow: None,
            reason: redact_reason(reason),
        }
    }

    pub fn prompt_decision(
        project: &ProjectContext,
        mode: ExecutionMode,
        command: &[String],
        subject: &str,
        decision: Decision,
        reason: &str,
    ) -> Self {
        Self::prompt_decision_for_kind(
            project,
            mode,
            command,
            ApprovalKind::NetDomain,
            subject,
            decision,
            reason,
        )
    }

    pub fn prompt_decision_for_kind(
        project: &ProjectContext,
        mode: ExecutionMode,
        command: &[String],
        kind: ApprovalKind,
        subject: &str,
        decision: Decision,
        reason: &str,
    ) -> Self {
        Self {
            schema_version: EVENT_SCHEMA_VERSION,
            timestamp: Utc::now(),
            event_type: EventType::Prompt,
            project_id: project.id.clone(),
            project_root: project.root.display().to_string(),
            mode,
            command: redact_command(command),
            subject: subject.to_string(),
            decision,
            decision_source: DecisionSource::Prompt,
            suggested_allow: Some(suggested_allow(kind, subject)),
            reason: redact_reason(reason),
        }
    }

    pub fn approval_decision(
        project: &ProjectContext,
        mode: ExecutionMode,
        command: &[String],
        subject: &str,
        decision: Decision,
        reason: &str,
    ) -> Self {
        Self {
            schema_version: EVENT_SCHEMA_VERSION,
            timestamp: Utc::now(),
            event_type: EventType::Approval,
            project_id: project.id.clone(),
            project_root: project.root.display().to_string(),
            mode,
            command: redact_command(command),
            subject: subject.to_string(),
            decision,
            decision_source: DecisionSource::Approval,
            suggested_allow: None,
            reason: redact_reason(reason),
        }
    }

    pub fn filesystem_decision(
        project: &ProjectContext,
        mode: ExecutionMode,
        command: &[String],
        subject: &str,
        decision: Decision,
        reason: &str,
    ) -> Self {
        Self {
            schema_version: EVENT_SCHEMA_VERSION,
            timestamp: Utc::now(),
            event_type: EventType::Filesystem,
            project_id: project.id.clone(),
            project_root: project.root.display().to_string(),
            mode,
            command: redact_command(command),
            subject: subject.to_string(),
            decision,
            decision_source: DecisionSource::Runtime,
            suggested_allow: None,
            reason: redact_reason(reason),
        }
    }
}

fn suggested_allow(kind: ApprovalKind, subject: &str) -> String {
    format!("condom allow add {} {subject}", kind.cli_name())
}

pub(crate) fn redact_command(command: &[String]) -> Vec<String> {
    let mut redacted = Vec::with_capacity(command.len());
    let mut redact_next = false;
    for arg in command {
        let lower = arg.to_ascii_lowercase();
        if redact_next {
            redacted.push("<redacted>".into());
            redact_next = false;
            continue;
        }
        if matches!(
            lower.as_str(),
            "--token" | "--password" | "--secret" | "--api-key" | "--auth-token"
        ) {
            redacted.push(arg.clone());
            redact_next = true;
        } else {
            redacted.push(redact_reason(arg));
        }
    }
    redacted
}

pub fn redact_reason(reason: &str) -> String {
    let markers = ["token=", "password=", "secret=", "authorization="];
    let lower = reason.to_ascii_lowercase();
    let mut redacted = String::new();
    let mut cursor = 0;

    while cursor < reason.len() {
        let next = markers
            .iter()
            .filter_map(|marker| {
                lower[cursor..]
                    .find(marker)
                    .map(|offset| (cursor + offset, *marker))
            })
            .min_by_key(|(index, _)| *index);
        let Some((start, marker)) = next else {
            redacted.push_str(&reason[cursor..]);
            break;
        };
        let value_start = start + marker.len();
        let value_end = reason[value_start..]
            .find(|ch: char| ch.is_whitespace() || ch == '&')
            .map(|offset| value_start + offset)
            .unwrap_or(reason.len());
        redacted.push_str(&reason[cursor..value_start]);
        redacted.push_str("<redacted>");
        cursor = value_end;
    }

    redacted
}

#[derive(Clone)]
pub struct EventLog {
    path: PathBuf,
}

impl EventLog {
    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn append(&self, event: &Event) -> Result<()> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("failed to create {}", parent.display()))?;
        }
        let mut file = match open_append_file(&self.path) {
            Ok(file) => file,
            Err(error) if error.kind() == io::ErrorKind::PermissionDenied => {
                match rotate_blocked_event_log(&self.path) {
                    Ok(_) => open_append_file(&self.path)
                        .with_context(|| format!("failed to open {}", self.path.display()))?,
                    Err(error) => {
                        return Err(error)
                            .with_context(|| format!("failed to rotate {}", self.path.display()))
                    }
                }
            }
            Err(error) => {
                return Err(error)
                    .with_context(|| format!("failed to open {}", self.path.display()));
            }
        };
        let mut record = serde_json::to_vec(event)?;
        record.push(b'\n');
        write_event_record(&mut file, &record)
            .with_context(|| format!("failed to write {}", self.path.display()))
    }

    pub fn append_best_effort(&self, event: &Event) {
        let _ = self.append(event);
    }

    pub fn list(&self) -> Result<Vec<Event>> {
        if !self.path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(&self.path)
            .with_context(|| format!("failed to read {}", self.path.display()))?;
        content.lines().try_fold(Vec::new(), |mut events, line| {
            events.extend(parse_event_line(line)?);
            Ok(events)
        })
    }

    pub fn count(&self) -> Result<usize> {
        if !self.path.exists() {
            return Ok(0);
        }
        let file = fs::File::open(&self.path)
            .with_context(|| format!("failed to open {}", self.path.display()))?;
        let reader = BufReader::new(file);
        reader.lines().try_fold(0usize, |count, line| {
            let line = line.with_context(|| format!("failed to read {}", self.path.display()))?;
            Ok(count + parse_event_line(&line)?.len())
        })
    }

    pub fn list_recent(&self, limit: usize) -> Result<Vec<Event>> {
        self.list_recent_matching(limit, |_| true)
    }

    pub fn list_recent_matching<F>(&self, limit: usize, predicate: F) -> Result<Vec<Event>>
    where
        F: Fn(&Event) -> bool,
    {
        if limit == 0 || !self.path.exists() {
            return Ok(Vec::new());
        }
        let mut file = fs::File::open(&self.path)
            .with_context(|| format!("failed to open {}", self.path.display()))?;
        let mut position = file
            .metadata()
            .with_context(|| format!("failed to inspect {}", self.path.display()))?
            .len();
        let mut prefix = Vec::new();
        let mut matches = Vec::new();
        while position > 0 && matches.len() < limit {
            let read_len = position.min(EVENT_LOG_TAIL_CHUNK_BYTES) as usize;
            position -= read_len as u64;
            file.seek(SeekFrom::Start(position))
                .with_context(|| format!("failed to seek {}", self.path.display()))?;
            let mut chunk = vec![0; read_len];
            file.read_exact(&mut chunk)
                .with_context(|| format!("failed to read {}", self.path.display()))?;

            chunk.extend_from_slice(&prefix);
            let complete = if position > 0 {
                if let Some(offset) = chunk.iter().position(|byte| *byte == b'\n') {
                    let complete = chunk.split_off(offset + 1);
                    prefix = chunk;
                    complete
                } else {
                    prefix = chunk;
                    continue;
                }
            } else {
                chunk
            };

            for line in complete.split(|byte| *byte == b'\n').rev() {
                if line.iter().all(|byte| byte.is_ascii_whitespace()) {
                    continue;
                }
                let line = std::str::from_utf8(line)
                    .context("failed to decode event log line as utf-8")?
                    .trim_end_matches('\r');
                let events = parse_event_line(line)?;
                for event in events.into_iter().rev() {
                    if predicate(&event) {
                        matches.push(event);
                        if matches.len() == limit {
                            break;
                        }
                    }
                }
                if matches.len() == limit {
                    break;
                }
            }
        }
        matches.reverse();
        Ok(matches)
    }
}

fn parse_event_line(line: &str) -> Result<Vec<Event>> {
    let line = line.trim();
    if line.is_empty() {
        return Ok(Vec::new());
    }
    let mut events = Vec::new();
    let stream = serde_json::Deserializer::from_str(line).into_iter::<serde_json::Value>();
    for value in stream {
        let value = value.context("failed to parse event json line")?;
        // tolerate records written by a different schema version rather than misreading them
        if value
            .get("schemaVersion")
            .and_then(serde_json::Value::as_u64)
            != Some(u64::from(EVENT_SCHEMA_VERSION))
        {
            continue;
        }
        events.push(serde_json::from_value(value).context("failed to parse event json line")?);
    }
    Ok(events)
}

#[cfg(unix)]
fn write_event_record(file: &mut fs::File, record: &[u8]) -> io::Result<()> {
    let fd = file.as_raw_fd();
    if unsafe { libc::flock(fd, libc::LOCK_EX) } != 0 {
        return Err(io::Error::last_os_error());
    }
    let write_result = file.write_all(record);
    let unlock_result = unsafe { libc::flock(fd, libc::LOCK_UN) };
    write_result?;
    if unlock_result != 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

#[cfg(not(unix))]
fn write_event_record(file: &mut fs::File, record: &[u8]) -> io::Result<()> {
    file.write_all(record)
}

fn open_append_file(path: &Path) -> io::Result<fs::File> {
    OpenOptions::new().create(true).append(true).open(path)
}

fn rotate_blocked_event_log(path: &Path) -> io::Result<PathBuf> {
    let parent = path.parent().ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            "event log path has no parent directory",
        )
    })?;
    let file_name = path.file_name().ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            "event log path has no file name",
        )
    })?;
    let file_name = file_name.to_string_lossy();
    for index in 0..100 {
        let candidate = parent.join(format!(
            "{file_name}.blocked-{}-{index}",
            std::process::id()
        ));
        match fs::rename(path, &candidate) {
            Ok(()) => return Ok(candidate),
            Err(error) if error.kind() == io::ErrorKind::AlreadyExists => continue,
            Err(error) => return Err(error),
        }
    }
    Err(io::Error::new(
        io::ErrorKind::AlreadyExists,
        "no available blocked event log path",
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[cfg(unix)]
    use std::os::unix::fs::PermissionsExt;

    #[test]
    fn redacts_secret_like_reason_values() {
        assert_eq!(
            redact_reason("failed token=abc password=hunter2 done"),
            "failed token=<redacted> password=<redacted> done"
        );
    }

    #[test]
    fn list_skips_records_with_mismatched_schema_version() {
        let temp = tempfile::tempdir().unwrap();
        let path = temp.path().join("events.jsonl");
        let project = ProjectContext {
            root: std::path::PathBuf::from("/tmp/project"),
            id: "id".into(),
            origin: None,
        };
        let event_log = EventLog::new(path.clone());
        event_log
            .append(&Event::proxy_decision(
                &project,
                ExecutionMode::Run,
                &["npm".into()],
                "host.test:443",
                Decision::Denied,
                "blocked",
            ))
            .unwrap();
        let mut future = serde_json::to_value(Event::proxy_decision(
            &project,
            ExecutionMode::Run,
            &["npm".into()],
            "future.test:443",
            Decision::Denied,
            "blocked",
        ))
        .unwrap();
        future["schemaVersion"] = serde_json::json!(EVENT_SCHEMA_VERSION + 1);
        let mut line = serde_json::to_string(&future).unwrap();
        line.push('\n');
        let mut file = fs::OpenOptions::new().append(true).open(&path).unwrap();
        file.write_all(line.as_bytes()).unwrap();

        let events = event_log.list().unwrap();
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].subject, "host.test:443");
    }

    #[test]
    fn redacts_secret_like_command_arguments() {
        let project = ProjectContext {
            root: std::path::PathBuf::from("/tmp/project"),
            id: "id".into(),
            origin: None,
        };
        let event = Event::runtime_denied(
            &project,
            ExecutionMode::Run,
            &[
                "tool".into(),
                "--token".into(),
                "abc".into(),
                "password=hunter2".into(),
            ],
            "denied",
        );

        assert_eq!(event.command[2], "<redacted>");
        assert_eq!(event.command[3], "password=<redacted>");
    }

    #[test]
    fn list_recent_returns_bounded_tail() {
        let temp = tempfile::tempdir().unwrap();
        let event_log = EventLog::new(temp.path().join("events.jsonl"));
        let project = ProjectContext {
            root: std::path::PathBuf::from("/tmp/project"),
            id: "id".into(),
            origin: None,
        };
        for index in 0..5 {
            event_log
                .append(&Event::proxy_decision(
                    &project,
                    ExecutionMode::Run,
                    &["npm".into()],
                    &format!("host-{index}.test:443"),
                    Decision::Denied,
                    "blocked",
                ))
                .unwrap();
        }

        let events = event_log.list_recent(2).unwrap();

        assert_eq!(event_log.count().unwrap(), 5);
        assert_eq!(
            events
                .iter()
                .map(|event| event.subject.as_str())
                .collect::<Vec<_>>(),
            vec!["host-3.test:443", "host-4.test:443"]
        );
    }

    #[test]
    fn list_accepts_concatenated_event_records() {
        let temp = tempfile::tempdir().unwrap();
        let path = temp.path().join("events.jsonl");
        let project = ProjectContext {
            root: std::path::PathBuf::from("/tmp/project"),
            id: "id".into(),
            origin: None,
        };
        let first = Event::proxy_decision(
            &project,
            ExecutionMode::Run,
            &["npm".into()],
            "first.test:443",
            Decision::Denied,
            "blocked",
        );
        let second = Event::proxy_decision(
            &project,
            ExecutionMode::Run,
            &["npm".into()],
            "second.test:443",
            Decision::Allowed,
            "allowed",
        );
        fs::write(
            &path,
            format!(
                "{}{}\n",
                serde_json::to_string(&first).unwrap(),
                serde_json::to_string(&second).unwrap()
            ),
        )
        .unwrap();
        let event_log = EventLog::new(path);

        let events = event_log.list().unwrap();

        assert_eq!(
            events
                .iter()
                .map(|event| event.subject.as_str())
                .collect::<Vec<_>>(),
            vec!["first.test:443", "second.test:443"]
        );
        assert_eq!(event_log.count().unwrap(), 2);
    }

    #[test]
    fn list_recent_matching_accepts_concatenated_event_records() {
        let temp = tempfile::tempdir().unwrap();
        let path = temp.path().join("events.jsonl");
        let event_log = EventLog::new(path.clone());
        let project = ProjectContext {
            root: std::path::PathBuf::from("/tmp/project"),
            id: "id".into(),
            origin: None,
        };
        for index in 0..40 {
            event_log
                .append(&Event::runtime_started(
                    &project,
                    ExecutionMode::Run,
                    &[format!("command-{index}")],
                ))
                .unwrap();
        }
        let first = Event::proxy_decision(
            &project,
            ExecutionMode::Run,
            &["npm".into()],
            "first.test:443",
            Decision::Denied,
            "blocked",
        );
        let second = Event::proxy_decision(
            &project,
            ExecutionMode::Run,
            &["npm".into()],
            "second.test:443",
            Decision::Denied,
            "blocked",
        );
        let existing = fs::read_to_string(&path).unwrap();
        let concatenated = format!(
            "{}{}\n",
            serde_json::to_string(&first).unwrap(),
            serde_json::to_string(&second).unwrap()
        );
        fs::write(&path, format!("{existing}{concatenated}")).unwrap();

        let events = event_log
            .list_recent_matching(2, |event| event.decision == Decision::Denied)
            .unwrap();

        assert_eq!(
            events
                .iter()
                .map(|event| event.subject.as_str())
                .collect::<Vec<_>>(),
            vec!["first.test:443", "second.test:443"]
        );
    }

    #[cfg(unix)]
    #[test]
    fn append_rotates_permission_denied_log_and_retries() {
        let temp = tempfile::tempdir().unwrap();
        let path = temp.path().join("events.jsonl");
        fs::write(&path, "stale\n").unwrap();
        fs::set_permissions(&path, fs::Permissions::from_mode(0o000)).unwrap();
        let event_log = EventLog::new(path.clone());
        let project = ProjectContext {
            root: std::path::PathBuf::from("/tmp/project"),
            id: "id".into(),
            origin: None,
        };

        event_log
            .append(&Event::runtime_started(
                &project,
                ExecutionMode::Run,
                &["true".into()],
            ))
            .unwrap();

        let events = event_log.list().unwrap();
        let blocked_logs = fs::read_dir(temp.path())
            .unwrap()
            .filter_map(|entry| {
                let entry = entry.unwrap();
                let name = entry.file_name().to_string_lossy().into_owned();
                name.starts_with("events.jsonl.blocked-")
                    .then_some(entry.path())
            })
            .collect::<Vec<_>>();

        assert_eq!(events.len(), 1);
        assert_eq!(blocked_logs.len(), 1);
        fs::set_permissions(&blocked_logs[0], fs::Permissions::from_mode(0o600)).unwrap();
        assert_eq!(fs::read_to_string(&blocked_logs[0]).unwrap(), "stale\n");
    }

    #[cfg(unix)]
    #[test]
    fn append_reports_unwritable_event_path() {
        let temp = tempfile::tempdir().unwrap();
        let parent_file = temp.path().join("state");
        fs::write(&parent_file, "not a directory").unwrap();
        let event_log = EventLog::new(parent_file.join("events.jsonl"));
        let project = ProjectContext {
            root: std::path::PathBuf::from("/tmp/project"),
            id: "id".into(),
            origin: None,
        };

        let error = event_log
            .append(&Event::runtime_started(
                &project,
                ExecutionMode::Run,
                &["true".into()],
            ))
            .unwrap_err();

        assert!(error.to_string().contains("failed to create"));
        event_log.append_best_effort(&Event::runtime_started(
            &project,
            ExecutionMode::Run,
            &["true".into()],
        ));
    }

    #[test]
    fn list_recent_matching_finds_older_matching_events() {
        let temp = tempfile::tempdir().unwrap();
        let event_log = EventLog::new(temp.path().join("events.jsonl"));
        let project = ProjectContext {
            root: std::path::PathBuf::from("/tmp/project"),
            id: "id".into(),
            origin: None,
        };
        event_log
            .append(&Event::proxy_decision(
                &project,
                ExecutionMode::Run,
                &["npm".into()],
                "blocked.example:443",
                Decision::Denied,
                "blocked",
            ))
            .unwrap();
        for index in 0..600 {
            event_log
                .append(&Event::runtime_started(
                    &project,
                    ExecutionMode::Run,
                    &[format!("command-{index}")],
                ))
                .unwrap();
        }

        let events = event_log
            .list_recent_matching(1, |event| event.decision == Decision::Denied)
            .unwrap();

        assert_eq!(events.len(), 1);
        assert_eq!(events[0].subject, "blocked.example:443");
    }

    #[test]
    fn list_recent_zero_returns_no_events() {
        let temp = tempfile::tempdir().unwrap();
        let event_log = EventLog::new(temp.path().join("events.jsonl"));
        let project = ProjectContext {
            root: std::path::PathBuf::from("/tmp/project"),
            id: "id".into(),
            origin: None,
        };
        event_log
            .append(&Event::runtime_started(
                &project,
                ExecutionMode::Run,
                &["true".into()],
            ))
            .unwrap();

        assert!(event_log.list_recent(0).unwrap().is_empty());
    }
}
