use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io::{self, Read};
use std::os::unix::fs::{FileTypeExt, MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{bail, Context, Result};
use chrono::{DateTime, Utc};
use crossterm::{
    event::{self, Event as TerminalEvent, KeyCode, KeyModifiers},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Wrap},
    Terminal,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use crate::model::config::{CondomConfig, ExecutionMode, ReviewFileRule, ReviewFileVisibility};
use crate::model::events::{
    redact_command, Decision, DecisionSource, Event, EventLog, EventType, EVENT_SCHEMA_VERSION,
};
use crate::model::policy::PolicySnapshot;
use crate::model::policy_pattern::policy_pattern_matches;
use crate::model::project::ProjectContext;
use crate::model::state::StatePaths;
use crate::sandbox::capture;

mod diff;
mod journal;
mod tui;

use diff::*;
use journal::*;
pub use journal::*;
use tui::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_baseline_mismatch() {
        let mut journal = ReviewJournal::new(vec!["npm".into(), "update".into()]);
        journal.operations.push(ReviewOperation {
            kind: ReviewOpKind::Modify,
            path: "package.json".into(),
            target: None,
            baseline_hash: Some("a".into()),
            captured_hash: Some("b".into()),
            baseline_kind: Some(ReviewEntryKind::File),
            captured_kind: Some(ReviewEntryKind::File),
            review_visibility: ReviewFileVisibility::Normal,
            default_selected: None,
        });
        let live = BTreeMap::from([("package.json".into(), "changed".into())]);
        assert_eq!(journal.detect_conflicts(&live).len(), 1);
    }

    #[test]
    fn diffs_create_modify_and_delete_operations() {
        let baseline = BTreeMap::from([
            (
                "keep.txt".into(),
                FileEntry {
                    kind: FileKind::File,
                    hash: "a".into(),
                    target: None,
                },
            ),
            (
                "remove.txt".into(),
                FileEntry {
                    kind: FileKind::File,
                    hash: "old".into(),
                    target: None,
                },
            ),
        ]);
        let captured = BTreeMap::from([
            (
                "keep.txt".into(),
                FileEntry {
                    kind: FileKind::File,
                    hash: "b".into(),
                    target: None,
                },
            ),
            (
                "add.txt".into(),
                FileEntry {
                    kind: FileKind::File,
                    hash: "new".into(),
                    target: None,
                },
            ),
        ]);

        let operations = diff_entries(&baseline, &captured);

        assert_eq!(
            operations
                .iter()
                .map(|operation| (&operation.kind, operation.path.as_str()))
                .collect::<Vec<_>>(),
            vec![
                (&ReviewOpKind::Create, "add.txt"),
                (&ReviewOpKind::Modify, "keep.txt"),
                (&ReviewOpKind::Delete, "remove.txt"),
            ]
        );
    }

    #[test]
    fn flags_sensitive_review_paths() {
        let flags = risk_flags(&[ReviewOperation {
            kind: ReviewOpKind::Modify,
            path: ".ci/workflows/main.yml".into(),
            target: None,
            baseline_hash: Some("a".into()),
            captured_hash: Some("b".into()),
            baseline_kind: Some(ReviewEntryKind::File),
            captured_kind: Some(ReviewEntryKind::File),
            review_visibility: ReviewFileVisibility::Normal,
            default_selected: None,
        }]);

        assert_eq!(flags, vec!["workflow/config changed"]);
    }

    #[test]
    fn review_diff_includes_git_hook_changes() {
        let temp = tempfile::tempdir().unwrap();
        let baseline_root = temp.path().join("baseline");
        let current_root = temp.path().join("current");
        let upper_dir = temp.path().join("upper");
        for root in [&baseline_root, &current_root, &upper_dir] {
            fs::create_dir_all(root.join(".git/hooks")).unwrap();
        }
        fs::write(baseline_root.join(".git/hooks/post-merge"), "old\n").unwrap();
        fs::write(current_root.join(".git/hooks/post-merge"), "new\n").unwrap();
        fs::write(upper_dir.join(".git/hooks/post-merge"), "new\n").unwrap();
        let baseline = collect_entries(&baseline_root, &[baseline_root.join(".condom")]).unwrap();

        let operations = diff_entries_from_upper_changes(
            &baseline,
            &upper_dir,
            &current_root,
            &[current_root.join(".condom")],
        )
        .unwrap();

        assert_eq!(operations.len(), 1);
        assert_eq!(operations[0].kind, ReviewOpKind::Modify);
        assert_eq!(operations[0].path, ".git/hooks/post-merge");
        assert_eq!(risk_flags(&operations), vec!["git hook changed"]);
    }

    #[test]
    fn counts_review_operations_by_kind() {
        let mut journal = ReviewJournal::new(vec![
            "npm".into(),
            "--token".into(),
            "secret-token".into(),
            "update".into(),
        ]);
        journal.exit_status = Some(0);
        journal.operations = vec![
            ReviewOperation {
                kind: ReviewOpKind::Create,
                path: "a\nfile.txt".into(),
                target: None,
                baseline_hash: None,
                captured_hash: Some("a".into()),
                baseline_kind: None,
                captured_kind: Some(ReviewEntryKind::File),
                review_visibility: ReviewFileVisibility::Normal,
                default_selected: None,
            },
            ReviewOperation {
                kind: ReviewOpKind::Modify,
                path: "b.txt".into(),
                target: None,
                baseline_hash: Some("a".into()),
                captured_hash: Some("b".into()),
                baseline_kind: Some(ReviewEntryKind::File),
                captured_kind: Some(ReviewEntryKind::File),
                review_visibility: ReviewFileVisibility::Normal,
                default_selected: None,
            },
            ReviewOperation {
                kind: ReviewOpKind::Create,
                path: "c.txt".into(),
                target: None,
                baseline_hash: None,
                captured_hash: Some("c".into()),
                baseline_kind: None,
                captured_kind: Some(ReviewEntryKind::File),
                review_visibility: ReviewFileVisibility::Normal,
                default_selected: None,
            },
        ];
        let counts = operation_counts(&journal.operations);

        assert_eq!(
            counts,
            vec![(ReviewOpKind::Create, 2), (ReviewOpKind::Modify, 1)]
        );
    }

    #[test]
    fn default_selection_selects_project_and_ephemeral_targets() {
        let operation = ReviewOperation {
            kind: ReviewOpKind::Modify,
            path: "lazy-lock.json".into(),
            target: None,
            baseline_hash: Some("old".into()),
            captured_hash: Some("new".into()),
            baseline_kind: Some(ReviewEntryKind::File),
            captured_kind: Some(ReviewEntryKind::File),
            review_visibility: ReviewFileVisibility::Normal,
            default_selected: None,
        };
        let targets = vec![
            ReviewTarget {
                id: "project".into(),
                label: "project /tmp/project".into(),
                kind: ReviewTargetKind::Project,
                baseline_root: PathBuf::from("/tmp/project"),
                current_root: PathBuf::from("/tmp/session/project"),
                apply_root: PathBuf::from("/tmp/project"),
                operations: vec![operation.clone()],
                selected_by_default: true,
            },
            ReviewTarget {
                id: "overlay-0".into(),
                label: "overlay 0 /tmp/lazy -> /tmp/runtime/lazy".into(),
                kind: ReviewTargetKind::Ephemeral { overlay_index: 0 },
                baseline_root: PathBuf::from("/tmp/lazy"),
                current_root: PathBuf::from("/tmp/session/overlay"),
                apply_root: PathBuf::from("/tmp/lazy"),
                operations: vec![operation],
                selected_by_default: true,
            },
        ];

        let state = ReviewTreeState::new(&targets, None);

        assert!(state.selected.contains(&ReviewFileKey {
            target_id: "project".into(),
            path: "lazy-lock.json".into(),
        }));
        assert!(state.selected.contains(&ReviewFileKey {
            target_id: "overlay-0".into(),
            path: "lazy-lock.json".into(),
        }));
    }

    #[test]
    fn review_file_rules_classify_matching_operations() {
        let before = FileEntry {
            kind: FileKind::File,
            hash: "old".into(),
            target: None,
        };
        let after = FileEntry {
            kind: FileKind::File,
            hash: "new".into(),
            target: None,
        };
        let operations = review_operations_with_file_rules(
            vec![
                operation(
                    ReviewOpKind::Modify,
                    "plugin/.git/index".into(),
                    Some(&before),
                    Some(&after),
                ),
                operation(
                    ReviewOpKind::Modify,
                    "plugin/.git/hooks/pre-commit".into(),
                    Some(&before),
                    Some(&after),
                ),
            ],
            &[ReviewFileRule {
                pattern: "**/.git/index".into(),
                visibility: ReviewFileVisibility::Hidden,
                default_selected: Some(true),
            }],
        );

        assert_eq!(
            operations[0].review_visibility,
            ReviewFileVisibility::Hidden
        );
        assert_eq!(operations[0].default_selected, Some(true));
        assert_eq!(
            operations[1].review_visibility,
            ReviewFileVisibility::Normal
        );
        assert_eq!(operations[1].default_selected, None);
    }

    #[test]
    fn hidden_review_operations_stay_selected_without_tree_rows() {
        let mut targets = review_tui_targets(&["hidden.txt", "visible.txt"]);
        targets[0].operations[0].review_visibility = ReviewFileVisibility::Hidden;
        targets[0].operations[0].default_selected = Some(true);

        let state = ReviewTreeState::new(&targets, None);

        assert!(state.selected.contains(&ReviewFileKey {
            target_id: "project".into(),
            path: "hidden.txt".into(),
        }));
        assert!(!state.rows.iter().any(|row| {
            matches!(
                row,
                ReviewTreeRow::Operation {
                    operation_index: 0,
                    ..
                }
            )
        }));
        assert!(state.rows.iter().any(|row| {
            matches!(
                row,
                ReviewTreeRow::Operation {
                    operation_index: 1,
                    ..
                }
            )
        }));
    }

    fn review_tui_targets(paths: &[&str]) -> Vec<ReviewTarget> {
        vec![ReviewTarget {
            id: "project".into(),
            label: "project /tmp/project".into(),
            kind: ReviewTargetKind::Project,
            baseline_root: PathBuf::from("/tmp/project-baseline"),
            current_root: PathBuf::from("/tmp/project-current"),
            apply_root: PathBuf::from("/tmp/project"),
            operations: paths
                .iter()
                .map(|path| ReviewOperation {
                    kind: ReviewOpKind::Modify,
                    path: (*path).into(),
                    target: None,
                    baseline_hash: Some("old".into()),
                    captured_hash: Some("new".into()),
                    baseline_kind: Some(ReviewEntryKind::File),
                    captured_kind: Some(ReviewEntryKind::File),
                    review_visibility: ReviewFileVisibility::Normal,
                    default_selected: None,
                })
                .collect(),
            selected_by_default: false,
        }]
    }

    #[test]
    fn review_tui_scroll_offset_keeps_context_below_cursor() {
        assert_eq!(review_tree_scroll_offset(0, 100, 10, 3), 0);
        assert_eq!(review_tree_scroll_offset(5, 100, 10, 3), 2);
        assert_eq!(review_tree_scroll_offset(95, 100, 10, 3), 90);
        assert_eq!(review_tree_scroll_offset(4, 8, 10, 3), 0);
    }

    #[test]
    fn review_tui_shift_tab_on_file_collapses_parent_directory() {
        let targets = review_tui_targets(&["dir/a.txt", "dir/b.txt", "root.txt"]);
        let mut state = ReviewTreeState::new(&targets, None);
        state.cursor = state
            .rows
            .iter()
            .position(|row| {
                matches!(
                    row,
                    ReviewTreeRow::Directory { path, .. } if path == "dir"
                )
            })
            .unwrap();
        state.toggle_expanded(&targets);
        state.cursor = state
            .rows
            .iter()
            .position(|row| {
                matches!(
                    row,
                    ReviewTreeRow::Operation {
                        operation_index: 0,
                        ..
                    }
                )
            })
            .unwrap();

        state.collapse_current_or_parent(&targets);

        assert!(!state.expanded.contains(&dir_expand_key(&targets[0], "dir")));
        assert!(matches!(
            state.current_row(),
            Some(ReviewTreeRow::Directory { path, .. }) if path == "dir"
        ));
    }

    #[test]
    fn review_tui_keep_diff_file_selects_and_advances() {
        let targets = review_tui_targets(&["a.txt", "b.txt"]);
        let mut state = ReviewTreeState::new(&targets, None);
        state.cursor = state
            .rows
            .iter()
            .position(|row| {
                matches!(
                    row,
                    ReviewTreeRow::Operation {
                        operation_index: 0,
                        ..
                    }
                )
            })
            .unwrap();
        state.enter_current(&targets);

        state.keep_diff_file_and_advance(&targets, 0, 0);

        assert!(state.selected.contains(&ReviewFileKey {
            target_id: "project".into(),
            path: "a.txt".into(),
        }));
        assert_eq!(
            state.screen,
            ReviewTreeScreen::Diff {
                target_index: 0,
                operation_index: 1,
                scroll: 0
            }
        );
    }

    #[test]
    fn review_tui_keep_diff_file_advances_into_collapsed_directory() {
        let targets = review_tui_targets(&["a.txt", "dir/b.txt"]);
        let mut state = ReviewTreeState::new(&targets, None);
        state.cursor = state
            .rows
            .iter()
            .position(|row| {
                matches!(
                    row,
                    ReviewTreeRow::Operation {
                        operation_index: 0,
                        ..
                    }
                )
            })
            .unwrap();
        state.enter_current(&targets);

        state.keep_diff_file_and_advance(&targets, 0, 0);

        assert!(state.expanded.contains(&dir_expand_key(&targets[0], "dir")));
        assert!(matches!(
            state.current_row(),
            Some(ReviewTreeRow::Operation {
                operation_index: 1,
                ..
            })
        ));
        assert_eq!(
            state.screen,
            ReviewTreeScreen::Diff {
                target_index: 0,
                operation_index: 1,
                scroll: 0
            }
        );
    }

    #[test]
    fn review_tui_diff_help_mentions_q_back() {
        let targets = review_tui_targets(&["a.txt"]);
        let mut state = ReviewTreeState::new(&targets, None);
        state.cursor = state
            .rows
            .iter()
            .position(|row| matches!(row, ReviewTreeRow::Operation { .. }))
            .unwrap();
        state.enter_current(&targets);

        assert!(review_tree_help(ReviewUiMode::Review, &state).contains("q/enter/esc back"));
    }

    #[test]
    fn review_tui_browse_preview_scroll_resets_when_cursor_moves() {
        let targets = review_tui_targets(&["a.txt", "b.txt"]);
        let mut state = ReviewTreeState::new(&targets, None);

        state.scroll_preview_down(10);
        state.move_next();

        assert_eq!(state.preview_scroll, 0);
    }

    #[test]
    fn review_tui_browse_help_mentions_preview_scroll_and_uppercase_discard() {
        let targets = review_tui_targets(&["a.txt"]);
        let state = ReviewTreeState::new(&targets, None);

        assert!(review_tree_help(ReviewUiMode::Review, &state).contains("d/u preview"));
        assert!(review_tree_help(ReviewUiMode::Final, &state).contains("d/u preview"));
        assert!(review_tree_help(ReviewUiMode::Final, &state).contains("D discard"));
    }

    #[test]
    fn review_tui_uses_local_icon_vocabulary() {
        assert_eq!(selection_glyph(true).0, ICON_TASK_DONE);
        assert_eq!(selection_glyph(false).0, ICON_TASK_DEFAULT);
        assert_eq!(selection_count_glyph(1, 2).0, ICON_TASK_ACTIVE);
        assert_eq!(review_tree_expand_glyph(true).0, ICON_FOLD_OPEN);
        assert_eq!(review_tree_expand_glyph(false).0, ICON_FOLD_CLOSED);
        assert_eq!(review_tree_folder_glyph(true).0, ICON_FOLDER_OPEN);
        assert_eq!(review_tree_folder_glyph(false).0, ICON_FOLDER_CLOSED);
        assert_eq!(
            review_target_glyph(&ReviewTargetKind::Project).0,
            ICON_PROJECT
        );
    }

    #[test]
    fn review_tui_reuses_cached_diff_lines() {
        let temp = tempfile::tempdir().unwrap();
        let current_root = temp.path().join("current");
        let apply_root = temp.path().join("apply");
        fs::create_dir_all(&current_root).unwrap();
        fs::create_dir_all(&apply_root).unwrap();
        fs::write(current_root.join("a.txt"), "new\n").unwrap();
        fs::write(apply_root.join("a.txt"), "old\n").unwrap();
        let targets = vec![ReviewTarget {
            id: "project".into(),
            label: "project /tmp/project".into(),
            kind: ReviewTargetKind::Project,
            baseline_root: apply_root.clone(),
            current_root: current_root.clone(),
            apply_root: apply_root.clone(),
            operations: vec![ReviewOperation {
                kind: ReviewOpKind::Modify,
                path: "a.txt".into(),
                target: None,
                baseline_hash: Some(hash_bytes(b"old\n")),
                captured_hash: Some(hash_bytes(b"new\n")),
                baseline_kind: Some(ReviewEntryKind::File),
                captured_kind: Some(ReviewEntryKind::File),
                review_visibility: ReviewFileVisibility::Normal,
                default_selected: None,
            }],
            selected_by_default: false,
        }];
        let mut state = ReviewTreeState::new(&targets, None);

        let first = lines_plaintext(&state.diff_lines(&targets, 0, 0));
        fs::remove_file(current_root.join("a.txt")).unwrap();
        let second = lines_plaintext(&state.diff_lines(&targets, 0, 0));

        assert_eq!(state.diff_cache.len(), 1);
        assert_eq!(first, second);
        assert!(second.contains("+new"));
    }

    fn lines_plaintext(lines: &[Line<'static>]) -> String {
        lines
            .iter()
            .map(|line| {
                line.spans
                    .iter()
                    .map(|span| span.content.as_ref())
                    .collect::<String>()
            })
            .collect::<Vec<_>>()
            .join("\n")
    }

    #[test]
    fn review_tui_short_labels_drop_redundant_target_prefixes() {
        let project = ReviewTarget {
            id: "project".into(),
            label: "project /tmp/project".into(),
            kind: ReviewTargetKind::Project,
            baseline_root: PathBuf::from("/tmp/project-baseline"),
            current_root: PathBuf::from("/tmp/project-current"),
            apply_root: PathBuf::from("/tmp/project"),
            operations: Vec::new(),
            selected_by_default: false,
        };
        let overlay = ReviewTarget {
            id: "overlay-1".into(),
            label: "overlay 1 /source -> /tmp/runtime".into(),
            kind: ReviewTargetKind::Ephemeral { overlay_index: 1 },
            baseline_root: PathBuf::from("/source"),
            current_root: PathBuf::from("/tmp/runtime"),
            apply_root: PathBuf::from("/source"),
            operations: Vec::new(),
            selected_by_default: false,
        };

        assert_eq!(review_target_short_label(&project), "/tmp/project");
        assert_eq!(
            review_target_short_label(&overlay),
            "/source -> /tmp/runtime"
        );
    }

    #[test]
    fn review_shell_script_starts_review_without_abort_special_case() {
        let script = review_shell_script();

        assert!(script.contains("final_status=\"$?\""));
        assert!(script.contains("condom review\n\nwhile :; do"));
        assert!(!script.contains("--auto"));
        assert!(!script.contains("review_status"));
        assert!(!script.contains("exit \"$final_status\""));
    }

    #[test]
    fn review_diff_half_page_keys_use_visible_diff_height() {
        assert_eq!(review_diff_half_page_scroll_amount(24), 8);
        assert_eq!(review_diff_half_page_scroll_amount(25), 9);
        assert_eq!(review_diff_half_page_scroll_amount(8), 1);
        assert_eq!(review_diff_half_page_scroll_amount(0), 1);
        assert_eq!(review_preview_half_page_scroll_amount(24), 8);
    }

    #[test]
    fn failed_apply_records_review_event() {
        let temp = tempfile::tempdir().unwrap();
        let project_root = temp.path().join("project");
        fs::create_dir_all(&project_root).unwrap();
        fs::write(project_root.join("package.json"), "{}\n").unwrap();
        let project = ProjectContext {
            root: project_root.clone(),
            id: "project-id".into(),
            origin: None,
        };
        let session = ReviewSession {
            id: Uuid::new_v4(),
            session_dir: temp.path().join("session"),
            workspace_dir: temp.path().join("session/merged"),
            upper_dir: temp.path().join("session/upper"),
            work_dir: temp.path().join("session/work"),
        };
        let event_log = EventLog::new(temp.path().join("events.jsonl"));
        let mut journal = ReviewJournal::new(vec!["npm".into(), "update".into()]);
        journal.id = session.id;
        journal.operations.push(ReviewOperation {
            kind: ReviewOpKind::Modify,
            path: "package.json".into(),
            target: None,
            baseline_hash: Some("stale-baseline".into()),
            captured_hash: Some("captured".into()),
            baseline_kind: Some(ReviewEntryKind::File),
            captured_kind: Some(ReviewEntryKind::File),
            review_visibility: ReviewFileVisibility::Normal,
            default_selected: None,
        });
        let targets = vec![ReviewTarget {
            id: "project".into(),
            label: format!("project {}", project_root.display()),
            kind: ReviewTargetKind::Project,
            baseline_root: project_root.clone(),
            current_root: session.workspace_dir.clone(),
            apply_root: project_root.clone(),
            operations: journal.operations.clone(),
            selected_by_default: true,
        }];
        let selection = ReviewSelection {
            selected: BTreeSet::from([(0, 0)]),
        };

        let command = vec!["npm".into(), "update".into()];
        let error = apply_review_selection_with_event(
            ReviewEventContext {
                project: &project,
                mode: ExecutionMode::Review,
                command: &command,
                event_log: &event_log,
            },
            &session,
            &targets,
            &selection,
            &mut journal,
        )
        .unwrap_err();

        assert!(error.to_string().contains("review apply conflict"));
        assert_eq!(
            fs::read_to_string(project_root.join("package.json")).unwrap(),
            "{}\n"
        );
        let events = event_log.list().unwrap();
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].event_type, EventType::ReviewApply);
        assert_eq!(events[0].decision, Decision::Failed);
        assert_eq!(events[0].subject, session.id.to_string());
        assert!(events[0].reason.contains("review apply failed"));
        assert!(events[0].reason.contains("review apply conflict"));
    }

    #[test]
    fn failed_apply_restores_current_operation_after_mutation_error() {
        let temp = tempfile::tempdir().unwrap();
        let project_root = temp.path().join("project");
        let captured_root = temp.path().join("captured");
        fs::create_dir_all(&project_root).unwrap();
        fs::create_dir_all(&captured_root).unwrap();
        fs::write(project_root.join("package.json"), "{}\n").unwrap();
        let session = ReviewSession {
            id: Uuid::new_v4(),
            session_dir: temp.path().join("session"),
            workspace_dir: captured_root.clone(),
            upper_dir: temp.path().join("upper"),
            work_dir: temp.path().join("work"),
        };
        let mut journal = ReviewJournal::new(vec!["npm".into(), "update".into()]);
        journal.operations.push(ReviewOperation {
            kind: ReviewOpKind::Modify,
            path: "package.json".into(),
            target: None,
            baseline_hash: Some(hash_bytes(b"{}\n")),
            captured_hash: Some(hash_bytes(b"{\"changed\":true}\n")),
            baseline_kind: Some(ReviewEntryKind::File),
            captured_kind: Some(ReviewEntryKind::File),
            review_visibility: ReviewFileVisibility::Normal,
            default_selected: None,
        });
        let targets = vec![ReviewTarget {
            id: "project".into(),
            label: format!("project {}", project_root.display()),
            kind: ReviewTargetKind::Project,
            baseline_root: project_root.clone(),
            current_root: captured_root,
            apply_root: project_root.clone(),
            operations: journal.operations.clone(),
            selected_by_default: true,
        }];
        let selection = ReviewSelection {
            selected: BTreeSet::from([(0, 0)]),
        };

        let error =
            apply_review_selection(&session, &targets, &selection, &mut journal).unwrap_err();

        assert!(error.to_string().contains("failed to inspect"));
        assert_eq!(
            fs::read_to_string(project_root.join("package.json")).unwrap(),
            "{}\n"
        );
        assert!(!journal.accepted);
    }

    #[test]
    fn selected_ephemeral_target_applies_to_overlay_source() {
        let temp = tempfile::tempdir().unwrap();
        let source = temp.path().join("source");
        let current = temp.path().join("current");
        fs::create_dir_all(&source).unwrap();
        fs::create_dir_all(&current).unwrap();
        fs::write(source.join("plugin.txt"), "baseline").unwrap();
        fs::write(current.join("plugin.txt"), "changed").unwrap();
        let operation = ReviewOperation {
            kind: ReviewOpKind::Modify,
            path: "plugin.txt".into(),
            target: None,
            baseline_hash: Some(hash_file(&source.join("plugin.txt")).unwrap()),
            captured_hash: Some(hash_file(&current.join("plugin.txt")).unwrap()),
            baseline_kind: Some(ReviewEntryKind::File),
            captured_kind: Some(ReviewEntryKind::File),
            review_visibility: ReviewFileVisibility::Normal,
            default_selected: None,
        };
        let session = ReviewSession {
            id: Uuid::new_v4(),
            session_dir: temp.path().join("session"),
            workspace_dir: temp.path().join("session/merged"),
            upper_dir: temp.path().join("session/upper"),
            work_dir: temp.path().join("session/work"),
        };
        let target = ReviewTarget {
            id: "overlay-0".into(),
            label: "overlay 0 source -> runtime".into(),
            kind: ReviewTargetKind::Ephemeral { overlay_index: 0 },
            baseline_root: source.clone(),
            current_root: current,
            apply_root: source.clone(),
            operations: vec![operation.clone()],
            selected_by_default: false,
        };
        let selection = ReviewSelection {
            selected: BTreeSet::from([(0, 0)]),
        };
        let mut journal = ReviewJournal::new(vec!["nvim".into()]);
        journal.operations = vec![operation];

        apply_review_selection(&session, &[target], &selection, &mut journal).unwrap();

        assert!(journal.accepted);
        assert_eq!(
            fs::read_to_string(source.join("plugin.txt")).unwrap(),
            "changed"
        );
    }

    #[test]
    fn apply_replaces_dangling_symlink_instead_of_writing_through_it() {
        let temp = tempfile::tempdir().unwrap();
        let source = temp.path().join("source");
        let current = temp.path().join("current");
        fs::create_dir_all(&source).unwrap();
        fs::create_dir_all(&current).unwrap();
        std::os::unix::fs::symlink("missing.txt", source.join("link.txt")).unwrap();
        fs::write(current.join("link.txt"), "captured").unwrap();
        let operation = ReviewOperation {
            kind: ReviewOpKind::Modify,
            path: "link.txt".into(),
            target: None,
            baseline_hash: Some(hash_bytes(b"missing.txt")),
            captured_hash: Some(hash_file(&current.join("link.txt")).unwrap()),
            baseline_kind: Some(ReviewEntryKind::Symlink),
            captured_kind: Some(ReviewEntryKind::File),
            review_visibility: ReviewFileVisibility::Normal,
            default_selected: None,
        };
        let session = ReviewSession {
            id: Uuid::new_v4(),
            session_dir: temp.path().join("session"),
            workspace_dir: temp.path().join("session/merged"),
            upper_dir: temp.path().join("session/upper"),
            work_dir: temp.path().join("session/work"),
        };
        let target = ReviewTarget {
            id: "project".into(),
            label: "project".into(),
            kind: ReviewTargetKind::Project,
            baseline_root: source.clone(),
            current_root: current,
            apply_root: source.clone(),
            operations: vec![operation.clone()],
            selected_by_default: true,
        };
        let selection = ReviewSelection {
            selected: BTreeSet::from([(0, 0)]),
        };
        let mut journal = ReviewJournal::new(vec!["tool".into()]);
        journal.operations = vec![operation];

        apply_review_selection(&session, &[target], &selection, &mut journal).unwrap();

        assert!(!fs::symlink_metadata(source.join("link.txt"))
            .unwrap()
            .file_type()
            .is_symlink());
        assert_eq!(
            fs::read_to_string(source.join("link.txt")).unwrap(),
            "captured"
        );
        assert!(!source.join("missing.txt").exists());
    }

    #[test]
    fn conflict_detection_rejects_live_file_kind_changes() {
        let operation = ReviewOperation {
            kind: ReviewOpKind::Modify,
            path: "config".into(),
            target: None,
            baseline_hash: Some("same".into()),
            captured_hash: Some("next".into()),
            baseline_kind: Some(ReviewEntryKind::File),
            captured_kind: Some(ReviewEntryKind::File),
            review_visibility: ReviewFileVisibility::Normal,
            default_selected: None,
        };
        let live = FileEntry {
            kind: FileKind::Symlink,
            hash: "same".into(),
            target: Some("same".into()),
        };

        assert!(operation_conflicts_with_entry(&operation, Some(&live)));
    }

    #[test]
    fn review_decision_rejects_unknown_schema_version() {
        let temp = tempfile::tempdir().unwrap();
        let session = ReviewSession {
            id: Uuid::new_v4(),
            session_dir: temp.path().join("session"),
            workspace_dir: temp.path().join("session/merged"),
            upper_dir: temp.path().join("session/upper"),
            work_dir: temp.path().join("session/work"),
        };
        let decision_path = runtime_review_decision_path(&session);
        fs::create_dir_all(decision_path.parent().unwrap()).unwrap();
        fs::write(
            &decision_path,
            r#"{"schemaVersion":2,"action":"apply","selected":[]}"#,
        )
        .unwrap();

        let error = read_review_decision(&session).unwrap_err();

        assert!(error
            .to_string()
            .contains("unsupported review decision schema"));
    }

    #[test]
    fn persisted_review_selection_ignores_unknown_schema_version() {
        let temp = tempfile::tempdir().unwrap();
        let selection_path = temp.path().join("selection.json");
        fs::write(
            &selection_path,
            r#"{"schemaVersion":2,"selected":[],"known":[]}"#,
        )
        .unwrap();

        assert_eq!(
            read_persisted_review_selection(&selection_path).unwrap(),
            None
        );
    }

    #[test]
    fn review_session_uses_temporary_workspace() {
        let session = create_session();

        assert!(session.session_dir.starts_with(review_session_base_dir()));
        assert!(session
            .session_dir
            .file_name()
            .unwrap()
            .to_string_lossy()
            .starts_with("condom-review-"));
    }
}
