use anyhow::Result;
use serde::{Deserialize, Serialize};

use std::collections::BTreeMap;
use std::path::Path;

use crate::auth::approvals::{
    command_app, Approval, ApprovalDecision, ApprovalKind, ApprovalScope, ApprovalStores,
    NewApproval,
};
use crate::auth::prompt::{
    self, FilesystemAccessMode, FilesystemPrompt, PromptDecision, PromptResult,
};
use crate::model::config::{CondomConfig, ExecutionMode, PromptMode};
use crate::model::events::{Decision, Event, EventLog};
use crate::model::policy::{self, PolicySnapshot};
use crate::model::policy_pattern::policy_pattern_matches;
use crate::model::project::ProjectContext;
use crate::model::state::StatePaths;

pub const NO_APPROVAL_UI_REASON: &str =
    "filesystem access denied because no approval UI is available";

#[derive(Clone, Copy)]
pub struct FilesystemAuthorizationContext<'a> {
    pub config: &'a CondomConfig,
    pub project: &'a ProjectContext,
    pub state: &'a StatePaths,
    pub mode: ExecutionMode,
    pub command: &'a [String],
    pub kind: ApprovalKind,
    pub subject: &'a str,
    pub policy_snapshot: Option<&'a PolicySnapshot>,
    pub prompt_environment: Option<&'a BTreeMap<String, String>>,
    pub event_log: &'a EventLog,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FilesystemAuthorization {
    pub decision: ApprovalDecision,
    pub reason: String,
    pub suggested_allow: Option<String>,
    #[serde(skip)]
    source: FilesystemAuthorizationSource,
    #[serde(
        default,
        rename = "cacheEntries",
        skip_serializing_if = "Vec::is_empty"
    )]
    pub cache_entries: Vec<FilesystemAuthorizationCacheEntry>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FilesystemAuthorizationCacheEntry {
    pub kind: ApprovalKind,
    pub subject: String,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
enum FilesystemAuthorizationSource {
    #[default]
    Other,
    StoredApproval,
    PolicySnapshot,
    InstancePrompt,
    StoredPrompt,
    TransportCacheable,
}

impl FilesystemAuthorization {
    pub(crate) fn from_transport_parts(
        decision: ApprovalDecision,
        reason: String,
        suggested_allow: Option<String>,
        cache_entries: Vec<FilesystemAuthorizationCacheEntry>,
        cacheable: bool,
    ) -> Self {
        Self {
            decision,
            reason,
            suggested_allow,
            source: if cacheable {
                FilesystemAuthorizationSource::TransportCacheable
            } else {
                FilesystemAuthorizationSource::Other
            },
            cache_entries,
        }
    }

    fn allow(reason: impl Into<String>) -> Self {
        Self::allow_from(reason, FilesystemAuthorizationSource::Other)
    }

    fn allow_from(reason: impl Into<String>, source: FilesystemAuthorizationSource) -> Self {
        Self {
            decision: ApprovalDecision::Allow,
            reason: reason.into(),
            suggested_allow: None,
            source,
            cache_entries: Vec::new(),
        }
    }

    fn deny(kind: ApprovalKind, subject: &str, reason: impl Into<String>) -> Self {
        Self::deny_from(kind, subject, reason, FilesystemAuthorizationSource::Other)
    }

    fn deny_from(
        kind: ApprovalKind,
        subject: &str,
        reason: impl Into<String>,
        source: FilesystemAuthorizationSource,
    ) -> Self {
        Self {
            decision: ApprovalDecision::Deny,
            reason: reason.into(),
            suggested_allow: suggested_allow(kind, subject),
            source,
            cache_entries: Vec::new(),
        }
    }

    pub fn is_cacheable(&self) -> bool {
        matches!(
            self.source,
            FilesystemAuthorizationSource::StoredApproval
                | FilesystemAuthorizationSource::PolicySnapshot
                | FilesystemAuthorizationSource::InstancePrompt
                | FilesystemAuthorizationSource::StoredPrompt
                | FilesystemAuthorizationSource::TransportCacheable
        )
    }
}

pub fn authorize_filesystem_access(
    context: FilesystemAuthorizationContext<'_>,
) -> Result<FilesystemAuthorization> {
    let Some(action) = context.kind.filesystem_action() else {
        return Ok(FilesystemAuthorization::deny(
            context.kind,
            context.subject,
            "only fs-read, fs-write, and fs-exec requests can use filesystem authorization",
        ));
    };

    if let Some(authorization) = snapshot_authorization(&context)? {
        return Ok(authorization);
    }

    if let Some(reason) = context
        .policy_snapshot
        .is_none()
        .then(|| hard_policy_denial(&context))
        .flatten()
    {
        append_prompt_event(&context, Decision::Denied, &reason)?;
        return Ok(FilesystemAuthorization::deny(
            context.kind,
            context.subject,
            reason,
        ));
    }

    if let Some(authorization) = stored_filesystem_authorization(&context)? {
        return Ok(authorization);
    }

    if prompt_mode(&context) == PromptMode::Deny {
        let reason = "filesystem access denied because prompt mode is deny";
        append_prompt_event(&context, Decision::Denied, reason)?;
        return Ok(FilesystemAuthorization::deny(
            context.kind,
            context.subject,
            reason,
        ));
    }

    let _prompt_queue =
        prompt::lock_approval_prompt_queue_with_environment(context.prompt_environment);
    crate::debug_log!(
        "filesystem approval queue acquired kind={:?} subject={} project_id={} project_root={}",
        context.kind,
        context.subject,
        context.project.id,
        context.project.root.display(),
    );
    if let Some(authorization) = stored_filesystem_authorization(&context)? {
        return Ok(authorization);
    }

    let prompt = FilesystemPrompt {
        action: action.into(),
        path: context.subject.into(),
        project_root: context.project.root.display().to_string(),
        command: context.command.to_vec(),
    };
    match prompt::prompt_filesystem_access_with_environment(&prompt, context.prompt_environment) {
        Ok(Some(decision)) => apply_prompt_decision(&context, decision),
        Ok(None) => {
            let reason = NO_APPROVAL_UI_REASON;
            append_prompt_event(&context, Decision::Denied, reason)?;
            Ok(FilesystemAuthorization::deny(
                context.kind,
                context.subject,
                reason,
            ))
        }
        Err(error) => {
            let reason = format!("failed to prompt for filesystem access: {error:#}");
            append_prompt_event(&context, Decision::Denied, &reason)?;
            Ok(FilesystemAuthorization::deny(
                context.kind,
                context.subject,
                reason,
            ))
        }
    }
}

fn prompt_mode(context: &FilesystemAuthorizationContext<'_>) -> PromptMode {
    context
        .policy_snapshot
        .map(|snapshot| snapshot.prompt.mode)
        .unwrap_or(context.config.defaults.prompt_mode)
}

fn stored_filesystem_authorization(
    context: &FilesystemAuthorizationContext<'_>,
) -> Result<Option<FilesystemAuthorization>> {
    let store = ApprovalStores::from_state(context.state);
    let app = command_app(context.command);
    crate::debug_log!(
        "filesystem approval stored lookup kind={:?} subject={} app={} project_id={} project_root={}",
        context.kind,
        context.subject,
        app.as_deref().unwrap_or("<none>"),
        context.project.id,
        context.project.root.display(),
    );
    match store.resolve_for_app(
        context.project,
        app.as_deref(),
        context.kind,
        context.subject,
    )? {
        Some(ApprovalDecision::Allow) => {
            crate::debug_log!(
                "filesystem approval stored result=allow kind={:?} subject={}",
                context.kind,
                context.subject,
            );
            context.event_log.append(&Event::approval_decision(
                context.project,
                context.mode,
                context.command,
                context.subject,
                Decision::Allowed,
                "allowed by stored filesystem approval",
            ))?;
            Ok(Some(FilesystemAuthorization::allow_from(
                "allowed by stored filesystem approval",
                FilesystemAuthorizationSource::StoredApproval,
            )))
        }
        Some(ApprovalDecision::Deny) => {
            crate::debug_log!(
                "filesystem approval stored result=deny kind={:?} subject={}",
                context.kind,
                context.subject,
            );
            context.event_log.append(&Event::approval_decision(
                context.project,
                context.mode,
                context.command,
                context.subject,
                Decision::Denied,
                "denied by stored filesystem approval",
            ))?;
            Ok(Some(FilesystemAuthorization::deny_from(
                context.kind,
                context.subject,
                "denied by stored filesystem approval",
                FilesystemAuthorizationSource::StoredApproval,
            )))
        }
        None => {
            crate::debug_log!(
                "filesystem approval stored result=none kind={:?} subject={}",
                context.kind,
                context.subject,
            );
            Ok(None)
        }
    }
}

fn snapshot_authorization(
    context: &FilesystemAuthorizationContext<'_>,
) -> Result<Option<FilesystemAuthorization>> {
    let Some(snapshot) = context.policy_snapshot else {
        return Ok(None);
    };
    let Some((allow, deny)) = snapshot_rules(snapshot, context.kind) else {
        return Ok(None);
    };
    if let Some(pattern) = deny
        .iter()
        .find(|pattern| policy_pattern_matches(pattern, context.subject))
    {
        let reason = format!(
            "filesystem {} denied by policy snapshot pattern `{pattern}`",
            context.kind.filesystem_action().unwrap_or("access")
        );
        context.event_log.append(&Event::approval_decision(
            context.project,
            context.mode,
            context.command,
            context.subject,
            Decision::Denied,
            &reason,
        ))?;
        return Ok(Some(FilesystemAuthorization::deny_from(
            context.kind,
            context.subject,
            reason,
            FilesystemAuthorizationSource::PolicySnapshot,
        )));
    }
    if let Some(pattern) = allow
        .iter()
        .find(|pattern| policy_pattern_matches(pattern, context.subject))
    {
        let reason = format!(
            "filesystem {} allowed by policy snapshot pattern `{pattern}`",
            context.kind.filesystem_action().unwrap_or("access")
        );
        context.event_log.append(&Event::approval_decision(
            context.project,
            context.mode,
            context.command,
            context.subject,
            Decision::Allowed,
            &reason,
        ))?;
        return Ok(Some(FilesystemAuthorization::allow_from(
            reason,
            FilesystemAuthorizationSource::PolicySnapshot,
        )));
    }
    Ok(None)
}

fn snapshot_rules(
    snapshot: &PolicySnapshot,
    kind: ApprovalKind,
) -> Option<(&Vec<String>, &Vec<String>)> {
    match kind {
        ApprovalKind::FsRead => Some((
            &snapshot.filesystem.allow_read,
            &snapshot.filesystem.deny_read,
        )),
        ApprovalKind::FsWrite => Some((
            &snapshot.filesystem.allow_write,
            &snapshot.filesystem.deny_write,
        )),
        ApprovalKind::FsExec => Some((
            &snapshot.filesystem.allow_execute,
            &snapshot.filesystem.deny_execute,
        )),
        _ => None,
    }
}

fn hard_policy_denial(context: &FilesystemAuthorizationContext<'_>) -> Option<String> {
    let patterns = match context.kind {
        ApprovalKind::FsRead => context.config.filesystem.deny_read.clone(),
        ApprovalKind::FsWrite => {
            let mut patterns = policy::internal_write_protection_paths(context.state);
            patterns.extend(context.config.filesystem.deny_write.clone());
            patterns
        }
        ApprovalKind::FsExec => Vec::new(),
        _ => Vec::new(),
    };
    patterns
        .iter()
        .find(|pattern| policy_pattern_matches(pattern, context.subject))
        .map(|pattern| {
            format!(
                "filesystem {} denied by hard policy pattern `{pattern}`",
                context.kind.filesystem_action().unwrap_or("access")
            )
        })
}

fn apply_prompt_decision(
    context: &FilesystemAuthorizationContext<'_>,
    result: impl Into<PromptResult>,
) -> Result<FilesystemAuthorization> {
    let result = result.into();
    match result.decision {
        PromptDecision::AllowOnce => {
            let reason = "allowed once by filesystem prompt";
            append_prompt_event(context, Decision::Accepted, reason)?;
            Ok(FilesystemAuthorization::allow(reason))
        }
        PromptDecision::DenyOnce => {
            let reason = "denied once by filesystem prompt";
            append_prompt_event(context, Decision::Rejected, reason)?;
            Ok(FilesystemAuthorization::deny(
                context.kind,
                context.subject,
                reason,
            ))
        }
        PromptDecision::AllowInstance => apply_instance_prompt_decision(
            context,
            &result,
            ApprovalDecision::Allow,
            Decision::Accepted,
            "allowed for instance by filesystem prompt",
        ),
        PromptDecision::DenyInstance => apply_instance_prompt_decision(
            context,
            &result,
            ApprovalDecision::Deny,
            Decision::Rejected,
            "denied for instance by filesystem prompt",
        ),
        PromptDecision::AllowAppProject => store_prompt_decision(
            context,
            &result,
            ApprovalDecision::Allow,
            ApprovalScope::AppProject,
            Decision::Accepted,
            "allowed for app/project by filesystem prompt",
            "filesystem prompt approval",
        ),
        PromptDecision::DenyAppProject => store_prompt_decision(
            context,
            &result,
            ApprovalDecision::Deny,
            ApprovalScope::AppProject,
            Decision::Rejected,
            "denied for app/project by filesystem prompt",
            "filesystem prompt denial",
        ),
        PromptDecision::AllowProject => store_prompt_decision(
            context,
            &result,
            ApprovalDecision::Allow,
            ApprovalScope::Project,
            Decision::Accepted,
            "allowed for project by filesystem prompt",
            "filesystem prompt approval",
        ),
        PromptDecision::DenyProject => store_prompt_decision(
            context,
            &result,
            ApprovalDecision::Deny,
            ApprovalScope::Project,
            Decision::Rejected,
            "denied for project by filesystem prompt",
            "filesystem prompt denial",
        ),
    }
}

fn apply_instance_prompt_decision(
    context: &FilesystemAuthorizationContext<'_>,
    result: &PromptResult,
    approval_decision: ApprovalDecision,
    event_decision: Decision,
    event_reason: &str,
) -> Result<FilesystemAuthorization> {
    let subject = selected_prompt_subject(context.subject, result.subject.as_deref());
    let cache_entries = selected_prompt_kinds(context.kind, result.filesystem_access)
        .into_iter()
        .map(|kind| FilesystemAuthorizationCacheEntry {
            kind,
            subject: subject.clone(),
        })
        .collect::<Vec<_>>();
    append_prompt_event(context, event_decision, event_reason)?;

    Ok(match approval_decision {
        ApprovalDecision::Allow => FilesystemAuthorization {
            decision: ApprovalDecision::Allow,
            reason: event_reason.into(),
            suggested_allow: None,
            source: FilesystemAuthorizationSource::InstancePrompt,
            cache_entries,
        },
        ApprovalDecision::Deny => FilesystemAuthorization {
            decision: ApprovalDecision::Deny,
            reason: event_reason.into(),
            suggested_allow: suggested_allow(context.kind, context.subject),
            source: FilesystemAuthorizationSource::InstancePrompt,
            cache_entries,
        },
    })
}

fn store_prompt_decision(
    context: &FilesystemAuthorizationContext<'_>,
    result: &PromptResult,
    approval_decision: ApprovalDecision,
    scope: ApprovalScope,
    event_decision: Decision,
    event_reason: &str,
    stored_reason: &str,
) -> Result<FilesystemAuthorization> {
    let store = ApprovalStores::from_state(context.state);
    let subject = selected_prompt_subject(context.subject, result.subject.as_deref());
    let app = (scope == ApprovalScope::AppProject)
        .then(|| command_app(context.command))
        .flatten();
    for kind in selected_prompt_kinds(context.kind, result.filesystem_access) {
        crate::debug_log!(
            "filesystem approval persistent store decision={approval_decision:?} scope={scope:?} kind={kind:?} subject={} app={} project_id={} project_root={}",
            subject,
            app.as_deref().unwrap_or("<none>"),
            context.project.id,
            context.project.root.display(),
        );
        store.add(Approval::new_for_app(
            context.project,
            NewApproval {
                decision: approval_decision,
                scope,
                kind,
                subject: subject.clone(),
                ttl: None,
                once: false,
                reason: Some(stored_reason.into()),
            },
            app.clone(),
        )?)?;
    }
    append_prompt_event(context, event_decision, event_reason)?;

    Ok(match approval_decision {
        ApprovalDecision::Allow => FilesystemAuthorization::allow_from(
            event_reason,
            FilesystemAuthorizationSource::StoredPrompt,
        ),
        ApprovalDecision::Deny => FilesystemAuthorization::deny_from(
            context.kind,
            context.subject,
            event_reason,
            FilesystemAuthorizationSource::StoredPrompt,
        ),
    })
}

fn selected_prompt_kinds(
    intercepted_kind: ApprovalKind,
    selected_access: Option<FilesystemAccessMode>,
) -> Vec<ApprovalKind> {
    match (intercepted_kind, selected_access) {
        (ApprovalKind::FsRead | ApprovalKind::FsWrite, Some(FilesystemAccessMode::Read)) => {
            vec![ApprovalKind::FsRead]
        }
        (ApprovalKind::FsRead | ApprovalKind::FsWrite, Some(FilesystemAccessMode::Write)) => {
            vec![ApprovalKind::FsWrite]
        }
        (ApprovalKind::FsRead | ApprovalKind::FsWrite, Some(FilesystemAccessMode::ReadWrite)) => {
            vec![ApprovalKind::FsRead, ApprovalKind::FsWrite]
        }
        _ => vec![intercepted_kind],
    }
}

fn selected_prompt_subject(subject: &str, selected_subject: Option<&str>) -> String {
    selected_subject
        .map(str::trim)
        .filter(|selected_subject| selected_subject_is_ancestor(subject, selected_subject))
        .map(persistent_prompt_subject)
        .unwrap_or_else(|| persistent_prompt_subject(subject))
}

fn selected_subject_is_ancestor(subject: &str, selected_subject: &str) -> bool {
    let selected_subject = selected_subject.trim();
    if selected_subject.is_empty() {
        return false;
    }
    let subject = Path::new(subject);
    let selected_subject = Path::new(selected_subject);
    subject == selected_subject || subject.starts_with(selected_subject)
}

fn persistent_prompt_subject(subject: &str) -> String {
    const AGENT_ARG0_MARKER: &str = "/.agent/tmp/arg0/";
    let Some(index) = subject.find(AGENT_ARG0_MARKER) else {
        return subject.into();
    };
    let remainder = &subject[index + AGENT_ARG0_MARKER.len()..];
    if remainder
        .split('/')
        .next()
        .is_some_and(|component| component.starts_with("agent-arg0"))
    {
        return subject[..index + AGENT_ARG0_MARKER.len() - 1].into();
    }
    subject.into()
}

fn append_prompt_event(
    context: &FilesystemAuthorizationContext<'_>,
    decision: Decision,
    reason: &str,
) -> Result<()> {
    context.event_log.append(&Event::prompt_decision_for_kind(
        context.project,
        context.mode,
        context.command,
        context.kind,
        context.subject,
        decision,
        reason,
    ))
}

fn suggested_allow(kind: ApprovalKind, subject: &str) -> Option<String> {
    if kind.filesystem_action().is_some() {
        Some(format!("condom allow add {} {subject}", kind.cli_name()))
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::auth::approvals::ApprovalStore;
    use std::collections::BTreeMap;
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use std::sync::Barrier;

    fn project() -> ProjectContext {
        ProjectContext {
            root: std::path::PathBuf::from("/tmp/project"),
            id: "project-id".into(),
            origin: None,
        }
    }

    #[test]
    fn exact_policy_path_matches_descendants_by_component() {
        assert!(policy_pattern_matches(
            "/tmp/project",
            "/tmp/project/src/main.rs"
        ));
        assert!(!policy_pattern_matches(
            "/tmp/project",
            "/tmp/projectile/src/main.rs"
        ));
    }

    #[test]
    fn filesystem_authorization_cacheability_uses_structured_source() {
        let text_only = FilesystemAuthorization::allow("allowed by stored filesystem approval");
        let stored = FilesystemAuthorization::allow_from(
            "custom stored reason",
            FilesystemAuthorizationSource::StoredApproval,
        );

        assert!(!text_only.is_cacheable());
        assert!(stored.is_cacheable());
    }

    #[test]
    fn stored_one_shot_filesystem_approval_is_consumed_once() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let store = ApprovalStore::new(state.approvals_file.clone());
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
                        once: true,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();

        let mut config = CondomConfig::default();
        config.defaults.prompt_mode = PromptMode::Deny;
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];
        let context = FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "/opt/sdk",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        };

        let first = authorize_filesystem_access(context).unwrap();
        let second = authorize_filesystem_access(context).unwrap();

        assert_eq!(first.decision, ApprovalDecision::Allow);
        assert_eq!(second.decision, ApprovalDecision::Deny);
        assert!(second.reason.contains("prompt mode is deny"));
        let events = event_log.list().unwrap();
        assert_eq!(events.len(), 2);
        assert_eq!(events[0].decision, Decision::Allowed);
        assert_eq!(events[1].decision, Decision::Denied);
    }

    #[test]
    fn configured_read_deny_wins_before_stored_allow() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let store = ApprovalStore::new(state.approvals_file.clone());
        store
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::FsRead,
                        subject: "~/.ssh/id_ed25519".into(),
                        ttl: None,
                        once: true,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();

        let mut config = CondomConfig::default();
        config.filesystem.deny_read = vec!["~/.ssh/**".into()];
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];
        let authorization = authorize_filesystem_access(FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "~/.ssh/id_ed25519",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        })
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Deny);
        assert!(authorization.reason.contains("hard policy pattern"));
        assert!(authorization.suggested_allow.is_some());
        assert!(store.load().unwrap()[0].consumed_at.is_none());
    }

    #[test]
    fn configured_write_deny_wins_before_prompting() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let mut config = CondomConfig::default();
        config.filesystem.deny_write = vec!["/tmp/cache/**".into()];
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];

        let authorization = authorize_filesystem_access(FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsWrite,
            subject: "/tmp/cache/package.tgz",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        })
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Deny);
        assert!(authorization.reason.contains("hard policy pattern"));
        assert_eq!(event_log.list().unwrap()[0].decision, Decision::Denied);
    }

    #[test]
    fn persistent_filesystem_prompt_decision_stores_scoped_approval() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["npm".into(), "install".into()];
        let context = FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsWrite,
            subject: "/tmp/cache",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        };

        let authorization =
            apply_prompt_decision(&context, PromptDecision::DenyAppProject).unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Deny);
        let approvals = ApprovalStore::new(state.approvals_file.clone())
            .load()
            .unwrap();
        assert_eq!(approvals.len(), 1);
        assert_eq!(approvals[0].scope, ApprovalScope::AppProject);
        assert_eq!(approvals[0].app.as_deref(), Some("npm"));
        assert_eq!(approvals[0].kind, ApprovalKind::FsWrite);
        assert_eq!(approvals[0].subject, "/tmp/cache");
        assert_eq!(approvals[0].decision, ApprovalDecision::Deny);
    }

    #[test]
    fn persistent_filesystem_prompt_decision_stores_selected_subject() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["agent".into()];
        let context = FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "/home/example/.agent/config.toml",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        };

        let authorization = apply_prompt_decision(
            &context,
            PromptResult::with_subject(PromptDecision::AllowAppProject, "/home/example/.agent"),
        )
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Allow);
        let approvals = ApprovalStore::new(state.approvals_file.clone())
            .load()
            .unwrap();
        assert_eq!(approvals.len(), 1);
        assert_eq!(approvals[0].scope, ApprovalScope::AppProject);
        assert_eq!(approvals[0].app.as_deref(), Some("agent"));
        assert_eq!(approvals[0].subject, "/home/example/.agent");
    }

    #[test]
    fn persistent_filesystem_prompt_decision_stores_selected_read_write_access() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["agent".into()];
        let context = FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "/home/example/.agent/config.toml",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        };

        let authorization = apply_prompt_decision(
            &context,
            PromptResult::with_subject_and_access(
                PromptDecision::AllowAppProject,
                "/home/example/.agent",
                Some(FilesystemAccessMode::ReadWrite),
            ),
        )
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Allow);
        let approvals = ApprovalStore::new(state.approvals_file.clone())
            .load()
            .unwrap();
        assert_eq!(approvals.len(), 2);
        assert_eq!(approvals[0].kind, ApprovalKind::FsRead);
        assert_eq!(approvals[1].kind, ApprovalKind::FsWrite);
        assert!(approvals
            .iter()
            .all(|approval| approval.subject == "/home/example/.agent"));
        assert!(approvals
            .iter()
            .all(|approval| approval.app.as_deref() == Some("agent")));
    }

    #[test]
    fn persistent_filesystem_prompt_decision_can_store_write_from_read_prompt() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];
        let context = FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "/tmp/cache/index.json",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        };

        apply_prompt_decision(
            &context,
            PromptResult::with_subject_and_access(
                PromptDecision::AllowProject,
                "/tmp/cache",
                Some(FilesystemAccessMode::Write),
            ),
        )
        .unwrap();

        let approvals = ApprovalStore::new(state.approvals_file.clone())
            .load()
            .unwrap();
        assert_eq!(approvals.len(), 1);
        assert_eq!(approvals[0].scope, ApprovalScope::Project);
        assert_eq!(approvals[0].kind, ApprovalKind::FsWrite);
        assert_eq!(approvals[0].subject, "/tmp/cache");
    }

    #[test]
    fn once_filesystem_prompt_decision_ignores_selected_access() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];
        let context = FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "/tmp/cache/index.json",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        };

        let authorization = apply_prompt_decision(
            &context,
            PromptResult::with_subject_and_access(
                PromptDecision::AllowOnce,
                "/tmp/cache",
                Some(FilesystemAccessMode::ReadWrite),
            ),
        )
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Allow);
        assert!(ApprovalStore::new(state.approvals_file.clone())
            .load()
            .unwrap()
            .is_empty());
    }

    #[test]
    fn instance_filesystem_prompt_decision_returns_selected_cache_entries_without_storing() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];
        let context = FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "/tmp/cache/index.json",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        };

        let authorization = apply_prompt_decision(
            &context,
            PromptResult::with_subject_and_access(
                PromptDecision::AllowInstance,
                "/tmp/cache",
                Some(FilesystemAccessMode::ReadWrite),
            ),
        )
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Allow);
        assert_eq!(
            authorization.cache_entries,
            vec![
                FilesystemAuthorizationCacheEntry {
                    kind: ApprovalKind::FsRead,
                    subject: "/tmp/cache".into(),
                },
                FilesystemAuthorizationCacheEntry {
                    kind: ApprovalKind::FsWrite,
                    subject: "/tmp/cache".into(),
                },
            ]
        );
        assert!(ApprovalStore::new(state.approvals_file.clone())
            .load()
            .unwrap()
            .is_empty());
    }

    #[test]
    fn deny_instance_filesystem_prompt_decision_returns_selected_cache_entries_without_storing() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];
        let context = FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsWrite,
            subject: "/tmp/cache/index.json",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        };

        let authorization = apply_prompt_decision(
            &context,
            PromptResult::with_subject_and_access(
                PromptDecision::DenyInstance,
                "/tmp/cache",
                Some(FilesystemAccessMode::Write),
            ),
        )
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Deny);
        assert_eq!(
            authorization.cache_entries,
            vec![FilesystemAuthorizationCacheEntry {
                kind: ApprovalKind::FsWrite,
                subject: "/tmp/cache".into(),
            }]
        );
        assert!(ApprovalStore::new(state.approvals_file.clone())
            .load()
            .unwrap()
            .is_empty());
    }

    #[test]
    fn persistent_filesystem_prompt_decision_ignores_non_ancestor_subject() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["agent".into()];
        let context = FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "/home/example/.agent/config.toml",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        };

        apply_prompt_decision(
            &context,
            PromptResult::with_subject(PromptDecision::AllowAppProject, "/home/example/.ssh"),
        )
        .unwrap();

        let approvals = ApprovalStore::new(state.approvals_file.clone())
            .load()
            .unwrap();
        assert_eq!(approvals.len(), 1);
        assert_eq!(approvals[0].subject, "/home/example/.agent/config.toml");
    }

    #[test]
    fn queued_filesystem_prompts_recheck_stored_approval_before_dialog() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["agent".into()];
        let count_path = temp.path().join("approval-count");
        let bin_dir = fake_sleeping_approval_gui_bin(&temp, "aa subject=/tmp/cache", &count_path);
        let mut environment = BTreeMap::new();
        environment.insert(prompt::APPROVAL_DISPLAY_ENV.into(), ":99".into());
        environment.insert(
            prompt::APPROVAL_PATH_ENV.into(),
            format!(
                "{}:{}",
                bin_dir.display(),
                std::env::var("PATH").unwrap_or_default()
            ),
        );
        let barrier = Barrier::new(2);

        std::thread::scope(|scope| {
            let first = scope.spawn(|| {
                barrier.wait();
                authorize_filesystem_access(FilesystemAuthorizationContext {
                    config: &config,
                    project: &project,
                    state: &state,
                    mode: ExecutionMode::Run,
                    command: &command,
                    kind: ApprovalKind::FsRead,
                    subject: "/tmp/cache/a.json",
                    policy_snapshot: None,
                    prompt_environment: Some(&environment),
                    event_log: &event_log,
                })
                .unwrap()
            });
            let second = scope.spawn(|| {
                barrier.wait();
                authorize_filesystem_access(FilesystemAuthorizationContext {
                    config: &config,
                    project: &project,
                    state: &state,
                    mode: ExecutionMode::Run,
                    command: &command,
                    kind: ApprovalKind::FsRead,
                    subject: "/tmp/cache/b.json",
                    policy_snapshot: None,
                    prompt_environment: Some(&environment),
                    event_log: &event_log,
                })
                .unwrap()
            });

            assert_eq!(first.join().unwrap().decision, ApprovalDecision::Allow);
            assert_eq!(second.join().unwrap().decision, ApprovalDecision::Allow);
        });

        assert_eq!(fs::read_to_string(count_path).unwrap(), "x");
        let approvals = ApprovalStore::new(state.approvals_file.clone())
            .load()
            .unwrap();
        assert_eq!(approvals.len(), 1);
        assert_eq!(approvals[0].subject, "/tmp/cache");
    }

    #[test]
    fn persistent_prompt_subject_groups_agent_arg0_siblings() {
        assert_eq!(
            persistent_prompt_subject("/home/example/.agent/tmp/arg0/agent-arg0KofqE0/config"),
            "/home/example/.agent/tmp/arg0"
        );
        assert_eq!(
            persistent_prompt_subject("/home/example/.agent/tmp/arg0/not-agent/config"),
            "/home/example/.agent/tmp/arg0/not-agent/config"
        );
    }

    #[test]
    fn persistent_filesystem_prompt_decision_stores_normalized_subject() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["agent".into()];
        let context = FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "/home/example/.agent/tmp/arg0/agent-arg0KofqE0",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        };

        let authorization =
            apply_prompt_decision(&context, PromptDecision::AllowAppProject).unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Allow);
        let approvals = ApprovalStore::new(state.approvals_file.clone())
            .load()
            .unwrap();
        assert_eq!(approvals.len(), 1);
        assert_eq!(approvals[0].scope, ApprovalScope::AppProject);
        assert_eq!(approvals[0].app.as_deref(), Some("agent"));
        assert_eq!(approvals[0].subject, "/home/example/.agent/tmp/arg0");
    }

    #[test]
    fn policy_snapshot_allow_resolves_before_prompt_mode_denial() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let mut snapshot_config = CondomConfig::default();
        snapshot_config.filesystem.allow_read = vec!["/opt/sdk/**".into()];
        let snapshot = policy::write_snapshot(
            &project,
            &state,
            &snapshot_config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let mut runtime_config = CondomConfig::default();
        runtime_config.defaults.prompt_mode = PromptMode::Deny;
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];

        let authorization = authorize_filesystem_access(FilesystemAuthorizationContext {
            config: &runtime_config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "/opt/sdk/include/header.h",
            policy_snapshot: Some(&snapshot),
            prompt_environment: None,
            event_log: &event_log,
        })
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Allow);
        assert!(authorization.reason.contains("policy snapshot pattern"));
        assert_eq!(event_log.list().unwrap()[0].decision, Decision::Allowed);
    }

    #[test]
    fn policy_snapshot_prompt_mode_wins_over_runtime_config() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let mut snapshot_config = CondomConfig::default();
        snapshot_config.defaults.prompt_mode = PromptMode::Deny;
        let snapshot = policy::write_snapshot(
            &project,
            &state,
            &snapshot_config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let runtime_config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];

        let authorization = authorize_filesystem_access(FilesystemAuthorizationContext {
            config: &runtime_config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsRead,
            subject: "/opt/sdk/include/header.h",
            policy_snapshot: Some(&snapshot),
            prompt_environment: None,
            event_log: &event_log,
        })
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Deny);
        assert_eq!(
            authorization.reason,
            "filesystem access denied because prompt mode is deny"
        );
    }

    #[test]
    fn policy_snapshot_deny_wins_before_stored_allow() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let mut snapshot_config = CondomConfig::default();
        snapshot_config.filesystem.deny_write = vec!["/opt/cache/**".into()];
        let snapshot = policy::write_snapshot(
            &project,
            &state,
            &snapshot_config,
            ExecutionMode::Run,
            &["tool".into()],
            &[],
        )
        .unwrap();
        let store = ApprovalStore::new(state.approvals_file.clone());
        store
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::FsWrite,
                        subject: "/opt/cache/pkg.tgz".into(),
                        ttl: None,
                        once: true,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];

        let authorization = authorize_filesystem_access(FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::FsWrite,
            subject: "/opt/cache/pkg.tgz",
            policy_snapshot: Some(&snapshot),
            prompt_environment: None,
            event_log: &event_log,
        })
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Deny);
        assert!(authorization.reason.contains("policy snapshot pattern"));
        assert!(store.load().unwrap()[0].consumed_at.is_none());
    }

    #[test]
    fn non_filesystem_kind_is_denied_without_prompting() {
        let temp = tempfile::tempdir().unwrap();
        let project = project();
        let state = StatePaths::from_base(&project, temp.path());
        let config = CondomConfig::default();
        let event_log = EventLog::new(state.events_file.clone());
        let command = vec!["tool".into()];
        let authorization = authorize_filesystem_access(FilesystemAuthorizationContext {
            config: &config,
            project: &project,
            state: &state,
            mode: ExecutionMode::Run,
            command: &command,
            kind: ApprovalKind::NetDomain,
            subject: "example.test",
            policy_snapshot: None,
            prompt_environment: None,
            event_log: &event_log,
        })
        .unwrap();

        assert_eq!(authorization.decision, ApprovalDecision::Deny);
        assert!(authorization.reason.contains("only fs-read"));
        assert_eq!(authorization.suggested_allow, None);
    }

    fn fake_sleeping_approval_gui_bin(
        temp: &tempfile::TempDir,
        decision: &str,
        count_path: &std::path::Path,
    ) -> std::path::PathBuf {
        let bin_dir = temp.path().join("bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let approval = bin_dir.join("condom-approval");
        fs::write(
            &approval,
            format!(
                "#!/bin/sh\nprintf x >> {}\nsleep 0.2\nprintf '%s\\n' {}\n",
                shell_quote(&count_path.display().to_string()),
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
}
