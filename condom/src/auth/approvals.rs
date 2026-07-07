use std::collections::BTreeMap;
use std::fs::{self, File, OpenOptions};
use std::os::fd::AsRawFd;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use chrono::{DateTime, Duration, Utc};
use clap::ValueEnum;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{model::policy_pattern::policy_pattern_matches, model::state::StatePaths};

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize, ValueEnum)]
#[serde(rename_all = "kebab-case")]
pub enum ApprovalKind {
    NetDomain,
    NetPort,
    FsRead,
    FsWrite,
    FsExec,
    Command,
}

impl ApprovalKind {
    pub fn cli_name(self) -> &'static str {
        match self {
            Self::NetDomain => "net-domain",
            Self::NetPort => "net-port",
            Self::FsRead => "fs-read",
            Self::FsWrite => "fs-write",
            Self::FsExec => "fs-exec",
            Self::Command => "command",
        }
    }

    pub fn filesystem_action(self) -> Option<&'static str> {
        match self {
            Self::FsRead => Some("read"),
            Self::FsWrite => Some("write"),
            Self::FsExec => Some("execute"),
            _ => None,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize, ValueEnum)]
#[serde(rename_all = "kebab-case")]
pub enum ApprovalScope {
    AppProject,
    Project,
    Global,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ApprovalDecision {
    Allow,
    Deny,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Approval {
    pub id: Uuid,
    pub decision: ApprovalDecision,
    pub scope: ApprovalScope,
    pub project_id: String,
    pub project_root: String,
    pub app: Option<String>,
    pub kind: ApprovalKind,
    pub subject: String,
    pub created_at: DateTime<Utc>,
    pub expires_at: Option<DateTime<Utc>>,
    pub once: bool,
    pub consumed_at: Option<DateTime<Utc>>,
    pub reason: Option<String>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct NewApproval {
    pub decision: ApprovalDecision,
    pub scope: ApprovalScope,
    pub kind: ApprovalKind,
    pub subject: String,
    pub ttl: Option<String>,
    pub once: bool,
    pub reason: Option<String>,
}

impl Approval {
    pub fn new(
        project: &crate::model::project::ProjectContext,
        input: NewApproval,
    ) -> Result<Self> {
        Self::new_with_app(project, input, None)
    }

    pub fn new_for_app(
        project: &crate::model::project::ProjectContext,
        input: NewApproval,
        app: Option<String>,
    ) -> Result<Self> {
        Self::new_with_app(project, input, app)
    }

    fn new_with_app(
        project: &crate::model::project::ProjectContext,
        input: NewApproval,
        app: Option<String>,
    ) -> Result<Self> {
        let created_at = Utc::now();
        let expires_at = input
            .ttl
            .as_deref()
            .map(parse_duration)
            .transpose()?
            .map(|duration| created_at + duration);
        Ok(Self {
            id: Uuid::new_v4(),
            decision: input.decision,
            scope: input.scope,
            project_id: project.id.clone(),
            project_root: project.root.display().to_string(),
            app,
            kind: input.kind,
            subject: input.subject,
            created_at,
            expires_at,
            once: input.once,
            consumed_at: None,
            reason: input.reason,
        })
    }

    pub fn active(&self, now: DateTime<Utc>) -> bool {
        self.consumed_at.is_none() && self.expires_at.map(|expires| expires > now).unwrap_or(true)
    }
}

pub fn command_app(command: &[String]) -> Option<String> {
    let command = command.first()?.trim();
    if command.is_empty() {
        return None;
    }
    Path::new(command)
        .file_name()
        .and_then(|name| name.to_str())
        .filter(|name| !name.is_empty())
        .map(ToOwned::to_owned)
        .or_else(|| Some(command.to_string()))
}

#[derive(Clone, Debug)]
pub struct ApprovalStore {
    path: PathBuf,
}

#[derive(Clone, Debug)]
pub struct ApprovalStores {
    project: ApprovalStore,
    global: ApprovalStore,
}

#[derive(Clone, Copy, Debug)]
enum ApprovalStoreKind {
    Project,
    Global,
}

#[derive(Clone)]
struct ApprovalCandidate {
    store: ApprovalStoreKind,
    id: Uuid,
    decision: ApprovalDecision,
    subject: String,
    created_at: DateTime<Utc>,
    once: bool,
}

impl ApprovalStore {
    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn load(&self) -> Result<Vec<Approval>> {
        self.load_unlocked()
    }

    fn load_unlocked(&self) -> Result<Vec<Approval>> {
        if !self.path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(&self.path)
            .with_context(|| format!("failed to read {}", self.path.display()))?;
        serde_json::from_str(&content)
            .with_context(|| format!("failed to parse {}", self.path.display()))
    }

    pub fn save(&self, approvals: &[Approval]) -> Result<()> {
        self.save_unlocked(approvals)
    }

    fn save_unlocked(&self, approvals: &[Approval]) -> Result<()> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("failed to create {}", parent.display()))?;
        }
        let content = serde_json::to_string_pretty(approvals)?;
        let temporary_path = self.temporary_path();
        fs::write(&temporary_path, content)
            .with_context(|| format!("failed to write {}", temporary_path.display()))?;
        fs::rename(&temporary_path, &self.path).with_context(|| {
            format!(
                "failed to replace {} with {}",
                self.path.display(),
                temporary_path.display()
            )
        })
    }

    pub fn add(&self, approval: Approval) -> Result<()> {
        self.update_approvals(|approvals| {
            approvals.push(approval);
            Ok(())
        })
    }

    pub fn remove(&self, id: Uuid) -> Result<bool> {
        self.update_approvals(|approvals| {
            let original_len = approvals.len();
            approvals.retain(|approval| approval.id != id);
            Ok(approvals.len() != original_len)
        })
    }

    pub fn gc(&self) -> Result<usize> {
        self.update_approvals(|approvals| {
            let original_len = approvals.len();
            let now = Utc::now();
            approvals.retain(|approval| approval.active(now));
            Ok(original_len - approvals.len())
        })
    }

    pub fn resolve(
        &self,
        project: &crate::model::project::ProjectContext,
        kind: ApprovalKind,
        subject: &str,
    ) -> Result<Option<ApprovalDecision>> {
        self.resolve_for_app(project, None, kind, subject)
    }

    pub fn resolve_for_app(
        &self,
        project: &crate::model::project::ProjectContext,
        app: Option<&str>,
        kind: ApprovalKind,
        subject: &str,
    ) -> Result<Option<ApprovalDecision>> {
        self.update_approvals(|approvals| {
            let now = Utc::now();
            let mut matched = None;
            for (index, approval) in approvals.iter().enumerate().rev() {
                if approval_matches(approval, project, app, kind, subject, now) {
                    matched = Some((index, approval.decision));
                    break;
                }
            }

            let Some((index, decision)) = matched else {
                return Ok(None);
            };
            if approvals[index].once {
                approvals[index].consumed_at = Some(now);
            }
            Ok(Some(decision))
        })
    }

    pub fn resolve_active_decisions(
        &self,
        project: &crate::model::project::ProjectContext,
        kind: ApprovalKind,
    ) -> Result<Vec<(String, ApprovalDecision)>> {
        self.resolve_active_decisions_for_app(project, None, kind)
    }

    pub fn resolve_active_decisions_for_app(
        &self,
        project: &crate::model::project::ProjectContext,
        app: Option<&str>,
        kind: ApprovalKind,
    ) -> Result<Vec<(String, ApprovalDecision)>> {
        self.update_approvals(|approvals| {
            let now = Utc::now();
            let mut decisions = BTreeMap::new();
            for (index, approval) in approvals.iter().enumerate() {
                if approval_matches_kind_scope(approval, project, app, kind, now) {
                    decisions.insert(approval.subject.clone(), (index, approval.decision));
                }
            }

            for (index, _decision) in decisions.values() {
                if approvals[*index].once {
                    approvals[*index].consumed_at = Some(now);
                }
            }

            Ok(decisions
                .into_iter()
                .map(|(subject, (_index, decision))| (subject, decision))
                .collect())
        })
    }

    fn candidates(
        &self,
        store: ApprovalStoreKind,
        project: &crate::model::project::ProjectContext,
        app: Option<&str>,
        kind: ApprovalKind,
        now: DateTime<Utc>,
    ) -> Result<Vec<ApprovalCandidate>> {
        Ok(self
            .load()?
            .into_iter()
            .enumerate()
            .filter(|(_, approval)| approval_matches_kind_scope(approval, project, app, kind, now))
            .map(|(_, approval)| ApprovalCandidate {
                store,
                id: approval.id,
                decision: approval.decision,
                subject: approval.subject,
                created_at: approval.created_at,
                once: approval.once,
            })
            .collect())
    }

    fn consume(&self, id: Uuid) -> Result<()> {
        self.update_approvals(|approvals| {
            if let Some(approval) = approvals.iter_mut().find(|approval| approval.id == id) {
                approval.consumed_at = Some(Utc::now());
            }
            Ok(())
        })
    }

    fn update_approvals<T>(
        &self,
        update: impl FnOnce(&mut Vec<Approval>) -> Result<T>,
    ) -> Result<T> {
        let lock = ApprovalFileLock::acquire(self.lock_path())?;
        let mut approvals = self.load_unlocked()?;
        let result = update(&mut approvals)?;
        self.save_unlocked(&approvals)?;
        drop(lock);
        Ok(result)
    }

    fn lock_path(&self) -> PathBuf {
        self.path.with_extension("lock")
    }

    fn temporary_path(&self) -> PathBuf {
        let file_name = self
            .path
            .file_name()
            .map(|name| name.to_string_lossy().to_string())
            .unwrap_or_else(|| "approvals.json".into());
        self.path
            .with_file_name(format!("{file_name}.tmp.{}", std::process::id()))
    }
}

struct ApprovalFileLock {
    file: File,
}

impl ApprovalFileLock {
    fn acquire(path: PathBuf) -> Result<Self> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("failed to create {}", parent.display()))?;
        }
        let file = OpenOptions::new()
            .create(true)
            .truncate(false)
            .read(true)
            .write(true)
            .open(&path)
            .with_context(|| format!("failed to open {}", path.display()))?;
        lock_file(&file).with_context(|| format!("failed to lock {}", path.display()))?;
        Ok(Self { file })
    }
}

impl Drop for ApprovalFileLock {
    fn drop(&mut self) {
        let _ = unlock_file(&self.file);
    }
}

#[cfg(unix)]
fn lock_file(file: &File) -> std::io::Result<()> {
    let result = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX) };
    if result == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error())
    }
}

#[cfg(unix)]
fn unlock_file(file: &File) -> std::io::Result<()> {
    let result = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_UN) };
    if result == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error())
    }
}

#[cfg(not(unix))]
fn lock_file(_file: &File) -> std::io::Result<()> {
    Ok(())
}

#[cfg(not(unix))]
fn unlock_file(_file: &File) -> std::io::Result<()> {
    Ok(())
}

impl ApprovalStores {
    pub fn from_state(state: &StatePaths) -> Self {
        Self {
            project: ApprovalStore::new(state.approvals_file.clone()),
            global: ApprovalStore::new(state.global_approvals_file.clone()),
        }
    }

    pub fn load(&self) -> Result<Vec<Approval>> {
        let mut approvals = self.global.load()?;
        approvals.extend(self.project.load()?);
        approvals.sort_by_key(|approval| approval.created_at);
        Ok(approvals)
    }

    pub fn add(&self, approval: Approval) -> Result<()> {
        crate::debug_log!(
            "approval store add scope={:?} kind={:?} decision={:?} once={} app={} subject={} project_id={} project_root={} project_file={} global_file={}",
            approval.scope,
            approval.kind,
            approval.decision,
            approval.once,
            approval.app.as_deref().unwrap_or("<none>"),
            approval.subject,
            approval.project_id,
            approval.project_root,
            self.project.path.display(),
            self.global.path.display(),
        );
        self.store_for_scope(approval.scope).add(approval)
    }

    pub fn remove(&self, id: Uuid) -> Result<bool> {
        let project_removed = self.project.remove(id)?;
        let global_removed = self.global.remove(id)?;
        Ok(project_removed || global_removed)
    }

    pub fn gc(&self) -> Result<usize> {
        Ok(self.project.gc()? + self.global.gc()?)
    }

    pub fn resolve(
        &self,
        project: &crate::model::project::ProjectContext,
        kind: ApprovalKind,
        subject: &str,
    ) -> Result<Option<ApprovalDecision>> {
        self.resolve_for_app(project, None, kind, subject)
    }

    pub fn resolve_for_app(
        &self,
        project: &crate::model::project::ProjectContext,
        app: Option<&str>,
        kind: ApprovalKind,
        subject: &str,
    ) -> Result<Option<ApprovalDecision>> {
        let now = Utc::now();
        crate::debug_log!(
            "approval resolve begin kind={kind:?} app={} subject={} project_id={} project_root={} project_file={} global_file={}",
            app.unwrap_or("<none>"),
            subject,
            project.id,
            project.root.display(),
            self.project.path.display(),
            self.global.path.display(),
        );
        let candidates = self.matching_candidates(project, app, kind, now)?;
        crate::debug_log!("approval resolve candidates={}", candidates.len());
        let candidate = candidates
            .into_iter()
            .filter(|candidate| approval_subject_matches(kind, &candidate.subject, subject))
            .max_by_key(|candidate| candidate.created_at);
        let Some(candidate) = candidate else {
            crate::debug_log!("approval resolve result=none");
            return Ok(None);
        };
        crate::debug_log!(
            "approval resolve result={:?} store={:?} once={} matched_subject={}",
            candidate.decision,
            candidate.store,
            candidate.once,
            candidate.subject,
        );
        if candidate.once {
            self.store_for_kind(candidate.store).consume(candidate.id)?;
        }
        Ok(Some(candidate.decision))
    }

    pub fn resolve_active_decisions(
        &self,
        project: &crate::model::project::ProjectContext,
        kind: ApprovalKind,
    ) -> Result<Vec<(String, ApprovalDecision)>> {
        self.resolve_active_decisions_for_app(project, None, kind)
    }

    pub fn resolve_active_decisions_for_app(
        &self,
        project: &crate::model::project::ProjectContext,
        app: Option<&str>,
        kind: ApprovalKind,
    ) -> Result<Vec<(String, ApprovalDecision)>> {
        let mut decisions = BTreeMap::new();
        for candidate in self.matching_candidates(project, app, kind, Utc::now())? {
            decisions
                .entry(candidate.subject.clone())
                .and_modify(|existing: &mut ApprovalCandidate| {
                    if candidate.created_at > existing.created_at {
                        *existing = candidate.clone();
                    }
                })
                .or_insert(candidate);
        }
        for candidate in decisions.values().filter(|candidate| candidate.once) {
            self.store_for_kind(candidate.store).consume(candidate.id)?;
        }
        Ok(decisions
            .into_iter()
            .map(|(subject, candidate)| (subject, candidate.decision))
            .collect())
    }

    fn matching_candidates(
        &self,
        project: &crate::model::project::ProjectContext,
        app: Option<&str>,
        kind: ApprovalKind,
        now: DateTime<Utc>,
    ) -> Result<Vec<ApprovalCandidate>> {
        let mut candidates =
            self.project
                .candidates(ApprovalStoreKind::Project, project, app, kind, now)?;
        candidates.extend(self.global.candidates(
            ApprovalStoreKind::Global,
            project,
            app,
            kind,
            now,
        )?);
        Ok(candidates)
    }

    fn store_for_scope(&self, scope: ApprovalScope) -> &ApprovalStore {
        match scope {
            ApprovalScope::Global => &self.global,
            ApprovalScope::AppProject | ApprovalScope::Project => &self.project,
        }
    }

    fn store_for_kind(&self, kind: ApprovalStoreKind) -> &ApprovalStore {
        match kind {
            ApprovalStoreKind::Project => &self.project,
            ApprovalStoreKind::Global => &self.global,
        }
    }
}

fn approval_matches(
    approval: &Approval,
    project: &crate::model::project::ProjectContext,
    app: Option<&str>,
    kind: ApprovalKind,
    subject: &str,
    now: DateTime<Utc>,
) -> bool {
    approval_subject_matches(approval.kind, &approval.subject, subject)
        && approval_matches_kind_scope(approval, project, app, kind, now)
}

fn approval_subject_matches(kind: ApprovalKind, pattern: &str, subject: &str) -> bool {
    match kind {
        ApprovalKind::FsRead | ApprovalKind::FsWrite | ApprovalKind::FsExec => {
            policy_pattern_matches(pattern, subject)
        }
        ApprovalKind::NetDomain | ApprovalKind::NetPort | ApprovalKind::Command => {
            pattern == subject
        }
    }
}

fn approval_matches_kind_scope(
    approval: &Approval,
    project: &crate::model::project::ProjectContext,
    app: Option<&str>,
    kind: ApprovalKind,
    now: DateTime<Utc>,
) -> bool {
    approval.active(now) && approval.kind == kind && approval_scope_matches(approval, project, app)
}

fn approval_scope_matches(
    approval: &Approval,
    project: &crate::model::project::ProjectContext,
    app: Option<&str>,
) -> bool {
    match approval.scope {
        ApprovalScope::AppProject => {
            approval.project_id == project.id && approval.app.as_deref() == app
        }
        ApprovalScope::Project => approval.project_id == project.id,
        ApprovalScope::Global => true,
    }
}

fn parse_duration(value: &str) -> Result<Duration> {
    let value = value.trim();
    if value.is_empty() {
        bail!("duration cannot be empty");
    }
    let unit_len = value.chars().next_back().map_or(1, char::len_utf8);
    let (number, unit) = value.split_at(value.len() - unit_len);
    let amount: i64 = number
        .parse()
        .with_context(|| format!("invalid duration `{value}`"))?;
    match unit {
        "s" => Ok(Duration::seconds(amount)),
        "m" => Ok(Duration::minutes(amount)),
        "h" => Ok(Duration::hours(amount)),
        "d" => Ok(Duration::days(amount)),
        _ => bail!("unsupported duration unit `{unit}` in `{value}`"),
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;

    #[test]
    fn parses_ttl_units() {
        assert_eq!(parse_duration("15m").unwrap(), Duration::minutes(15));
        assert_eq!(parse_duration("2h").unwrap(), Duration::hours(2));
    }

    #[test]
    fn parse_duration_rejects_multibyte_unit_without_panicking() {
        assert!(parse_duration("5×").is_err());
    }

    #[test]
    fn command_app_uses_command_basename() {
        assert_eq!(
            command_app(&["/home/example/.local/bin/agent".into(), "--help".into()]),
            Some("agent".into())
        );
        assert_eq!(command_app(&["curl".into()]), Some("curl".into()));
        assert_eq!(command_app(&[]), None);
    }

    #[test]
    fn resolves_latest_active_matching_approval_and_consumes_once() {
        let temp = tempfile::tempdir().unwrap();
        let store = ApprovalStore::new(temp.path().join("approvals.json"));
        let project = crate::model::project::ProjectContext {
            root: PathBuf::from("/tmp/project"),
            id: "project-id".into(),
            origin: None,
        };
        store
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Deny,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::NetDomain,
                        subject: "example.test".into(),
                        ttl: None,
                        once: false,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();
        store
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::NetDomain,
                        subject: "example.test".into(),
                        ttl: None,
                        once: true,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();

        assert_eq!(
            store
                .resolve(&project, ApprovalKind::NetDomain, "example.test")
                .unwrap(),
            Some(ApprovalDecision::Allow)
        );
        assert_eq!(
            store
                .resolve(&project, ApprovalKind::NetDomain, "example.test")
                .unwrap(),
            Some(ApprovalDecision::Deny)
        );
    }

    #[test]
    fn app_project_approval_matches_only_the_same_app() {
        let temp = tempfile::tempdir().unwrap();
        let store = ApprovalStore::new(temp.path().join("approvals.json"));
        let project = crate::model::project::ProjectContext {
            root: PathBuf::from("/tmp/project"),
            id: "project-id".into(),
            origin: None,
        };
        store
            .add(
                Approval::new_for_app(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::AppProject,
                        kind: ApprovalKind::FsRead,
                        subject: "/home/example/.agent".into(),
                        ttl: None,
                        once: false,
                        reason: None,
                    },
                    Some("agent".into()),
                )
                .unwrap(),
            )
            .unwrap();

        assert_eq!(
            store
                .resolve_for_app(
                    &project,
                    Some("agent"),
                    ApprovalKind::FsRead,
                    "/home/example/.agent/config.toml",
                )
                .unwrap(),
            Some(ApprovalDecision::Allow)
        );
        assert_eq!(
            store
                .resolve_for_app(
                    &project,
                    Some("curl"),
                    ApprovalKind::FsRead,
                    "/home/example/.agent/config.toml",
                )
                .unwrap(),
            None
        );
    }

    #[test]
    fn project_approval_matches_any_app_in_the_project() {
        let temp = tempfile::tempdir().unwrap();
        let store = ApprovalStore::new(temp.path().join("approvals.json"));
        let project = crate::model::project::ProjectContext {
            root: PathBuf::from("/tmp/project"),
            id: "project-id".into(),
            origin: None,
        };
        store
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::FsRead,
                        subject: "/opt/sdk".into(),
                        ttl: None,
                        once: false,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();

        assert_eq!(
            store
                .resolve_for_app(
                    &project,
                    Some("agent"),
                    ApprovalKind::FsRead,
                    "/opt/sdk/include/header.h",
                )
                .unwrap(),
            Some(ApprovalDecision::Allow)
        );
        assert_eq!(
            store
                .resolve_for_app(
                    &project,
                    Some("curl"),
                    ApprovalKind::FsRead,
                    "/opt/sdk/include/header.h",
                )
                .unwrap(),
            Some(ApprovalDecision::Allow)
        );
    }

    #[test]
    fn approval_stores_resolve_filesystem_descendant_subjects() {
        let temp = tempfile::tempdir().unwrap();
        let project = crate::model::project::ProjectContext {
            root: PathBuf::from("/tmp/project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = crate::model::state::StatePaths::from_base(&project, temp.path());
        let stores = ApprovalStores::from_state(&state);
        stores
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::FsRead,
                        subject: "/home/example/.agent".into(),
                        ttl: None,
                        once: false,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();

        assert_eq!(
            stores
                .resolve_for_app(
                    &project,
                    Some("agent"),
                    ApprovalKind::FsRead,
                    "/home/example/.agent/config.toml",
                )
                .unwrap(),
            Some(ApprovalDecision::Allow)
        );
    }

    #[test]
    fn resolves_active_decisions_by_subject_and_consumes_once() {
        let temp = tempfile::tempdir().unwrap();
        let store = ApprovalStore::new(temp.path().join("approvals.json"));
        let project = crate::model::project::ProjectContext {
            root: PathBuf::from("/tmp/project"),
            id: "project-id".into(),
            origin: None,
        };
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
                subject: "/tmp/cache".into(),
                ttl: None,
                once: false,
                reason: None,
            },
            NewApproval {
                decision: ApprovalDecision::Deny,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::FsRead,
                subject: "/tmp/cache".into(),
                ttl: None,
                once: false,
                reason: None,
            },
        ] {
            store
                .add(Approval::new(&project, approval).unwrap())
                .unwrap();
        }

        assert_eq!(
            store
                .resolve_active_decisions(&project, ApprovalKind::FsRead)
                .unwrap(),
            vec![
                ("/opt/sdk".into(), ApprovalDecision::Allow),
                ("/tmp/cache".into(), ApprovalDecision::Deny),
            ]
        );
        assert_eq!(
            store
                .resolve_active_decisions(&project, ApprovalKind::FsRead)
                .unwrap(),
            vec![("/tmp/cache".into(), ApprovalDecision::Deny)]
        );
    }

    #[test]
    fn filesystem_approvals_match_descendants_by_component() {
        let temp = tempfile::tempdir().unwrap();
        let store = ApprovalStore::new(temp.path().join("approvals.json"));
        let project = crate::model::project::ProjectContext {
            root: PathBuf::from("/tmp/project"),
            id: "project-id".into(),
            origin: None,
        };
        store
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::FsWrite,
                        subject: "/home/example/.agent/tmp/arg0".into(),
                        ttl: None,
                        once: false,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();
        store
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::NetDomain,
                        subject: "example.test".into(),
                        ttl: None,
                        once: false,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();

        assert_eq!(
            store
                .resolve(
                    &project,
                    ApprovalKind::FsWrite,
                    "/home/example/.agent/tmp/arg0/agent-arg0KofqE0/.lock",
                )
                .unwrap(),
            Some(ApprovalDecision::Allow)
        );
        assert_eq!(
            store
                .resolve(
                    &project,
                    ApprovalKind::FsWrite,
                    "/home/example/.agent/tmp/arg0suffix/.lock",
                )
                .unwrap(),
            None
        );
        assert_eq!(
            store
                .resolve(&project, ApprovalKind::NetDomain, "example.test.evil")
                .unwrap(),
            None
        );
    }

    #[test]
    fn resolves_project_and_global_scopes() {
        let temp = tempfile::tempdir().unwrap();
        let store = ApprovalStore::new(temp.path().join("approvals.json"));
        let project = crate::model::project::ProjectContext {
            root: PathBuf::from("/tmp/project"),
            id: "project-id".into(),
            origin: None,
        };
        let other_project = crate::model::project::ProjectContext {
            root: PathBuf::from("/tmp/other"),
            id: "other-project-id".into(),
            origin: None,
        };
        for approval in [
            NewApproval {
                decision: ApprovalDecision::Allow,
                scope: ApprovalScope::Project,
                kind: ApprovalKind::NetDomain,
                subject: "example.test".into(),
                ttl: None,
                once: false,
                reason: None,
            },
            NewApproval {
                decision: ApprovalDecision::Deny,
                scope: ApprovalScope::Global,
                kind: ApprovalKind::NetDomain,
                subject: "global.example".into(),
                ttl: None,
                once: false,
                reason: None,
            },
        ] {
            store
                .add(Approval::new(&project, approval).unwrap())
                .unwrap();
        }

        assert_eq!(
            store
                .resolve(&project, ApprovalKind::NetDomain, "example.test")
                .unwrap(),
            Some(ApprovalDecision::Allow)
        );
        assert_eq!(
            store
                .resolve(&other_project, ApprovalKind::NetDomain, "example.test")
                .unwrap(),
            None
        );
        assert_eq!(
            store
                .resolve(&other_project, ApprovalKind::NetDomain, "global.example")
                .unwrap(),
            Some(ApprovalDecision::Deny)
        );
    }

    #[test]
    fn global_approvals_are_shared_across_project_state_dirs() {
        let temp = tempfile::tempdir().unwrap();
        let state_base = temp.path().join("state");
        let project = crate::model::project::ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let other_project = crate::model::project::ProjectContext {
            root: temp.path().join("other"),
            id: "other-project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &state_base);
        let other_state = StatePaths::from_base(&other_project, &state_base);
        let stores = ApprovalStores::from_state(&state);
        stores
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Global,
                        kind: ApprovalKind::NetDomain,
                        subject: "registry.example".into(),
                        ttl: None,
                        once: false,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();

        assert!(state.global_approvals_file.exists());
        assert!(!state.approvals_file.exists());
        assert_eq!(
            state.global_approvals_file,
            other_state.global_approvals_file
        );
        assert_eq!(
            ApprovalStores::from_state(&other_state)
                .resolve(&other_project, ApprovalKind::NetDomain, "registry.example")
                .unwrap(),
            Some(ApprovalDecision::Allow)
        );
    }
}
