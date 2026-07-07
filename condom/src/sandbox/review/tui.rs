use super::*;

pub(super) const REVIEW_UI_SESSION_VERSION: u32 = 1;

pub(super) const REVIEW_UI_BACK_TO_SHELL_EXIT: i32 = 75;
// Review helpers run inside a NixOS-shaped sandbox that exposes /run/current-system/sw,
// while /bin/sh is not guaranteed to exist there.

pub(super) const REVIEW_HELPER_SHELL: &str = "/run/current-system/sw/bin/sh";

pub(super) const ICON_FOLD_CLOSED: &str = "";

pub(super) const ICON_FOLD_OPEN: &str = "";

pub(super) const ICON_FOLDER_CLOSED: &str = "";

pub(super) const ICON_FOLDER_OPEN: &str = "";

pub(super) const ICON_TASK_DEFAULT: &str = "";

pub(super) const ICON_TASK_ACTIVE: &str = "➡";

pub(super) const ICON_TASK_DONE: &str = "";

const ICON_TASK_CANCELLED: &str = "";

const ICON_FILE: &str = "";

pub(super) const ICON_PROJECT: &str = "";

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ReviewUiSession {
    pub(super) schema_version: u32,
    pub(super) id: Uuid,
    pub(super) mode: ExecutionMode,
    pub(super) command: Vec<String>,
    pub(super) exit_status: Option<i32>,
    #[serde(default)]
    pub(super) file_rules: Vec<ReviewFileRule>,
    pub(super) targets: Vec<ReviewUiTarget>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ReviewUiTarget {
    pub(super) id: String,
    pub(super) label: String,
    pub(super) kind: ReviewUiTargetKind,
    pub(super) baseline_root: PathBuf,
    pub(super) current_root: PathBuf,
    pub(super) apply_root: PathBuf,
    pub(super) upper_dir: PathBuf,
    pub(super) selected_by_default: bool,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub(super) enum ReviewUiTargetKind {
    Project,
    Ephemeral { overlay_index: usize },
}

#[derive(Clone, Debug, Eq, PartialEq, Ord, PartialOrd, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ReviewFileKey {
    pub(super) target_id: String,
    pub(super) path: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct PersistedReviewSelection {
    pub(super) schema_version: u32,
    pub(super) selected: Vec<ReviewFileKey>,
    pub(super) known: Vec<ReviewFileKey>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(super) enum ReviewUiMode {
    Review,
    Final,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(super) enum ReviewUiOutcome {
    Shell,
    Apply,
    Discard,
    BackToShell,
    Interrupted,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) enum ReviewTreeRow {
    Target {
        target_index: usize,
    },
    Directory {
        target_index: usize,
        path: String,
        depth: usize,
    },
    Operation {
        target_index: usize,
        operation_index: usize,
        depth: usize,
    },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) enum ReviewTreeScreen {
    Browse,
    Diff {
        target_index: usize,
        operation_index: usize,
        scroll: usize,
    },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) enum ReviewTreeFocus {
    Target {
        target_index: usize,
    },
    Directory {
        target_index: usize,
        path: String,
    },
    Operation {
        target_index: usize,
        operation_index: usize,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(super) enum ReviewOperationDirection {
    Previous,
    Next,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) struct ReviewTreeState {
    pub(super) rows: Vec<ReviewTreeRow>,
    pub(super) cursor: usize,
    pub(super) preview_scroll: usize,
    pub(super) expanded: BTreeSet<String>,
    pub(super) selected: BTreeSet<ReviewFileKey>,
    pub(super) known: BTreeSet<ReviewFileKey>,
    pub(super) screen: ReviewTreeScreen,
    pub(super) diff_cache: BTreeMap<ReviewDiffCacheKey, Vec<Line<'static>>>,
}

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub(super) struct ReviewDiffCacheKey {
    pub(super) target_index: usize,
    pub(super) operation_index: usize,
}

#[derive(Default)]
struct ReviewPathTree {
    pub(super) dirs: BTreeMap<String, ReviewPathTree>,
    pub(super) files: Vec<usize>,
}

pub(super) fn build_review_tree_rows(
    targets: &[ReviewTarget],
    expanded: &BTreeSet<String>,
) -> Vec<ReviewTreeRow> {
    let mut rows = Vec::new();
    for (target_index, target) in targets.iter().enumerate() {
        if !target.operations.iter().any(review_operation_is_visible) {
            continue;
        }
        rows.push(ReviewTreeRow::Target { target_index });
        if expanded.contains(&target_expand_key(target)) {
            let tree = build_path_tree(target);
            push_tree_rows(targets, target_index, "", &tree, 1, expanded, &mut rows);
        }
    }
    rows
}

fn build_path_tree(target: &ReviewTarget) -> ReviewPathTree {
    let mut root = ReviewPathTree::default();
    for (operation_index, operation) in target.operations.iter().enumerate() {
        if !review_operation_is_visible(operation) {
            continue;
        }
        let mut node = &mut root;
        let parts = operation.path.split('/').collect::<Vec<_>>();
        for part in parts.iter().take(parts.len().saturating_sub(1)) {
            node = node.dirs.entry((*part).to_string()).or_default();
        }
        node.files.push(operation_index);
    }
    root
}

fn review_operation_is_visible(operation: &ReviewOperation) -> bool {
    operation.review_visibility == ReviewFileVisibility::Normal
}

fn push_tree_rows(
    targets: &[ReviewTarget],
    target_index: usize,
    prefix: &str,
    tree: &ReviewPathTree,
    depth: usize,
    expanded: &BTreeSet<String>,
    rows: &mut Vec<ReviewTreeRow>,
) {
    let target = &targets[target_index];
    for (name, child) in &tree.dirs {
        let path = if prefix.is_empty() {
            name.clone()
        } else {
            format!("{prefix}/{name}")
        };
        rows.push(ReviewTreeRow::Directory {
            target_index,
            path: path.clone(),
            depth,
        });
        if expanded.contains(&dir_expand_key(target, &path)) {
            push_tree_rows(
                targets,
                target_index,
                &path,
                child,
                depth + 1,
                expanded,
                rows,
            );
        }
    }
    let mut files = tree.files.clone();
    files.sort_by(|left, right| {
        target.operations[*left]
            .path
            .cmp(&target.operations[*right].path)
    });
    rows.extend(
        files
            .into_iter()
            .map(|operation_index| ReviewTreeRow::Operation {
                target_index,
                operation_index,
                depth,
            }),
    );
}

pub(super) fn review_diff_half_page_scroll_amount(terminal_height: u16) -> usize {
    const NON_DIFF_CONTENT_ROWS: u16 = 8;
    let visible_diff_rows = terminal_height.saturating_sub(NON_DIFF_CONTENT_ROWS).max(1);
    usize::from(visible_diff_rows.div_ceil(2))
}

pub(super) fn review_preview_half_page_scroll_amount(terminal_height: u16) -> usize {
    review_diff_half_page_scroll_amount(terminal_height)
}

pub(super) fn review_tree_scroll_offset(
    cursor: usize,
    row_count: usize,
    visible_rows: usize,
    preferred_scrolloff: usize,
) -> usize {
    if visible_rows == 0 || row_count <= visible_rows {
        return 0;
    }
    let scrolloff = preferred_scrolloff.min(visible_rows.saturating_sub(1) / 2);
    cursor
        .saturating_sub(scrolloff)
        .min(row_count.saturating_sub(visible_rows))
}

pub(super) fn parent_directory_path(path: &str) -> Option<String> {
    path.rsplit_once('/')
        .map(|(parent, _)| parent.to_string())
        .filter(|parent| !parent.is_empty())
}

pub(super) fn directory_ancestors(path: &str) -> Vec<String> {
    let mut ancestors = Vec::new();
    let mut parent = parent_directory_path(path);
    while let Some(path) = parent {
        parent = parent_directory_path(&path);
        ancestors.push(path);
    }
    ancestors.reverse();
    ancestors
}

pub(super) fn run_review_tree_ui(
    targets: &[ReviewTarget],
    session: &ReviewUiSession,
    mode: ReviewUiMode,
    state: &mut ReviewTreeState,
) -> Result<ReviewUiOutcome> {
    enable_raw_mode().context("failed to enable raw mode for review UI")?;
    let mut stdout = io::stdout();
    if let Err(error) = execute!(stdout, EnterAlternateScreen) {
        let _ = disable_raw_mode();
        return Err(error).context("failed to enter alternate screen for review UI");
    }
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = match Terminal::new(backend) {
        Ok(terminal) => terminal,
        Err(error) => {
            let _ = disable_raw_mode();
            let _ = execute!(io::stdout(), LeaveAlternateScreen);
            return Err(error).context("failed to initialize review UI terminal");
        }
    };
    let result = review_tree_loop(&mut terminal, targets, session, mode, state);
    if let Err(error) = disable_raw_mode() {
        eprintln!("condom: failed to leave raw mode after review UI: {error:#}");
    }
    if let Err(error) = execute!(terminal.backend_mut(), LeaveAlternateScreen) {
        eprintln!("condom: failed to leave alternate screen after review UI: {error:#}");
    }
    if let Err(error) = terminal.show_cursor() {
        eprintln!("condom: failed to restore cursor after review UI: {error:#}");
    }
    result
}

fn review_tree_loop(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    targets: &[ReviewTarget],
    session: &ReviewUiSession,
    mode: ReviewUiMode,
    state: &mut ReviewTreeState,
) -> Result<ReviewUiOutcome> {
    loop {
        terminal.draw(|frame| draw_review_tree_ui(frame, targets, session, mode, state))?;
        if let TerminalEvent::Key(key) = event::read()? {
            if key.code == KeyCode::Char('c') && key.modifiers.contains(KeyModifiers::CONTROL) {
                return Ok(ReviewUiOutcome::Interrupted);
            }
            match state.screen.clone() {
                ReviewTreeScreen::Browse => match key.code {
                    KeyCode::Esc if mode == ReviewUiMode::Final => {
                        return Ok(ReviewUiOutcome::BackToShell);
                    }
                    KeyCode::Char('b') if mode == ReviewUiMode::Review => {
                        return Ok(ReviewUiOutcome::Shell);
                    }
                    KeyCode::Char('a') if mode == ReviewUiMode::Final => {
                        return Ok(ReviewUiOutcome::Apply);
                    }
                    KeyCode::Char('D') if mode == ReviewUiMode::Final => {
                        return Ok(ReviewUiOutcome::Discard);
                    }
                    KeyCode::Char('b') if mode == ReviewUiMode::Final => {
                        return Ok(ReviewUiOutcome::BackToShell);
                    }
                    KeyCode::Char('d') => {
                        let amount =
                            review_preview_half_page_scroll_amount(terminal.size()?.height);
                        state.scroll_preview_down(amount);
                    }
                    KeyCode::Char('u') => {
                        let amount =
                            review_preview_half_page_scroll_amount(terminal.size()?.height);
                        state.scroll_preview_up(amount);
                    }
                    KeyCode::Down | KeyCode::Char('j') => state.move_next(),
                    KeyCode::Up | KeyCode::Char('k') => state.move_previous(),
                    KeyCode::BackTab => state.collapse_current_or_parent(targets),
                    KeyCode::Tab if key.modifiers.contains(KeyModifiers::SHIFT) => {
                        state.collapse_current_or_parent(targets);
                    }
                    KeyCode::Tab => state.toggle_expanded(targets),
                    KeyCode::Char(' ') => state.toggle_current_selection(targets),
                    KeyCode::Char('A') if mode == ReviewUiMode::Review => state.select_all(targets),
                    KeyCode::Char('n') if mode == ReviewUiMode::Review => state.select_none(),
                    KeyCode::Enter => state.enter_current(targets),
                    _ => {}
                },
                ReviewTreeScreen::Diff {
                    target_index,
                    operation_index,
                    scroll,
                } => match key.code {
                    KeyCode::Esc | KeyCode::Enter | KeyCode::Char('q') => {
                        state.screen = ReviewTreeScreen::Browse;
                    }
                    KeyCode::Left => {
                        state.move_to_adjacent_operation(
                            targets,
                            target_index,
                            operation_index,
                            ReviewOperationDirection::Previous,
                        );
                    }
                    KeyCode::Right => {
                        state.move_to_adjacent_operation(
                            targets,
                            target_index,
                            operation_index,
                            ReviewOperationDirection::Next,
                        );
                    }
                    KeyCode::Char('a') => {
                        state.keep_diff_file_and_advance(targets, target_index, operation_index);
                    }
                    KeyCode::Down | KeyCode::Char('j') => {
                        state.screen = ReviewTreeScreen::Diff {
                            target_index,
                            operation_index,
                            scroll: scroll + 1,
                        };
                    }
                    KeyCode::Up | KeyCode::Char('k') => {
                        state.screen = ReviewTreeScreen::Diff {
                            target_index,
                            operation_index,
                            scroll: scroll.saturating_sub(1),
                        };
                    }
                    KeyCode::PageDown => {
                        state.screen = ReviewTreeScreen::Diff {
                            target_index,
                            operation_index,
                            scroll: scroll + 20,
                        };
                    }
                    KeyCode::PageUp => {
                        state.screen = ReviewTreeScreen::Diff {
                            target_index,
                            operation_index,
                            scroll: scroll.saturating_sub(20),
                        };
                    }
                    KeyCode::Char('d') => {
                        let amount = review_diff_half_page_scroll_amount(terminal.size()?.height);
                        state.screen = ReviewTreeScreen::Diff {
                            target_index,
                            operation_index,
                            scroll: scroll.saturating_add(amount),
                        };
                    }
                    KeyCode::Char('u') => {
                        let amount = review_diff_half_page_scroll_amount(terminal.size()?.height);
                        state.screen = ReviewTreeScreen::Diff {
                            target_index,
                            operation_index,
                            scroll: scroll.saturating_sub(amount),
                        };
                    }
                    KeyCode::Char(' ') => state.toggle_current_selection(targets),
                    _ => {}
                },
            }
        }
    }
}

fn draw_review_tree_ui(
    frame: &mut ratatui::Frame<'_>,
    targets: &[ReviewTarget],
    session: &ReviewUiSession,
    mode: ReviewUiMode,
    state: &mut ReviewTreeState,
) {
    let vertical = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(0),
            Constraint::Length(3),
        ])
        .split(frame.area());
    let title = Paragraph::new(review_tree_title(targets, session, mode, state)).block(
        Block::default()
            .title(format!(" {ICON_PROJECT} review "))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(Color::DarkGray)),
    );
    frame.render_widget(title, vertical[0]);

    match state.screen.clone() {
        ReviewTreeScreen::Browse => {
            let body = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([Constraint::Percentage(42), Constraint::Percentage(58)])
                .split(vertical[1]);
            draw_review_tree_list(frame, body[0], targets, state);
            let preview = Paragraph::new(review_tree_preview(targets, state))
                .block(
                    Block::default()
                        .title(format!(" {ICON_FILE} preview "))
                        .borders(Borders::ALL)
                        .border_style(Style::default().fg(Color::DarkGray)),
                )
                .scroll((state.preview_scroll as u16, 0))
                .wrap(Wrap { trim: false });
            frame.render_widget(preview, body[1]);
        }
        ReviewTreeScreen::Diff {
            target_index,
            operation_index,
            scroll,
        } => {
            let diff = state.diff_text(targets, target_index, operation_index);
            let paragraph = Paragraph::new(diff)
                .block(
                    Block::default()
                        .title(review_diff_title(
                            &targets[target_index],
                            operation_index,
                            state,
                        ))
                        .borders(Borders::ALL)
                        .border_style(Style::default().fg(Color::DarkGray)),
                )
                .scroll((scroll as u16, 0))
                .wrap(Wrap { trim: false });
            frame.render_widget(paragraph, vertical[1]);
        }
    }

    let help = Paragraph::new(review_tree_help(mode, state)).block(
        Block::default()
            .title(" keys ")
            .borders(Borders::ALL)
            .border_style(Style::default().fg(Color::DarkGray)),
    );
    frame.render_widget(help, vertical[2]);
}

fn draw_review_tree_list(
    frame: &mut ratatui::Frame<'_>,
    area: ratatui::layout::Rect,
    targets: &[ReviewTarget],
    state: &ReviewTreeState,
) {
    let items = state
        .rows
        .iter()
        .map(|row| review_tree_list_item(targets, state, row))
        .collect::<Vec<_>>();
    let visible_rows = usize::from(area.height.saturating_sub(2));
    let offset = review_tree_scroll_offset(state.cursor, state.rows.len(), visible_rows, 3);
    let list = List::new(items)
        .block(
            Block::default()
                .title(format!(
                    " {ICON_FOLD_OPEN} changes {}/{} ",
                    state.selected.len(),
                    total_operation_count(targets)
                ))
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::DarkGray)),
        )
        .highlight_symbol("▌ ")
        .highlight_style(
            Style::default()
                .fg(Color::Black)
                .bg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        );
    let mut list_state = ListState::default().with_offset(offset);
    if !state.rows.is_empty() {
        list_state.select(Some(state.cursor));
    }
    frame.render_stateful_widget(list, area, &mut list_state);
}

fn review_tree_title(
    targets: &[ReviewTarget],
    session: &ReviewUiSession,
    mode: ReviewUiMode,
    state: &ReviewTreeState,
) -> String {
    let mode_label = match mode {
        ReviewUiMode::Review => "condom review",
        ReviewUiMode::Final => "condom final",
    };
    format!(
        "{ICON_PROJECT} {mode_label}   {ICON_FILE} mode {}   exit {}   {ICON_TASK_DONE} selected {}/{}",
        session.mode.as_str(),
        review_exit_status_label(session.exit_status),
        state.selected.len(),
        total_operation_count(targets)
    )
}

pub(super) fn review_tree_help(mode: ReviewUiMode, state: &ReviewTreeState) -> &'static str {
    match (&state.screen, mode) {
        (ReviewTreeScreen::Browse, ReviewUiMode::Review) => {
            "↑↓/jk move | d/u preview | enter open/toggle | tab  expand | shift-tab  collapse | space  keep | A/n all/none | b shell | ctrl-c shell"
        }
        (ReviewTreeScreen::Browse, ReviewUiMode::Final) => {
            "↑↓/jk move | d/u preview | enter open/toggle | tab  expand | shift-tab  collapse | space  keep | a apply | D discard | b shell | ctrl-c shell"
        }
        (ReviewTreeScreen::Diff { .. }, _) => {
            "↑↓/jk scroll | d/u half page | ←/→ file | a  keep+next | space toggle | q/enter/esc back | ctrl-c shell"
        }
    }
}

fn review_tree_list_item<'a>(
    targets: &[ReviewTarget],
    state: &ReviewTreeState,
    row: &ReviewTreeRow,
) -> ListItem<'a> {
    match row {
        ReviewTreeRow::Target { target_index } => {
            let target = &targets[*target_index];
            let selected = selected_count_for_target_key(state, target);
            let expanded = state.expanded.contains(&target_expand_key(target));
            let (selection_glyph, selection_color) =
                selection_count_glyph(selected, target.operations.len());
            let (fold_glyph, fold_color) = review_tree_expand_glyph(expanded);
            let (glyph, color) = review_target_glyph(&target.kind);
            ListItem::new(Line::from(vec![
                Span::styled(selection_glyph, Style::default().fg(selection_color)),
                Span::raw(" "),
                Span::styled(fold_glyph, Style::default().fg(fold_color)),
                Span::raw(" "),
                Span::styled(
                    glyph,
                    Style::default().fg(color).add_modifier(Modifier::BOLD),
                ),
                Span::raw(" "),
                Span::styled(
                    review_target_short_label(target),
                    Style::default().add_modifier(Modifier::BOLD),
                ),
                Span::styled(
                    format!("  {selected}/{}", target.operations.len()),
                    Style::default().fg(Color::DarkGray),
                ),
            ]))
        }
        ReviewTreeRow::Directory {
            target_index,
            path,
            depth,
        } => {
            let target = &targets[*target_index];
            let (selected, total) = selected_count_for_prefix_key(state, target, path);
            let expanded = state.expanded.contains(&dir_expand_key(target, path));
            let (selection_glyph, selection_color) = selection_count_glyph(selected, total);
            let (fold_glyph, fold_color) = review_tree_expand_glyph(expanded);
            let (folder_glyph, folder_color) = review_tree_folder_glyph(expanded);
            ListItem::new(Line::from(vec![
                Span::styled(
                    review_tree_indent(*depth),
                    Style::default().fg(Color::DarkGray),
                ),
                Span::styled(selection_glyph, Style::default().fg(selection_color)),
                Span::raw(" "),
                Span::styled(fold_glyph, Style::default().fg(fold_color)),
                Span::raw(" "),
                Span::styled(folder_glyph, Style::default().fg(folder_color)),
                Span::raw(" "),
                Span::styled(path_basename(path), Style::default().fg(folder_color)),
                Span::styled(
                    format!("  {selected}/{total}"),
                    Style::default().fg(Color::DarkGray),
                ),
            ]))
        }
        ReviewTreeRow::Operation {
            target_index,
            operation_index,
            depth,
        } => {
            let target = &targets[*target_index];
            let operation = &target.operations[*operation_index];
            let key = operation_file_key(target, operation);
            let selected = state.selected.contains(&key);
            let (selection_glyph, selection_color) = selection_glyph(selected);
            let (kind_glyph, kind_color) = review_kind_glyph(&operation.kind);
            ListItem::new(Line::from(vec![
                Span::styled(
                    review_tree_indent(*depth),
                    Style::default().fg(Color::DarkGray),
                ),
                Span::styled(selection_glyph, Style::default().fg(selection_color)),
                Span::raw(" "),
                Span::styled(
                    kind_glyph,
                    Style::default().fg(kind_color).add_modifier(Modifier::BOLD),
                ),
                Span::raw(" "),
                Span::styled(ICON_FILE, Style::default().fg(Color::Cyan)),
                Span::raw(" "),
                Span::raw(path_basename(&operation.path)),
            ]))
        }
    }
}

fn review_tree_preview(targets: &[ReviewTarget], state: &mut ReviewTreeState) -> Text<'static> {
    let mut lines = vec![Line::from(vec![
        Span::styled(ICON_TASK_DONE, Style::default().fg(Color::Green)),
        Span::raw(" "),
        Span::styled("selected ", Style::default().fg(Color::DarkGray)),
        Span::styled(
            format!(
                "{}/{}",
                state.selected.len(),
                total_operation_count(targets)
            ),
            Style::default()
                .fg(Color::Green)
                .add_modifier(Modifier::BOLD),
        ),
    ])];
    let Some(row) = state.current_row().cloned() else {
        if total_operation_count(targets) == 0 {
            lines.push(Line::from("no captured changes"));
        } else {
            lines.push(Line::from(
                "all captured changes are hidden by review.fileRules",
            ));
        }
        return Text::from(lines);
    };
    match row {
        ReviewTreeRow::Target { target_index } => {
            let target = &targets[target_index];
            let selected = selected_count_for_target_key(state, target);
            let (glyph, color) = review_target_glyph(&target.kind);
            lines.push(Line::from(""));
            lines.push(icon_metadata_line(
                glyph,
                color,
                "target",
                review_target_short_label(target),
            ));
            lines.push(metadata_line(
                "kind",
                review_target_kind_label(&target.kind),
            ));
            lines.push(metadata_line(
                "selected",
                format!("{selected}/{}", target.operations.len()),
            ));
            lines.push(metadata_line(
                "changes",
                target.operations.len().to_string(),
            ));
            lines.extend(operation_count_lines(&target.operations));
        }
        ReviewTreeRow::Directory {
            target_index, path, ..
        } => {
            let target = &targets[target_index];
            let (selected, total) = selected_count_for_prefix_key(state, target, &path);
            let expanded = state.expanded.contains(&dir_expand_key(target, &path));
            let (folder_glyph, folder_color) = review_tree_folder_glyph(expanded);
            lines.push(Line::from(""));
            lines.push(metadata_line("target", review_target_short_label(target)));
            lines.push(icon_metadata_line(
                folder_glyph,
                folder_color,
                "directory",
                path.clone(),
            ));
            lines.push(metadata_line("selected", format!("{selected}/{total}")));
            lines.extend(operation_count_lines(&operations_for_prefix(target, &path)));
        }
        ReviewTreeRow::Operation {
            target_index,
            operation_index,
            ..
        } => {
            let target = &targets[target_index];
            let operation = &target.operations[operation_index];
            let key = operation_file_key(target, operation);
            let selected = state.selected.contains(&key);
            let (kind_glyph, kind_color) = review_kind_glyph(&operation.kind);
            let (selection_glyph, selection_color) = selection_glyph(selected);
            lines.push(Line::from(""));
            lines.push(metadata_line("target", review_target_short_label(target)));
            lines.push(icon_metadata_line(
                ICON_FILE,
                Color::Cyan,
                "file",
                operation.path.clone(),
            ));
            lines.push(Line::from(vec![
                Span::styled("kind      ", Style::default().fg(Color::DarkGray)),
                Span::styled(
                    kind_glyph,
                    Style::default().fg(kind_color).add_modifier(Modifier::BOLD),
                ),
                Span::raw(" "),
                Span::styled(
                    review_kind_label(&operation.kind),
                    Style::default().fg(kind_color),
                ),
            ]));
            lines.push(Line::from(vec![
                Span::styled("selection ", Style::default().fg(Color::DarkGray)),
                Span::styled(selection_glyph, Style::default().fg(selection_color)),
                Span::raw(" "),
                Span::styled(
                    selection_label(selected),
                    Style::default().fg(selection_color),
                ),
            ]));
            lines.push(Line::from(""));
            lines.extend(state.diff_preview_lines(targets, target_index, operation_index, 80));
        }
    }
    Text::from(lines)
}

pub(super) fn review_target_short_label(target: &ReviewTarget) -> String {
    match target.kind {
        ReviewTargetKind::Project => target
            .label
            .strip_prefix("project ")
            .unwrap_or(&target.label)
            .to_string(),
        ReviewTargetKind::Ephemeral { overlay_index } => {
            let prefix = format!("overlay {overlay_index} ");
            target
                .label
                .strip_prefix(&prefix)
                .unwrap_or(&target.label)
                .to_string()
        }
    }
}

fn path_basename(path: &str) -> String {
    path.rsplit('/').next().unwrap_or(path).to_string()
}

fn metadata_line(label: &'static str, value: impl Into<String>) -> Line<'static> {
    Line::from(vec![
        Span::styled(format!("{label:<10}"), Style::default().fg(Color::DarkGray)),
        Span::raw(value.into()),
    ])
}

fn icon_metadata_line(
    icon: &'static str,
    color: Color,
    label: &'static str,
    value: impl Into<String>,
) -> Line<'static> {
    Line::from(vec![
        Span::styled(format!("{label:<10}"), Style::default().fg(Color::DarkGray)),
        Span::styled(
            icon,
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        ),
        Span::raw(" "),
        Span::raw(value.into()),
    ])
}

fn operation_count_lines(operations: &[ReviewOperation]) -> Vec<Line<'static>> {
    operation_counts(operations)
        .into_iter()
        .map(|(kind, count)| {
            let (glyph, color) = review_kind_glyph(&kind);
            Line::from(vec![
                Span::styled(
                    glyph,
                    Style::default().fg(color).add_modifier(Modifier::BOLD),
                ),
                Span::raw(" "),
                Span::styled(count.to_string(), Style::default().fg(color)),
                Span::raw(" "),
                Span::styled(
                    review_kind_label(&kind),
                    Style::default().fg(Color::DarkGray),
                ),
            ])
        })
        .collect()
}

fn operations_for_prefix(target: &ReviewTarget, path: &str) -> Vec<ReviewOperation> {
    let prefix = format!("{path}/");
    target
        .operations
        .iter()
        .filter(|operation| operation.path.starts_with(&prefix))
        .cloned()
        .collect()
}

fn review_diff_title(
    target: &ReviewTarget,
    operation_index: usize,
    state: &ReviewTreeState,
) -> String {
    let Some(operation) = target.operations.get(operation_index) else {
        return "diff".into();
    };
    let selected = state
        .selected
        .contains(&operation_file_key(target, operation));
    let (selection, _) = selection_glyph(selected);
    let (kind, _) = review_kind_glyph(&operation.kind);
    format!("{selection} {kind} {ICON_FILE} {}", operation.path)
}

pub(super) fn selection_glyph(selected: bool) -> (&'static str, Color) {
    if selected {
        (ICON_TASK_DONE, Color::Green)
    } else {
        (ICON_TASK_DEFAULT, Color::DarkGray)
    }
}

fn selection_label(selected: bool) -> &'static str {
    if selected {
        "keep"
    } else {
        "skip"
    }
}

pub(super) fn selection_count_glyph(selected: usize, total: usize) -> (&'static str, Color) {
    if selected == 0 {
        (ICON_TASK_DEFAULT, Color::DarkGray)
    } else if selected == total {
        (ICON_TASK_DONE, Color::Green)
    } else {
        (ICON_TASK_ACTIVE, Color::Yellow)
    }
}

pub(super) fn review_target_glyph(kind: &ReviewTargetKind) -> (&'static str, Color) {
    match kind {
        ReviewTargetKind::Project => (ICON_PROJECT, Color::Cyan),
        ReviewTargetKind::Ephemeral { .. } => ("◉", Color::Magenta),
    }
}

pub(super) fn review_tree_expand_glyph(expanded: bool) -> (&'static str, Color) {
    if expanded {
        (ICON_FOLD_OPEN, Color::DarkGray)
    } else {
        (ICON_FOLD_CLOSED, Color::DarkGray)
    }
}

pub(super) fn review_tree_folder_glyph(expanded: bool) -> (&'static str, Color) {
    if expanded {
        (ICON_FOLDER_OPEN, Color::Blue)
    } else {
        (ICON_FOLDER_CLOSED, Color::Blue)
    }
}

fn review_tree_indent(depth: usize) -> String {
    "  ".repeat(depth)
}

fn review_kind_glyph(kind: &ReviewOpKind) -> (&'static str, Color) {
    match kind {
        ReviewOpKind::Create => ("✚", Color::Green),
        ReviewOpKind::Modify => ("±", Color::Yellow),
        ReviewOpKind::Delete => (ICON_TASK_CANCELLED, Color::Red),
        ReviewOpKind::Rename => ("↦", Color::Magenta),
        ReviewOpKind::Symlink => ("↪", Color::Blue),
        ReviewOpKind::Metadata => ("◆", Color::DarkGray),
    }
}
