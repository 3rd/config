use super::*;

pub(super) fn render_operation_diff_lines(
    targets: &[ReviewTarget],
    target_index: usize,
    operation_index: usize,
) -> Vec<Line<'static>> {
    let Some(target) = targets.get(target_index) else {
        return vec![Line::from("unknown operation")];
    };
    let Some(operation) = target.operations.get(operation_index) else {
        return vec![Line::from("unknown operation")];
    };
    match operation_diff_output(target, operation) {
        Ok(lines) => lines,
        Err(error) => vec![Line::from(Span::styled(
            format!("failed to render diff: {error:#}"),
            Style::default().fg(Color::Red),
        ))],
    }
}

fn operation_diff_output(
    target: &ReviewTarget,
    operation: &ReviewOperation,
) -> Result<Vec<Line<'static>>> {
    match operation.kind {
        ReviewOpKind::Create => {
            prefixed_file_diff_lines("+", &target.current_root.join(&operation.path))
        }
        ReviewOpKind::Delete => {
            prefixed_file_diff_lines("-", &target.apply_root.join(&operation.path))
        }
        ReviewOpKind::Modify | ReviewOpKind::Symlink => unified_file_diff_lines(
            &target.apply_root.join(&operation.path),
            &target.current_root.join(&operation.path),
        ),
        ReviewOpKind::Rename | ReviewOpKind::Metadata => Ok(vec![Line::from(
            "diff is unavailable for this operation kind",
        )]),
    }
}

fn unified_file_diff_lines(before: &Path, after: &Path) -> Result<Vec<Line<'static>>> {
    let output = Command::new("diff")
        .args(["-u", "--label"])
        .arg(before.display().to_string())
        .arg("--label")
        .arg(after.display().to_string())
        .arg(before)
        .arg(after)
        .output();
    let output = match output {
        Ok(output) => output,
        Err(error) if error.kind() == io::ErrorKind::NotFound => {
            return Ok(vec![Line::from("diff command not found")]);
        }
        Err(error) => return Err(error).context("failed to run diff"),
    };
    if !output.status.success() && output.status.code() != Some(1) {
        bail!(
            "diff exited with status {}; stderr: {}",
            output.status.code().unwrap_or(1),
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }
    Ok(String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(styled_diff_line)
        .collect())
}

fn prefixed_file_diff_lines(prefix: &str, path: &Path) -> Result<Vec<Line<'static>>> {
    match read_text_preview(path)? {
        Some(preview) => {
            let mut lines = Vec::new();
            for line in prefix_preview_lines(prefix, &preview) {
                lines.push(styled_diff_line(&line));
            }
            Ok(lines)
        }
        None => Ok(vec![Line::from("binary or non-utf8 file")]),
    }
}

fn styled_diff_line(line: &str) -> Line<'static> {
    let style = if line.starts_with("@@") {
        Style::default().fg(Color::Cyan)
    } else if line.starts_with("+++") || line.starts_with("---") {
        Style::default()
            .fg(Color::Yellow)
            .add_modifier(Modifier::BOLD)
    } else if line.starts_with('+') {
        Style::default().fg(Color::Green)
    } else if line.starts_with('-') {
        Style::default().fg(Color::Red)
    } else {
        Style::default()
    };
    Line::from(Span::styled(line.to_string(), style))
}

pub(super) fn target_expand_key(target: &ReviewTarget) -> String {
    format!("target:{}", target.id)
}

pub(super) fn dir_expand_key(target: &ReviewTarget, path: &str) -> String {
    format!("dir:{}:{path}", target.id)
}

pub(super) fn operation_file_key(
    target: &ReviewTarget,
    operation: &ReviewOperation,
) -> ReviewFileKey {
    ReviewFileKey {
        target_id: target.id.clone(),
        path: operation.path.clone(),
    }
}

pub(super) fn operation_keys_for_target(
    targets: &[ReviewTarget],
    target_index: usize,
) -> Vec<ReviewFileKey> {
    targets
        .get(target_index)
        .map(|target| {
            target
                .operations
                .iter()
                .map(|operation| operation_file_key(target, operation))
                .collect()
        })
        .unwrap_or_default()
}

pub(super) fn operation_keys_for_prefix(
    targets: &[ReviewTarget],
    target_index: usize,
    prefix: &str,
) -> Vec<ReviewFileKey> {
    targets
        .get(target_index)
        .map(|target| {
            let prefix = format!("{prefix}/");
            target
                .operations
                .iter()
                .filter(|operation| operation.path.starts_with(&prefix))
                .map(|operation| operation_file_key(target, operation))
                .collect()
        })
        .unwrap_or_default()
}

pub(super) fn selected_count_for_target_key(
    state: &ReviewTreeState,
    target: &ReviewTarget,
) -> usize {
    target
        .operations
        .iter()
        .filter(|operation| {
            state
                .selected
                .contains(&operation_file_key(target, operation))
        })
        .count()
}

pub(super) fn selected_count_for_prefix_key(
    state: &ReviewTreeState,
    target: &ReviewTarget,
    path: &str,
) -> (usize, usize) {
    let prefix = format!("{path}/");
    let mut selected = 0;
    let mut total = 0;
    for operation in target
        .operations
        .iter()
        .filter(|operation| operation.path.starts_with(&prefix))
    {
        total += 1;
        if state
            .selected
            .contains(&operation_file_key(target, operation))
        {
            selected += 1;
        }
    }
    (selected, total)
}

pub(super) fn total_operation_count(targets: &[ReviewTarget]) -> usize {
    targets.iter().map(|target| target.operations.len()).sum()
}

pub(super) fn review_target_kind_label(kind: &ReviewTargetKind) -> String {
    match kind {
        ReviewTargetKind::Project => "project".into(),
        ReviewTargetKind::Ephemeral { overlay_index } => format!("overlay-{overlay_index}"),
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct TextPreview {
    pub(super) text: String,
    pub(super) truncated: bool,
}

fn read_text_preview(path: &Path) -> Result<Option<TextPreview>> {
    const PREVIEW_BYTES: usize = 64 * 1024;
    let bytes = fs::read(path).with_context(|| format!("failed to read {}", path.display()))?;
    let truncated = bytes.len() > PREVIEW_BYTES;
    let preview_bytes = &bytes[..bytes.len().min(PREVIEW_BYTES)];
    if preview_bytes.contains(&0) {
        return Ok(None);
    }
    let text = match std::str::from_utf8(preview_bytes) {
        Ok(text) => text.to_string(),
        Err(_) => return Ok(None),
    };
    Ok(Some(TextPreview { text, truncated }))
}

fn prefix_preview_lines(prefix: &str, preview: &TextPreview) -> Vec<String> {
    const PREVIEW_LINES: usize = 200;
    let mut lines = preview
        .text
        .lines()
        .take(PREVIEW_LINES)
        .map(|line| format!("{prefix}{line}"))
        .collect::<Vec<_>>();
    if preview.text.lines().count() > PREVIEW_LINES || preview.truncated {
        lines.push(format!("{prefix}[preview truncated]"));
    }
    lines
}

pub(super) fn diff_entries_from_upper_changes(
    baseline: &BTreeMap<String, FileEntry>,
    upper_dir: &Path,
    captured_root: &Path,
    excludes: &[PathBuf],
) -> Result<Vec<ReviewOperation>> {
    let candidate_paths = upper_changed_paths(upper_dir)?;
    let mut changed_paths = BTreeSet::new();
    for path in candidate_paths {
        if baseline.contains_key(&path) || file_entry_at(&captured_root.join(&path))?.is_some() {
            changed_paths.insert(path);
            continue;
        }
        let prefix = format!("{path}/");
        changed_paths.extend(
            baseline
                .keys()
                .filter(|baseline_path| baseline_path.starts_with(&prefix))
                .cloned(),
        );
    }

    let mut operations = Vec::new();
    for path in changed_paths {
        let captured_path = captured_root.join(&path);
        if is_excluded(&captured_path, excludes) {
            continue;
        }
        if let Some(operation) = diff_entry(
            &path,
            baseline.get(&path),
            file_entry_at(&captured_path)?.as_ref(),
        ) {
            operations.push(operation);
        }
    }
    Ok(operations)
}

fn is_excluded(path: &Path, excludes: &[PathBuf]) -> bool {
    excludes.iter().any(|exclude| path.starts_with(exclude))
}

pub(super) fn collect_entries(
    root: &Path,
    excludes: &[PathBuf],
) -> Result<BTreeMap<String, FileEntry>> {
    let mut entries = BTreeMap::new();
    collect_entries_into(root, root, excludes, &mut entries)?;
    Ok(entries)
}

fn collect_entries_into(
    root: &Path,
    current: &Path,
    excludes: &[PathBuf],
    entries: &mut BTreeMap<String, FileEntry>,
) -> Result<()> {
    for entry in
        fs::read_dir(current).with_context(|| format!("failed to read {}", current.display()))?
    {
        let entry = entry?;
        let path = entry.path();
        if is_excluded(&path, excludes) {
            continue;
        }
        let relative = path
            .strip_prefix(root)
            .unwrap_or(&path)
            .to_string_lossy()
            .replace('\\', "/");
        if relative == ".condom" || relative.starts_with(".condom/") {
            continue;
        }

        let metadata = fs::symlink_metadata(&path)
            .with_context(|| format!("failed to inspect {}", path.display()))?;
        if metadata.file_type().is_symlink() {
            let target = fs::read_link(&path)
                .with_context(|| format!("failed to read {}", path.display()))?;
            let target = target.to_string_lossy().to_string();
            entries.insert(
                relative,
                FileEntry {
                    kind: FileKind::Symlink,
                    hash: hash_bytes(target.as_bytes()),
                    target: Some(target),
                },
            );
        } else if metadata.is_dir() {
            collect_entries_into(root, &path, excludes, entries)?;
        } else if metadata.is_file() {
            entries.insert(
                relative,
                FileEntry {
                    kind: FileKind::File,
                    hash: hash_file(&path)?,
                    target: None,
                },
            );
        }
    }
    Ok(())
}

pub(super) fn file_entry_at(path: &Path) -> Result<Option<FileEntry>> {
    let metadata = match fs::symlink_metadata(path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(None),
        Err(error) => {
            return Err(error).with_context(|| format!("failed to inspect {}", path.display()));
        }
    };
    if metadata.file_type().is_symlink() {
        let target =
            fs::read_link(path).with_context(|| format!("failed to read {}", path.display()))?;
        let target = target.to_string_lossy().to_string();
        return Ok(Some(FileEntry {
            kind: FileKind::Symlink,
            hash: hash_bytes(target.as_bytes()),
            target: Some(target),
        }));
    }
    if metadata.is_file() {
        return Ok(Some(FileEntry {
            kind: FileKind::File,
            hash: hash_file(path)?,
            target: None,
        }));
    }
    Ok(None)
}

fn diff_entry(
    path: &str,
    before: Option<&FileEntry>,
    after: Option<&FileEntry>,
) -> Option<ReviewOperation> {
    match (before, after) {
        (None, Some(after)) => Some(operation(
            if after.kind == FileKind::Symlink {
                ReviewOpKind::Symlink
            } else {
                ReviewOpKind::Create
            },
            path.to_string(),
            None,
            Some(after),
        )),
        (Some(before), None) => Some(operation(
            ReviewOpKind::Delete,
            path.to_string(),
            Some(before),
            None,
        )),
        (Some(before), Some(after)) if before != after => Some(operation(
            if after.kind == FileKind::Symlink {
                ReviewOpKind::Symlink
            } else {
                ReviewOpKind::Modify
            },
            path.to_string(),
            Some(before),
            Some(after),
        )),
        _ => None,
    }
}

#[cfg(test)]
pub(super) fn diff_entries(
    baseline: &BTreeMap<String, FileEntry>,
    captured: &BTreeMap<String, FileEntry>,
) -> Vec<ReviewOperation> {
    let paths = baseline
        .keys()
        .chain(captured.keys())
        .cloned()
        .collect::<BTreeSet<_>>();
    let mut operations = Vec::new();
    for path in paths {
        if let Some(operation) = diff_entry(&path, baseline.get(&path), captured.get(&path)) {
            operations.push(operation);
        }
    }
    operations
}
