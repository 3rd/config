use super::*;

pub const REVIEW_JOURNAL_VERSION: u32 = 1;

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ReviewOpKind {
    Create,
    Modify,
    Delete,
    Rename,
    Symlink,
    Metadata,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReviewOperation {
    pub kind: ReviewOpKind,
    pub path: String,
    pub target: Option<String>,
    pub baseline_hash: Option<String>,
    pub captured_hash: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub baseline_kind: Option<ReviewEntryKind>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub captured_kind: Option<ReviewEntryKind>,
    #[serde(default, skip_serializing_if = "review_visibility_is_normal")]
    pub review_visibility: ReviewFileVisibility,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub default_selected: Option<bool>,
}

fn review_visibility_is_normal(visibility: &ReviewFileVisibility) -> bool {
    *visibility == ReviewFileVisibility::Normal
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReviewJournal {
    pub schema_version: u32,
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
    pub command: Vec<String>,
    pub exit_status: Option<i32>,
    pub operations: Vec<ReviewOperation>,
    pub risk_flags: Vec<String>,
    pub accepted: bool,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ReviewEntryKind {
    File,
    Symlink,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) struct FileEntry {
    pub(super) kind: FileKind,
    pub(super) hash: String,
    pub(super) target: Option<String>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) enum FileKind {
    File,
    Symlink,
}

impl From<&FileKind> for ReviewEntryKind {
    fn from(kind: &FileKind) -> Self {
        match kind {
            FileKind::File => Self::File,
            FileKind::Symlink => Self::Symlink,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ReviewSession {
    pub id: Uuid,
    pub session_dir: PathBuf,
    pub workspace_dir: PathBuf,
    pub upper_dir: PathBuf,
    pub work_dir: PathBuf,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) enum ReviewTargetKind {
    Project,
    Ephemeral { overlay_index: usize },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) struct ReviewTarget {
    pub(super) id: String,
    pub(super) label: String,
    pub(super) kind: ReviewTargetKind,
    pub(super) baseline_root: PathBuf,
    pub(super) current_root: PathBuf,
    pub(super) apply_root: PathBuf,
    pub(super) operations: Vec<ReviewOperation>,
    pub(super) selected_by_default: bool,
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub(super) struct ReviewSelection {
    pub(super) selected: BTreeSet<(usize, usize)>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ReviewDecision {
    pub(super) schema_version: u32,
    pub(super) action: ReviewDecisionAction,
    pub(super) selected: Vec<ReviewFileKey>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub(super) enum ReviewDecisionAction {
    Apply,
    Discard,
}

struct ReviewRun<'a> {
    pub(super) project: &'a ProjectContext,
    pub(super) state: &'a StatePaths,
    pub(super) config: &'a CondomConfig,
    pub(super) mode: ExecutionMode,
    pub(super) command: &'a [String],
    pub(super) extra_env: &'a BTreeMap<String, String>,
    pub(super) event_log: &'a EventLog,
    pub(super) policy_snapshot: &'a PolicySnapshot,
    pub(super) runner_path: Option<&'a Path>,
    pub(super) runtime_path: Option<&'a str>,
    pub(super) ephemeral_overlays: &'a [capture::EphemeralOverlay],
}

impl ReviewJournal {
    pub fn new(command: Vec<String>) -> Self {
        Self {
            schema_version: REVIEW_JOURNAL_VERSION,
            id: Uuid::new_v4(),
            created_at: Utc::now(),
            command,
            exit_status: None,
            operations: Vec::new(),
            risk_flags: Vec::new(),
            accepted: false,
        }
    }

    pub fn detect_conflicts<'a>(
        &'a self,
        live_hashes: &BTreeMap<String, String>,
    ) -> Vec<&'a ReviewOperation> {
        self.operations
            .iter()
            .filter(|operation| operation_conflicts(operation, live_hashes))
            .collect()
    }
}

// Keep this exported entrypoint stable; ReviewRun is the internal normalized shape.

#[allow(clippy::too_many_arguments)]
pub fn run_review_session(
    project: &ProjectContext,
    state: &StatePaths,
    config: &CondomConfig,
    command: &[String],
    ephemeral_overlays: &[capture::EphemeralOverlay],
    extra_env: &BTreeMap<String, String>,
    event_log: &EventLog,
    policy_snapshot: &PolicySnapshot,
) -> Result<i32> {
    run_review_session_with_runner(
        project,
        state,
        config,
        ExecutionMode::Review,
        command,
        ephemeral_overlays,
        extra_env,
        event_log,
        policy_snapshot,
        None,
        None,
    )
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn run_review_session_with_runner(
    project: &ProjectContext,
    state: &StatePaths,
    config: &CondomConfig,
    mode: ExecutionMode,
    command: &[String],
    ephemeral_overlays: &[capture::EphemeralOverlay],
    extra_env: &BTreeMap<String, String>,
    event_log: &EventLog,
    policy_snapshot: &PolicySnapshot,
    runner_path: Option<&Path>,
    runtime_path: Option<&str>,
) -> Result<i32> {
    let session = create_session();
    let runtime_dir = capture::bind_capture_runtime_project_dir(&session.session_dir);
    let review_state = state.with_runtime_dir(runtime_dir);
    run_review_session_with_runner_in_session(
        session,
        project,
        &review_state,
        config,
        mode,
        command,
        ephemeral_overlays,
        extra_env,
        event_log,
        policy_snapshot,
        runner_path,
        runtime_path,
    )
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn run_review_session_with_runner_in_session(
    session: ReviewSession,
    project: &ProjectContext,
    state: &StatePaths,
    config: &CondomConfig,
    mode: ExecutionMode,
    command: &[String],
    ephemeral_overlays: &[capture::EphemeralOverlay],
    extra_env: &BTreeMap<String, String>,
    event_log: &EventLog,
    policy_snapshot: &PolicySnapshot,
    runner_path: Option<&Path>,
    runtime_path: Option<&str>,
) -> Result<i32> {
    let run = ReviewRun {
        project,
        state,
        config,
        mode,
        command,
        extra_env,
        event_log,
        policy_snapshot,
        runner_path,
        runtime_path,
        ephemeral_overlays,
    };
    let result = run_mounted_review_session(&run, &session);
    cleanup_session(&session);
    result
}

fn run_mounted_review_session(run: &ReviewRun<'_>, session: &ReviewSession) -> Result<i32> {
    let mut overlay = capture::mount_overlay_capture(capture::OverlayCaptureMount {
        lower_dir: &run.project.root,
        upper_dir: &session.upper_dir,
        work_dir: &session.work_dir,
        merged_dir: &session.workspace_dir,
        fuse_overlayfs: &capture::configured_fuse_overlayfs_path(),
    })?;
    let mut ephemeral_overlays = capture::mount_ephemeral_overlays(
        &run.project.root,
        &session.session_dir,
        run.ephemeral_overlays,
        &capture::configured_fuse_overlayfs_path(),
    )?;
    let result = run_review_session_inner(run, session);
    let ephemeral_unmount_result = ephemeral_overlays.unmount();
    if let Err(error) = ephemeral_unmount_result {
        if result.is_ok() {
            return Err(error);
        }
        eprintln!(
            "condom: failed to unmount ephemeral review overlays in {}: {error:#}",
            session.session_dir.display()
        );
    }
    let unmount_result = overlay.unmount();
    if let Err(error) = unmount_result {
        if result.is_ok() {
            return Err(error);
        }
        eprintln!(
            "condom: failed to unmount review capture {}: {error:#}",
            session.workspace_dir.display()
        );
    }
    result
}

fn run_review_session_inner(run: &ReviewRun<'_>, session: &ReviewSession) -> Result<i32> {
    let live_excludes = live_excludes(run.project, run.state);
    let baseline = collect_entries(&run.project.root, &live_excludes)?;

    let code = capture::run_with_bind_capture(capture::BindCaptureRun {
        project: run.project,
        state: run.state,
        session_dir: &session.session_dir,
        workspace_dir: &session.workspace_dir,
        config: run.config,
        mode: run.mode,
        command: run.command,
        extra_env: run.extra_env,
        event_log: run.event_log,
        policy_snapshot: run.policy_snapshot,
        runner_path: run.runner_path,
        runtime_path: run.runtime_path,
        ephemeral_overlays: run.ephemeral_overlays,
        mediate_filesystem: true,
        review_inspection: false,
    })?;

    write_review_ui_session(run, session, Some(code))?;
    run_review_shell(run, session)?;

    let targets = build_review_targets(run, session, &baseline)?;
    if review_targets_are_empty(&targets) {
        println!("no captured changes");
        return Ok(code);
    }

    print_review_targets_summary(&targets, run.command, Some(code));
    let decision = read_review_decision(session)?;
    let selection = match decision {
        Some(decision) if decision.action == ReviewDecisionAction::Apply => {
            review_selection_from_file_keys(&targets, &decision.selected)
        }
        Some(_) => ReviewSelection::default(),
        None => {
            println!("no final review decision; discarding captured changes");
            ReviewSelection::default()
        }
    };

    if selection.selected.is_empty() {
        run.event_log.append(&review_event(
            run.project,
            run.mode,
            run.command,
            session,
            Decision::Rejected,
            "review changes discarded",
        ))?;
        println!("discarded captured changes");
    } else {
        let mut journal = ReviewJournal::new(run.command.to_vec());
        journal.id = session.id;
        journal.exit_status = Some(code);
        journal.operations = selected_operations(&targets, &selection);
        journal.risk_flags = risk_flags(&journal.operations);
        apply_review_selection_with_event(
            ReviewEventContext {
                project: run.project,
                mode: run.mode,
                command: run.command,
                event_log: run.event_log,
            },
            session,
            &targets,
            &selection,
            &mut journal,
        )?;
        println!("approved captured changes");
    }

    Ok(code)
}

pub(super) struct ReviewEventContext<'a> {
    pub(super) project: &'a ProjectContext,
    pub(super) mode: ExecutionMode,
    pub(super) command: &'a [String],
    pub(super) event_log: &'a EventLog,
}

pub(crate) fn create_session() -> ReviewSession {
    let id = Uuid::new_v4();
    let session_dir = temporary_review_session_dir(id);
    let workspace_dir = session_dir.join("merged");
    let upper_dir = session_dir.join("upper");
    let work_dir = session_dir.join("work");
    ReviewSession {
        id,
        session_dir,
        workspace_dir,
        upper_dir,
        work_dir,
    }
}

fn temporary_review_session_dir(id: Uuid) -> PathBuf {
    review_session_base_dir().join(format!("condom-review-{id}"))
}

pub(super) fn review_session_base_dir() -> PathBuf {
    if let Some(base) = std::env::var_os("CONDOM_REVIEW_TMPDIR") {
        return PathBuf::from(base);
    }

    if let Some(runtime_dir) = std::env::var_os("XDG_RUNTIME_DIR") {
        let base = PathBuf::from(runtime_dir).join("condom/review");
        if ensure_review_session_base(&base) {
            return base;
        }
    }

    let shared_memory_base = PathBuf::from("/dev/shm/condom-review");
    if Path::new("/dev/shm").is_dir() && ensure_review_session_base(&shared_memory_base) {
        return shared_memory_base;
    }

    std::env::temp_dir()
}

fn ensure_review_session_base(base: &Path) -> bool {
    fs::create_dir_all(base).is_ok() && base.is_dir()
}

fn run_review_shell(run: &ReviewRun<'_>, session: &ReviewSession) -> Result<()> {
    let helpers = prepare_review_shell_helpers(run, session)?;
    let mut shell_env = run.extra_env.clone();
    prepend_path(&mut shell_env, &helpers.sandbox_bin_dir);
    shell_env.insert(
        "CONDOM_REVIEW_SESSION".into(),
        helpers.sandbox_session_path.display().to_string(),
    );
    let shell = vec![helpers.sandbox_shell_path.display().to_string()];
    print_review_shell_entry(run.ephemeral_overlays.len());
    let code = capture::run_with_bind_capture(capture::BindCaptureRun {
        project: run.project,
        state: run.state,
        session_dir: &session.session_dir,
        workspace_dir: &session.workspace_dir,
        config: run.config,
        mode: run.mode,
        command: &shell,
        extra_env: &shell_env,
        event_log: run.event_log,
        policy_snapshot: run.policy_snapshot,
        runner_path: run.runner_path,
        runtime_path: None,
        ephemeral_overlays: run.ephemeral_overlays,
        mediate_filesystem: false,
        review_inspection: true,
    })?;
    if code != 0 {
        println!("review shell exited with status {code}");
    }
    Ok(())
}

struct ReviewShellHelpers {
    pub(super) sandbox_bin_dir: PathBuf,
    pub(super) sandbox_shell_path: PathBuf,
    pub(super) sandbox_session_path: PathBuf,
}

fn prepare_review_shell_helpers(
    run: &ReviewRun<'_>,
    session: &ReviewSession,
) -> Result<ReviewShellHelpers> {
    let runtime_review_dir = runtime_review_dir(session);
    let bin_dir = runtime_review_dir.join("bin");
    fs::create_dir_all(&bin_dir)
        .with_context(|| format!("failed to create {}", bin_dir.display()))?;
    let helper_path = bin_dir.join("condom");
    fs::write(&helper_path, review_helper_script(run)?)
        .with_context(|| format!("failed to write {}", helper_path.display()))?;
    fs::set_permissions(&helper_path, fs::Permissions::from_mode(0o755))
        .with_context(|| format!("failed to mark {} executable", helper_path.display()))?;
    let shell_path = bin_dir.join("condom-shell");
    fs::write(&shell_path, review_shell_script())
        .with_context(|| format!("failed to write {}", shell_path.display()))?;
    fs::set_permissions(&shell_path, fs::Permissions::from_mode(0o755))
        .with_context(|| format!("failed to mark {} executable", shell_path.display()))?;
    Ok(ReviewShellHelpers {
        sandbox_bin_dir: sandbox_review_dir(run.project).join("bin"),
        sandbox_shell_path: sandbox_review_dir(run.project).join("bin/condom-shell"),
        sandbox_session_path: sandbox_review_session_path(run.project),
    })
}

fn runtime_review_dir(session: &ReviewSession) -> PathBuf {
    session.session_dir.join("runtime/.condom/review")
}

fn sandbox_review_dir(project: &ProjectContext) -> PathBuf {
    project.root.join(".condom/review")
}

fn sandbox_review_session_path(project: &ProjectContext) -> PathBuf {
    sandbox_review_dir(project).join("session.json")
}

fn runtime_review_session_path(session: &ReviewSession) -> PathBuf {
    runtime_review_dir(session).join("session.json")
}

pub(super) fn runtime_review_decision_path(session: &ReviewSession) -> PathBuf {
    runtime_review_dir(session).join("decision.json")
}

fn prepend_path(env: &mut BTreeMap<String, String>, path: &Path) {
    let existing = env
        .get("PATH")
        .cloned()
        .or_else(|| std::env::var("PATH").ok())
        .unwrap_or_default();
    let value = if existing.is_empty() {
        path.display().to_string()
    } else {
        format!("{}:{existing}", path.display())
    };
    env.insert("PATH".into(), value);
}

pub(super) fn review_shell_script() -> String {
    format!(
        r#"#!{helper_shell}
set -u

condom review

while :; do
  if [ -n "${{CONDOM_REVIEW_SHELL:-}}" ]; then
    sh -lc "$CONDOM_REVIEW_SHELL"
  elif [ -n "${{SHELL:-}}" ]; then
    "$SHELL"
  else
    sh
  fi
  shell_status="$?"
  if [ "$shell_status" -ne 0 ]; then
    printf 'review shell exited with status %s\n' "$shell_status"
  fi
  condom final
  final_status="$?"
  if [ "$final_status" -eq {back_to_shell_exit} ]; then
    continue
  fi
  exit 0
done
"#,
        helper_shell = REVIEW_HELPER_SHELL,
        back_to_shell_exit = REVIEW_UI_BACK_TO_SHELL_EXIT,
    )
}

fn print_review_shell_entry(ephemeral_overlay_count: usize) {
    println!("entering review shell; exit the shell to approve or discard");
    println!("review helpers:");
    println!("- condom review");
    println!("- condom help");
    println!("- condom diff");
    println!("- condom status");
    if ephemeral_overlay_count > 0 {
        println!("- condom overlays");
        println!("- condom diff --target overlay-<index>");
    }
}

fn review_helper_script(run: &ReviewRun<'_>) -> Result<String> {
    let project_root = run.project.root.display().to_string();
    let baseline = run
        .project
        .root
        .join(".condom/review/baseline")
        .display()
        .to_string();
    let mut target_list = format!(
        "  printf '%s\\n' {}\n",
        shell_quote(&format!("project {}", run.project.root.display()))
    );
    let mut target_cases = format!(
        "    project) left={}; right={}; label={} ;;\n",
        shell_quote(&baseline),
        shell_quote(&project_root),
        shell_quote(&format!("project {}", run.project.root.display()))
    );
    let mut all_target_diffs = String::from("  run_target_diff project || status=\"$?\"\n");
    let mut all_target_statuses = String::from("  run_target_status project || status=\"$?\"\n");
    let mut overlay_list = String::new();
    for (index, overlay) in run.ephemeral_overlays.iter().enumerate() {
        let destination =
            capture::ephemeral_overlay_absolute_destination(&run.project.root, overlay)?
                .display()
                .to_string();
        let baseline = run
            .project
            .root
            .join(".condom/review/overlays")
            .join(index.to_string())
            .join("baseline")
            .display()
            .to_string();
        overlay_list.push_str(&format!(
            "  printf '%s\\n' {}\n",
            shell_quote(&format!(
                "[{index}] {} -> {destination}",
                overlay.source.display()
            ))
        ));
        target_list.push_str(&format!(
            "  printf '%s\\n' {}\n",
            shell_quote(&format!(
                "overlay-{index} {} -> {destination}",
                overlay.source.display()
            ))
        ));
        target_cases.push_str(&format!(
            "    overlay-{index}) left={}; right={}; label={} ;;\n",
            shell_quote(&baseline),
            shell_quote(&destination),
            shell_quote(&format!(
                "overlay-{index} {} -> {destination}",
                overlay.source.display()
            ))
        ));
        all_target_diffs.push_str(&format!(
            "  run_target_diff overlay-{index} || status=\"$?\"\n"
        ));
        all_target_statuses.push_str(&format!(
            "  run_target_status overlay-{index} || status=\"$?\"\n"
        ));
    }
    if overlay_list.is_empty() {
        overlay_list.push_str("  printf '%s\\n' 'no ephemeral overlays configured'\n");
    }

    Ok(format!(
        r#"#!{helper_shell}
set -u

PROJECT_ROOT={project_root}
BASELINE_ROOT={baseline}
REVIEW_SESSION="${{CONDOM_REVIEW_SESSION:-$PROJECT_ROOT/.condom/review/session.json}}"
REVIEW_UI="$PROJECT_ROOT/.condom/review/bin/condom-review-ui"

usage() {{
  cat <<'USAGE'
condom review helpers:
  condom review
  condom help
  condom status
  condom diff
  condom diff --target <project|overlay-N>
  condom overlays
USAGE
}}

normalize_diff_status() {{
  status="$1"
  if [ "$status" -eq 1 ]; then
    return 0
  fi
  return "$status"
}}

diff_output_path() {{
  if command -v mktemp >/dev/null 2>&1; then
    mktemp "${{TMPDIR:-/tmp}}/condom-diff.XXXXXX"
    return "$?"
  fi
  output="${{TMPDIR:-/tmp}}/condom-diff.$$"
  : > "$output" || return "$?"
  printf '%s\n' "$output"
}}

page_file() {{
  file="$1"
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    cat "$file"
    return "$?"
  fi
  if [ "${{CONDOM_REVIEW_PAGER:-}}" = "cat" ] || [ "${{PAGER:-}}" = "cat" ]; then
    cat "$file"
    return "$?"
  fi
  case "${{TERM:-}}" in
    ""|dumb)
      cat "$file"
      return "$?"
      ;;
  esac
  if [ -n "${{CONDOM_REVIEW_PAGER:-}}" ] && [ "${{CONDOM_REVIEW_PAGER#* }}" = "$CONDOM_REVIEW_PAGER" ]; then
    "$CONDOM_REVIEW_PAGER" "$file"
    return "$?"
  fi
  if [ -n "${{PAGER:-}}" ] && [ "${{PAGER#* }}" = "$PAGER" ]; then
    "$PAGER" "$file"
    return "$?"
  fi
  if command -v less >/dev/null 2>&1; then
    LESS="${{LESS:-FRX}}" less -R "$file"
    return "$?"
  fi
  cat "$file"
}}

run_diff() {{
  left="$1"
  right="$2"
  output="$(diff_output_path)" || return "$?"
  if command -v delta >/dev/null 2>&1 && command -v diff >/dev/null 2>&1; then
    raw_output="$(diff_output_path)" || {{
      rm -f "$output"
      return "$?"
    }}
    diff --color=never -ruN --exclude=.git --exclude=.condom "$left" "$right" > "$raw_output"
    return_normalized="$?"
    if ! delta --paging=never < "$raw_output" > "$output"; then
      cat "$raw_output" > "$output"
    fi
    rm -f "$raw_output"
    page_file "$output"
    page_status="$?"
    rm -f "$output"
    if [ "$page_status" -ne 0 ]; then
      return "$page_status"
    fi
    normalize_diff_status "$return_normalized"
    return "$?"
  fi
  if command -v difft >/dev/null 2>&1; then
    difft --color=always "$left" "$right" > "$output"
    return_normalized="$?"
    page_file "$output"
    page_status="$?"
    rm -f "$output"
    if [ "$page_status" -ne 0 ]; then
      return "$page_status"
    fi
    normalize_diff_status "$return_normalized"
    return "$?"
  fi
  if ! command -v diff >/dev/null 2>&1; then
    rm -f "$output"
    printf '%s\n' 'diff command not found' >&2
    return 127
  fi
  diff --color=always -ruN --exclude=.git --exclude=.condom "$left" "$right" > "$output"
  return_normalized="$?"
  page_file "$output"
  page_status="$?"
  rm -f "$output"
  if [ "$page_status" -ne 0 ]; then
    return "$page_status"
  fi
  normalize_diff_status "$return_normalized"
  return "$?"
}}

run_status() {{
  left="$1"
  right="$2"
  if ! command -v diff >/dev/null 2>&1; then
    printf '%s\n' 'diff command not found' >&2
    return 127
  fi
  diff -qrN --exclude=.git --exclude=.condom "$left" "$right"
  return_normalized="$?"
  normalize_diff_status "$return_normalized"
  return "$?"
}}

list_overlays() {{
{overlay_list}}}

list_targets() {{
{target_list}}}

select_target() {{
  case "$1" in
{target_cases}    *)
      printf 'unknown review target: %s\n' "$1" >&2
      exit 2
      ;;
  esac
}}

print_header() {{
  printf '\033[1;36m== %s ==\033[0m\n' "$1"
}}

run_target_diff() {{
  select_target "$1"
  print_header "$label"
  run_diff "$left" "$right"
}}

run_target_status() {{
  select_target "$1"
  print_header "$label"
  run_status "$left" "$right"
}}

run_all_diffs() {{
  status=0
{all_target_diffs}  return "$status"
}}

run_all_statuses() {{
  status=0
{all_target_statuses}  return "$status"
}}

command="${{1:-help}}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "$command" in
  review)
    if [ "$#" -ne 0 ]; then
      printf '%s\n' 'usage: condom review' >&2
      exit 2
    fi
    exec "$REVIEW_UI" __review-ui --mode review --session "$REVIEW_SESSION"
    ;;
  final)
    if [ "$#" -ne 0 ]; then
      printf '%s\n' 'usage: condom final' >&2
      exit 2
    fi
    exec "$REVIEW_UI" __review-ui --mode final --session "$REVIEW_SESSION"
    ;;
  help|-h|--help)
    usage
    ;;
  diff)
    if [ "$#" -eq 0 ]; then
      run_all_diffs
    elif [ "$#" -eq 2 ] && [ "$1" = "--target" ]; then
      run_target_diff "$2"
    else
      printf '%s\n' 'usage: condom diff [--target <project|overlay-N>]' >&2
      exit 2
    fi
    ;;
  status)
    if [ "$#" -eq 0 ]; then
      run_all_statuses
    elif [ "$#" -eq 2 ] && [ "$1" = "--target" ]; then
      run_target_status "$2"
    else
      printf '%s\n' 'usage: condom status [--target <project|overlay-N>]' >&2
      exit 2
    fi
    ;;
  overlays)
    list_overlays
    ;;
  targets)
    list_targets
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
"#,
        project_root = shell_quote(&project_root),
        baseline = shell_quote(&baseline),
        helper_shell = REVIEW_HELPER_SHELL,
        overlay_list = overlay_list,
        target_list = target_list,
        target_cases = target_cases,
        all_target_diffs = all_target_diffs,
        all_target_statuses = all_target_statuses
    ))
}

fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\\''"))
}

fn stdio_is_tty() -> bool {
    unsafe { libc::isatty(libc::STDIN_FILENO) == 1 && libc::isatty(libc::STDOUT_FILENO) == 1 }
}

pub(super) fn review_exit_status_label(exit_status: Option<i32>) -> String {
    exit_status
        .map(|code| code.to_string())
        .unwrap_or_else(|| "unknown".into())
}

fn review_command_label(command: &[String]) -> String {
    serde_json::to_string(&redact_command(command)).unwrap_or_else(|_| "[]".into())
}

fn json_string(value: &str) -> String {
    serde_json::to_string(value).unwrap_or_else(|_| "\"<unprintable>\"".into())
}

pub(super) fn operation_counts(operations: &[ReviewOperation]) -> Vec<(ReviewOpKind, usize)> {
    let mut counts = BTreeMap::<String, (ReviewOpKind, usize)>::new();
    for operation in operations {
        let key = review_kind_label(&operation.kind).to_string();
        counts
            .entry(key)
            .and_modify(|(_kind, count)| *count += 1)
            .or_insert((operation.kind.clone(), 1));
    }
    counts.into_values().collect()
}

pub(super) fn review_kind_label(kind: &ReviewOpKind) -> &'static str {
    match kind {
        ReviewOpKind::Create => "create",
        ReviewOpKind::Modify => "modify",
        ReviewOpKind::Delete => "delete",
        ReviewOpKind::Rename => "rename",
        ReviewOpKind::Symlink => "symlink",
        ReviewOpKind::Metadata => "metadata",
    }
}

fn print_risk_flags(risk_flags: &[String]) {
    if risk_flags.is_empty() {
        return;
    }
    println!("risk flags:");
    for flag in risk_flags {
        println!("- {flag}");
    }
}

pub(crate) fn cleanup_session(session: &ReviewSession) {
    if let Err(error) = fs::remove_dir_all(&session.session_dir) {
        if error.kind() == io::ErrorKind::NotFound {
            return;
        }
        eprintln!(
            "condom: failed to remove review session {}: {error:#}",
            session.session_dir.display()
        );
    }
}

fn write_bytes_atomic(path: &Path, bytes: &[u8]) -> Result<()> {
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("review");
    let temp = path.with_file_name(format!(".{file_name}.tmp"));
    fs::write(&temp, bytes).with_context(|| format!("failed to write {}", temp.display()))?;
    fs::rename(&temp, path).with_context(|| format!("failed to persist {}", path.display()))?;
    Ok(())
}

fn copy_entry(source: &Path, destination: &Path) -> Result<()> {
    let metadata = fs::symlink_metadata(source)
        .with_context(|| format!("failed to inspect {}", source.display()))?;
    if metadata.file_type().is_symlink() {
        copy_symlink(source, destination)
    } else if metadata.is_dir() {
        fs::create_dir_all(destination)
            .with_context(|| format!("failed to create {}", destination.display()))?;
        for entry in
            fs::read_dir(source).with_context(|| format!("failed to read {}", source.display()))?
        {
            let entry = entry?;
            copy_entry(&entry.path(), &destination.join(entry.file_name()))?;
        }
        Ok(())
    } else if metadata.is_file() {
        if let Some(parent) = destination.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("failed to create {}", parent.display()))?;
        }
        fs::copy(source, destination)
            .with_context(|| format!("failed to copy {}", source.display()))?;
        Ok(())
    } else {
        Ok(())
    }
}

#[cfg(unix)]
fn copy_symlink(source: &Path, destination: &Path) -> Result<()> {
    let target =
        fs::read_link(source).with_context(|| format!("failed to read {}", source.display()))?;
    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }
    std::os::unix::fs::symlink(&target, destination)
        .with_context(|| format!("failed to create symlink {}", destination.display()))
}

#[cfg(not(unix))]
fn copy_symlink(_source: &Path, _destination: &Path) -> Result<()> {
    bail!("symlink review capture is only supported on Unix")
}

fn live_excludes(project: &ProjectContext, state: &StatePaths) -> Vec<PathBuf> {
    let mut excludes = default_excludes(&project.root);
    excludes.push(state.xdg_state_dir.clone());
    if let Ok(relative_state) = state.xdg_state_dir.strip_prefix(&project.root) {
        if let Some(first_component) = relative_state.components().next() {
            excludes.push(project.root.join(first_component.as_os_str()));
        }
    }
    excludes
}

fn captured_excludes(
    project: &ProjectContext,
    state: &StatePaths,
    session: &ReviewSession,
) -> Vec<PathBuf> {
    let mut excludes = default_excludes(&session.workspace_dir);
    excludes.extend(
        live_excludes(project, state)
            .into_iter()
            .filter_map(|path| {
                path.strip_prefix(&project.root)
                    .ok()
                    .map(|relative| session.workspace_dir.join(relative))
            }),
    );
    excludes
}

fn default_excludes(root: &Path) -> Vec<PathBuf> {
    vec![root.join(".condom")]
}

fn build_review_targets(
    run: &ReviewRun<'_>,
    session: &ReviewSession,
    project_baseline: &BTreeMap<String, FileEntry>,
) -> Result<Vec<ReviewTarget>> {
    let project_operations = review_operations_with_file_rules(
        diff_entries_from_upper_changes(
            project_baseline,
            &session.upper_dir,
            &session.workspace_dir,
            &captured_excludes(run.project, run.state, session),
        )?,
        &run.config.review.file_rules,
    );
    let mut targets = vec![ReviewTarget {
        id: "project".into(),
        label: format!("project {}", run.project.root.display()),
        kind: ReviewTargetKind::Project,
        baseline_root: run.project.root.clone(),
        current_root: session.workspace_dir.clone(),
        apply_root: run.project.root.clone(),
        operations: project_operations,
        selected_by_default: true,
    }];

    for (index, overlay) in run.ephemeral_overlays.iter().enumerate() {
        let source = fs::canonicalize(&overlay.source).with_context(|| {
            format!(
                "failed to resolve ephemeral overlay source {}",
                overlay.source.display()
            )
        })?;
        let current_root = capture::ephemeral_overlay_session_mount(&session.session_dir, index);
        let upper_dir = capture::ephemeral_overlay_session_upper_dir(&session.session_dir, index);
        let baseline = collect_entries(&source, &default_excludes(&source))?;
        let operations = review_operations_with_file_rules(
            diff_entries_from_upper_changes(
                &baseline,
                &upper_dir,
                &current_root,
                &default_excludes(&current_root),
            )?,
            &run.config.review.file_rules,
        );
        targets.push(ReviewTarget {
            id: format!("overlay-{index}"),
            label: format!(
                "overlay {index} {} -> {}",
                source.display(),
                capture::ephemeral_overlay_absolute_destination(&run.project.root, overlay)?
                    .display()
            ),
            kind: ReviewTargetKind::Ephemeral {
                overlay_index: index,
            },
            baseline_root: source.clone(),
            current_root,
            apply_root: source,
            operations,
            selected_by_default: true,
        });
    }
    Ok(targets)
}

fn review_targets_are_empty(targets: &[ReviewTarget]) -> bool {
    targets.iter().all(|target| target.operations.is_empty())
}

pub(super) fn review_operations_with_file_rules(
    mut operations: Vec<ReviewOperation>,
    rules: &[ReviewFileRule],
) -> Vec<ReviewOperation> {
    if rules.is_empty() {
        return operations;
    }
    for operation in &mut operations {
        for rule in rules {
            if !policy_pattern_matches(&rule.pattern, &operation.path) {
                continue;
            }
            operation.review_visibility = rule.visibility;
            if let Some(default_selected) = rule.default_selected {
                operation.default_selected = Some(default_selected);
            }
        }
    }
    operations
}

fn write_review_ui_session(
    run: &ReviewRun<'_>,
    session: &ReviewSession,
    exit_status: Option<i32>,
) -> Result<()> {
    let review_dir = runtime_review_dir(session);
    fs::create_dir_all(&review_dir)
        .with_context(|| format!("failed to create {}", review_dir.display()))?;
    let mut targets = vec![ReviewUiTarget {
        id: "project".into(),
        label: format!("project {}", run.project.root.display()),
        kind: ReviewUiTargetKind::Project,
        baseline_root: run.project.root.join(".condom/review/baseline"),
        current_root: run.project.root.clone(),
        apply_root: run.project.root.join(".condom/review/baseline"),
        upper_dir: run.project.root.join(".condom/review/upper"),
        selected_by_default: true,
    }];
    for (index, overlay) in run.ephemeral_overlays.iter().enumerate() {
        let source = fs::canonicalize(&overlay.source).with_context(|| {
            format!(
                "failed to resolve ephemeral overlay source {}",
                overlay.source.display()
            )
        })?;
        let destination =
            capture::ephemeral_overlay_absolute_destination(&run.project.root, overlay)?;
        let overlay_root = run
            .project
            .root
            .join(".condom/review/overlays")
            .join(index.to_string());
        targets.push(ReviewUiTarget {
            id: format!("overlay-{index}"),
            label: format!(
                "overlay {index} {} -> {}",
                source.display(),
                destination.display()
            ),
            kind: ReviewUiTargetKind::Ephemeral {
                overlay_index: index,
            },
            baseline_root: overlay_root.join("baseline"),
            current_root: destination,
            apply_root: overlay_root.join("baseline"),
            upper_dir: overlay_root.join("upper"),
            selected_by_default: true,
        });
    }
    let session_view = ReviewUiSession {
        schema_version: REVIEW_UI_SESSION_VERSION,
        id: session.id,
        mode: run.mode,
        command: run.command.to_vec(),
        exit_status,
        file_rules: run.config.review.file_rules.clone(),
        targets,
    };
    let path = runtime_review_session_path(session);
    write_bytes_atomic(&path, &serde_json::to_vec_pretty(&session_view)?)
}

pub(super) fn read_review_decision(session: &ReviewSession) -> Result<Option<ReviewDecision>> {
    let path = runtime_review_decision_path(session);
    match fs::read(&path) {
        Ok(bytes) => {
            let decision: ReviewDecision = serde_json::from_slice(&bytes)
                .with_context(|| format!("failed to parse {}", path.display()))?;
            if decision.schema_version != REVIEW_UI_SESSION_VERSION {
                bail!(
                    "unsupported review decision schema {}; expected {}",
                    decision.schema_version,
                    REVIEW_UI_SESSION_VERSION
                );
            }
            Ok(Some(decision))
        }
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(error).with_context(|| format!("failed to read {}", path.display())),
    }
}

fn review_selection_from_file_keys(
    targets: &[ReviewTarget],
    keys: &[ReviewFileKey],
) -> ReviewSelection {
    let selected_keys = keys.iter().cloned().collect::<BTreeSet<_>>();
    let mut selection = ReviewSelection::default();
    for (target_index, target) in targets.iter().enumerate() {
        for (operation_index, operation) in target.operations.iter().enumerate() {
            if selected_keys.contains(&ReviewFileKey {
                target_id: target.id.clone(),
                path: operation.path.clone(),
            }) {
                selection.selected.insert((target_index, operation_index));
            }
        }
    }
    selection
}

fn selected_operations(
    targets: &[ReviewTarget],
    selection: &ReviewSelection,
) -> Vec<ReviewOperation> {
    selection
        .selected
        .iter()
        .filter_map(|(target_index, operation_index)| {
            targets
                .get(*target_index)
                .and_then(|target| target.operations.get(*operation_index))
                .cloned()
        })
        .collect()
}

fn print_review_targets_summary(
    targets: &[ReviewTarget],
    command: &[String],
    exit_status: Option<i32>,
) {
    let operations = targets
        .iter()
        .flat_map(|target| target.operations.iter())
        .cloned()
        .collect::<Vec<_>>();
    println!("exit status: {}", review_exit_status_label(exit_status));
    println!("command: {}", review_command_label(command));
    println!("captured changes: {}", operations.len());
    println!("operation counts:");
    for (kind, count) in operation_counts(&operations) {
        println!("- {}: {count}", review_kind_label(&kind));
    }
    println!("review targets:");
    for (index, target) in targets.iter().enumerate() {
        if target.operations.is_empty() {
            continue;
        }
        println!(
            "- [{}] {}: {} changed files{}",
            index,
            target.label,
            target.operations.len(),
            if target.selected_by_default {
                " (selected by default)"
            } else {
                ""
            }
        );
    }
    println!("apply plan:");
    for target in targets {
        for operation in &target.operations {
            println!(
                "- {} {}: {}",
                target.id,
                review_kind_label(&operation.kind),
                json_string(&operation.path)
            );
        }
    }
    print_risk_flags(&risk_flags(&operations));
}

pub fn run_review_ui_command(mode: &str, session_path: &Path) -> Result<i32> {
    let mode = match mode {
        "review" => ReviewUiMode::Review,
        "final" => ReviewUiMode::Final,
        _ => bail!("unknown review UI mode `{mode}`"),
    };
    let session_view = read_review_ui_session(session_path)?;
    let targets = build_review_targets_from_ui_session(&session_view)?;
    let review_dir = session_path
        .parent()
        .ok_or_else(|| anyhow::anyhow!("review session path has no parent"))?;
    let selection_path = review_dir.join("selection.json");
    let decision_path = review_dir.join("decision.json");

    if review_targets_are_empty(&targets) {
        if mode == ReviewUiMode::Final {
            write_review_decision(&decision_path, ReviewDecisionAction::Discard, Vec::new())?;
        }
        println!("no captured changes");
        return Ok(0);
    }

    if !stdio_is_tty() {
        if mode == ReviewUiMode::Final {
            write_review_decision(&decision_path, ReviewDecisionAction::Discard, Vec::new())?;
        }
        println!("no interactive terminal available; discarding captured changes");
        return Ok(0);
    }

    let persisted = read_persisted_review_selection(&selection_path)?;
    let mut state = ReviewTreeState::new(&targets, persisted);
    let outcome =
        run_review_tree_ui(&targets, &session_view, mode, &mut state).unwrap_or_else(|error| {
            eprintln!("condom: review UI failed: {error:#}; returning to shell");
            ReviewUiOutcome::Shell
        });
    write_persisted_review_selection(&selection_path, &state)?;

    match (mode, outcome) {
        (ReviewUiMode::Review, ReviewUiOutcome::Interrupted) => Ok(0),
        (ReviewUiMode::Final, ReviewUiOutcome::Interrupted) => Ok(REVIEW_UI_BACK_TO_SHELL_EXIT),
        (ReviewUiMode::Final, ReviewUiOutcome::Apply) => {
            write_review_decision(
                &decision_path,
                ReviewDecisionAction::Apply,
                state.selected_file_keys(),
            )?;
            Ok(0)
        }
        (ReviewUiMode::Final, ReviewUiOutcome::Discard) => {
            write_review_decision(&decision_path, ReviewDecisionAction::Discard, Vec::new())?;
            Ok(0)
        }
        (ReviewUiMode::Final, ReviewUiOutcome::BackToShell | ReviewUiOutcome::Shell) => {
            Ok(REVIEW_UI_BACK_TO_SHELL_EXIT)
        }
        _ => Ok(0),
    }
}

fn read_review_ui_session(path: &Path) -> Result<ReviewUiSession> {
    let bytes = fs::read(path).with_context(|| format!("failed to read {}", path.display()))?;
    let session: ReviewUiSession = serde_json::from_slice(&bytes)
        .with_context(|| format!("failed to parse {}", path.display()))?;
    if session.schema_version != REVIEW_UI_SESSION_VERSION {
        bail!(
            "unsupported review session schema {}; expected {}",
            session.schema_version,
            REVIEW_UI_SESSION_VERSION
        );
    }
    Ok(session)
}

fn build_review_targets_from_ui_session(session: &ReviewUiSession) -> Result<Vec<ReviewTarget>> {
    let mut targets = Vec::new();
    for target in &session.targets {
        let baseline = collect_entries(
            &target.baseline_root,
            &default_excludes(&target.baseline_root),
        )?;
        let operations = review_operations_with_file_rules(
            diff_entries_from_upper_changes(
                &baseline,
                &target.upper_dir,
                &target.current_root,
                &default_excludes(&target.current_root),
            )?,
            &session.file_rules,
        );
        targets.push(ReviewTarget {
            id: target.id.clone(),
            label: target.label.clone(),
            kind: match target.kind {
                ReviewUiTargetKind::Project => ReviewTargetKind::Project,
                ReviewUiTargetKind::Ephemeral { overlay_index } => {
                    ReviewTargetKind::Ephemeral { overlay_index }
                }
            },
            baseline_root: target.baseline_root.clone(),
            current_root: target.current_root.clone(),
            apply_root: target.apply_root.clone(),
            operations,
            selected_by_default: target.selected_by_default,
        });
    }
    Ok(targets)
}

pub(super) fn read_persisted_review_selection(
    path: &Path,
) -> Result<Option<PersistedReviewSelection>> {
    match fs::read(path) {
        Ok(bytes) => {
            let selection: PersistedReviewSelection = serde_json::from_slice(&bytes)
                .with_context(|| format!("failed to parse {}", path.display()))?;
            if selection.schema_version != REVIEW_UI_SESSION_VERSION {
                return Ok(None);
            }
            Ok(Some(selection))
        }
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(error).with_context(|| format!("failed to read {}", path.display())),
    }
}

fn write_persisted_review_selection(path: &Path, state: &ReviewTreeState) -> Result<()> {
    let selection = PersistedReviewSelection {
        schema_version: REVIEW_UI_SESSION_VERSION,
        selected: state.selected_file_keys(),
        known: state.known_file_keys(),
    };
    write_bytes_atomic(path, &serde_json::to_vec_pretty(&selection)?)
}

fn write_review_decision(
    path: &Path,
    action: ReviewDecisionAction,
    selected: Vec<ReviewFileKey>,
) -> Result<()> {
    let decision = ReviewDecision {
        schema_version: REVIEW_UI_SESSION_VERSION,
        action,
        selected,
    };
    write_bytes_atomic(path, &serde_json::to_vec_pretty(&decision)?)
}

impl ReviewTreeState {
    pub(super) fn new(
        targets: &[ReviewTarget],
        persisted: Option<PersistedReviewSelection>,
    ) -> Self {
        let persisted_selected = persisted
            .as_ref()
            .map(|selection| selection.selected.iter().cloned().collect::<BTreeSet<_>>())
            .unwrap_or_default();
        let persisted_known = persisted
            .as_ref()
            .map(|selection| selection.known.iter().cloned().collect::<BTreeSet<_>>())
            .unwrap_or_default();
        let mut selected = BTreeSet::new();
        let mut known = BTreeSet::new();
        let mut expanded = BTreeSet::new();
        for target in targets {
            if target.operations.is_empty() {
                continue;
            }
            expanded.insert(target_expand_key(target));
            for operation in &target.operations {
                let key = operation_file_key(target, operation);
                if persisted_known.contains(&key) {
                    if persisted_selected.contains(&key) {
                        selected.insert(key.clone());
                    }
                } else if operation
                    .default_selected
                    .unwrap_or(target.selected_by_default)
                {
                    selected.insert(key.clone());
                }
                known.insert(key);
            }
        }
        let mut state = Self {
            rows: Vec::new(),
            cursor: 0,
            preview_scroll: 0,
            expanded,
            selected,
            known,
            screen: ReviewTreeScreen::Browse,
            diff_cache: BTreeMap::new(),
        };
        state.refresh_rows(targets);
        state
    }

    pub(super) fn refresh_rows(&mut self, targets: &[ReviewTarget]) {
        self.rows = build_review_tree_rows(targets, &self.expanded);
        if self.cursor >= self.rows.len() {
            self.cursor = self.rows.len().saturating_sub(1);
        }
    }

    pub(super) fn move_next(&mut self) {
        if self.rows.is_empty() {
            return;
        }
        let next_cursor = (self.cursor + 1).min(self.rows.len() - 1);
        if next_cursor != self.cursor {
            self.preview_scroll = 0;
            self.cursor = next_cursor;
        }
    }

    pub(super) fn move_previous(&mut self) {
        let next_cursor = self.cursor.saturating_sub(1);
        if next_cursor != self.cursor {
            self.preview_scroll = 0;
            self.cursor = next_cursor;
        }
    }

    pub(super) fn current_row(&self) -> Option<&ReviewTreeRow> {
        self.rows.get(self.cursor)
    }

    pub(super) fn current_operation(&self) -> Option<(usize, usize)> {
        match self.current_row()? {
            ReviewTreeRow::Operation {
                target_index,
                operation_index,
                ..
            } => Some((*target_index, *operation_index)),
            _ => None,
        }
    }

    pub(super) fn enter_current(&mut self, targets: &[ReviewTarget]) {
        if let Some((target_index, operation_index)) = self.current_operation() {
            self.screen = ReviewTreeScreen::Diff {
                target_index,
                operation_index,
                scroll: 0,
            };
            return;
        }
        self.toggle_expanded(targets);
    }

    pub(super) fn toggle_expanded(&mut self, targets: &[ReviewTarget]) {
        let Some(key) = self.current_expand_key(targets) else {
            return;
        };
        if !self.expanded.remove(&key) {
            self.expanded.insert(key);
        }
        self.refresh_rows(targets);
    }

    pub(super) fn collapse_current_or_parent(&mut self, targets: &[ReviewTarget]) {
        let Some(focus) = self.collapse_focus(targets) else {
            return;
        };
        self.refresh_rows(targets);
        self.focus_row(focus);
    }

    pub(super) fn collapse_focus(&mut self, targets: &[ReviewTarget]) -> Option<ReviewTreeFocus> {
        match self.current_row()?.clone() {
            ReviewTreeRow::Target { target_index } => {
                let target = targets.get(target_index)?;
                self.expanded.remove(&target_expand_key(target));
                Some(ReviewTreeFocus::Target { target_index })
            }
            ReviewTreeRow::Directory {
                target_index, path, ..
            } => {
                let target = targets.get(target_index)?;
                let key = dir_expand_key(target, &path);
                if self.expanded.remove(&key) {
                    return Some(ReviewTreeFocus::Directory { target_index, path });
                }
                if let Some(parent) = parent_directory_path(&path) {
                    self.expanded.remove(&dir_expand_key(target, &parent));
                    Some(ReviewTreeFocus::Directory {
                        target_index,
                        path: parent,
                    })
                } else {
                    self.expanded.remove(&target_expand_key(target));
                    Some(ReviewTreeFocus::Target { target_index })
                }
            }
            ReviewTreeRow::Operation {
                target_index,
                operation_index,
                ..
            } => {
                let target = targets.get(target_index)?;
                let operation = target.operations.get(operation_index)?;
                if let Some(parent) = parent_directory_path(&operation.path) {
                    self.expanded.remove(&dir_expand_key(target, &parent));
                    Some(ReviewTreeFocus::Directory {
                        target_index,
                        path: parent,
                    })
                } else {
                    Some(ReviewTreeFocus::Target { target_index })
                }
            }
        }
    }

    pub(super) fn focus_row(&mut self, focus: ReviewTreeFocus) {
        let next_cursor = self.rows.iter().position(|row| match (&focus, row) {
            (
                ReviewTreeFocus::Target { target_index },
                ReviewTreeRow::Target {
                    target_index: row_target,
                },
            ) => target_index == row_target,
            (
                ReviewTreeFocus::Directory { target_index, path },
                ReviewTreeRow::Directory {
                    target_index: row_target,
                    path: row_path,
                    ..
                },
            ) => target_index == row_target && path == row_path,
            (
                ReviewTreeFocus::Operation {
                    target_index,
                    operation_index,
                },
                ReviewTreeRow::Operation {
                    target_index: row_target,
                    operation_index: row_operation,
                    ..
                },
            ) => target_index == row_target && operation_index == row_operation,
            _ => false,
        });
        if let Some(cursor) = next_cursor {
            if cursor != self.cursor {
                self.preview_scroll = 0;
            }
            self.cursor = cursor;
        } else if self.cursor >= self.rows.len() {
            self.cursor = self.rows.len().saturating_sub(1);
            self.preview_scroll = 0;
        }
    }

    pub(super) fn scroll_preview_down(&mut self, amount: usize) {
        self.preview_scroll = self.preview_scroll.saturating_add(amount);
    }

    pub(super) fn scroll_preview_up(&mut self, amount: usize) {
        self.preview_scroll = self.preview_scroll.saturating_sub(amount);
    }

    pub(super) fn current_expand_key(&self, targets: &[ReviewTarget]) -> Option<String> {
        match self.current_row()? {
            ReviewTreeRow::Target { target_index } => {
                targets.get(*target_index).map(target_expand_key)
            }
            ReviewTreeRow::Directory {
                target_index, path, ..
            } => targets
                .get(*target_index)
                .map(|target| dir_expand_key(target, path)),
            ReviewTreeRow::Operation { .. } => None,
        }
    }

    pub(super) fn select_operation(
        &mut self,
        targets: &[ReviewTarget],
        target_index: usize,
        operation_index: usize,
    ) {
        let Some(target) = targets.get(target_index) else {
            return;
        };
        let Some(operation) = target.operations.get(operation_index) else {
            return;
        };
        self.selected.insert(operation_file_key(target, operation));
    }

    pub(super) fn move_to_adjacent_operation(
        &mut self,
        targets: &[ReviewTarget],
        target_index: usize,
        operation_index: usize,
        direction: ReviewOperationDirection,
    ) -> bool {
        let operations = targets
            .iter()
            .enumerate()
            .flat_map(|(target_index, target)| {
                (0..target.operations.len())
                    .map(move |operation_index| (target_index, operation_index))
            })
            .collect::<Vec<_>>();
        let Some(position) = operations.iter().position(|(row_target, row_operation)| {
            *row_target == target_index && *row_operation == operation_index
        }) else {
            return false;
        };
        let next_position = match direction {
            ReviewOperationDirection::Previous => position.checked_sub(1),
            ReviewOperationDirection::Next => {
                (position + 1 < operations.len()).then_some(position + 1)
            }
        };
        let Some(next_position) = next_position else {
            return false;
        };
        let (target_index, operation_index) = operations[next_position];
        self.expand_operation_path(targets, target_index, operation_index);
        self.focus_row(ReviewTreeFocus::Operation {
            target_index,
            operation_index,
        });
        self.screen = ReviewTreeScreen::Diff {
            target_index,
            operation_index,
            scroll: 0,
        };
        true
    }

    pub(super) fn expand_operation_path(
        &mut self,
        targets: &[ReviewTarget],
        target_index: usize,
        operation_index: usize,
    ) {
        let Some(target) = targets.get(target_index) else {
            return;
        };
        let Some(operation) = target.operations.get(operation_index) else {
            return;
        };
        self.expanded.insert(target_expand_key(target));
        for parent in directory_ancestors(&operation.path) {
            self.expanded.insert(dir_expand_key(target, &parent));
        }
        self.refresh_rows(targets);
    }

    pub(super) fn keep_diff_file_and_advance(
        &mut self,
        targets: &[ReviewTarget],
        target_index: usize,
        operation_index: usize,
    ) {
        self.select_operation(targets, target_index, operation_index);
        self.move_to_adjacent_operation(
            targets,
            target_index,
            operation_index,
            ReviewOperationDirection::Next,
        );
    }

    pub(super) fn toggle_current_selection(&mut self, targets: &[ReviewTarget]) {
        let keys = match self.current_row() {
            Some(ReviewTreeRow::Target { target_index }) => {
                operation_keys_for_target(targets, *target_index)
            }
            Some(ReviewTreeRow::Directory {
                target_index, path, ..
            }) => operation_keys_for_prefix(targets, *target_index, path),
            Some(ReviewTreeRow::Operation {
                target_index,
                operation_index,
                ..
            }) => targets
                .get(*target_index)
                .and_then(|target| {
                    target
                        .operations
                        .get(*operation_index)
                        .map(|operation| vec![operation_file_key(target, operation)])
                })
                .unwrap_or_default(),
            None => Vec::new(),
        };
        if keys.is_empty() {
            return;
        }
        let all_selected = keys.iter().all(|key| self.selected.contains(key));
        for key in keys {
            if all_selected {
                self.selected.remove(&key);
            } else {
                self.selected.insert(key);
            }
        }
    }

    pub(super) fn select_all(&mut self, targets: &[ReviewTarget]) {
        self.selected = targets
            .iter()
            .flat_map(|target| {
                target
                    .operations
                    .iter()
                    .map(|operation| operation_file_key(target, operation))
            })
            .collect();
    }

    pub(super) fn select_none(&mut self) {
        self.selected.clear();
    }

    pub(super) fn selected_file_keys(&self) -> Vec<ReviewFileKey> {
        self.selected.iter().cloned().collect()
    }

    pub(super) fn known_file_keys(&self) -> Vec<ReviewFileKey> {
        self.known.iter().cloned().collect()
    }

    pub(super) fn diff_lines(
        &mut self,
        targets: &[ReviewTarget],
        target_index: usize,
        operation_index: usize,
    ) -> Vec<Line<'static>> {
        let key = ReviewDiffCacheKey {
            target_index,
            operation_index,
        };
        self.diff_cache
            .entry(key)
            .or_insert_with(|| render_operation_diff_lines(targets, target_index, operation_index));
        self.diff_cache
            .get(&key)
            .cloned()
            .unwrap_or_else(|| vec![Line::from("unknown operation")])
    }

    pub(super) fn diff_preview_lines(
        &mut self,
        targets: &[ReviewTarget],
        target_index: usize,
        operation_index: usize,
        max_lines: usize,
    ) -> Vec<Line<'static>> {
        let mut lines = self.diff_lines(targets, target_index, operation_index);
        if lines.len() > max_lines {
            lines.truncate(max_lines);
            lines.push(Line::from(Span::styled(
                "…",
                Style::default().fg(Color::DarkGray),
            )));
        }
        lines
    }

    pub(super) fn diff_text(
        &mut self,
        targets: &[ReviewTarget],
        target_index: usize,
        operation_index: usize,
    ) -> Text<'static> {
        Text::from(self.diff_lines(targets, target_index, operation_index))
    }
}

pub(super) fn upper_changed_paths(upper_dir: &Path) -> Result<Vec<String>> {
    if !upper_dir.is_dir() {
        return Ok(Vec::new());
    }
    let mut paths = BTreeSet::new();
    collect_upper_changed_paths(upper_dir, upper_dir, &mut paths)?;
    Ok(paths.into_iter().collect())
}

fn collect_upper_changed_paths(
    root: &Path,
    current: &Path,
    paths: &mut BTreeSet<String>,
) -> Result<()> {
    for entry in
        fs::read_dir(current).with_context(|| format!("failed to read {}", current.display()))?
    {
        let entry = entry?;
        let path = entry.path();
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
        if is_overlay_whiteout(&metadata) {
            paths.insert(relative);
        } else if metadata.is_dir() {
            collect_upper_changed_paths(root, &path, paths)?;
        } else {
            paths.insert(relative);
        }
    }
    Ok(())
}

fn is_overlay_whiteout(metadata: &fs::Metadata) -> bool {
    metadata.file_type().is_char_device() && metadata.rdev() == 0
}

pub(super) fn operation(
    kind: ReviewOpKind,
    path: String,
    before: Option<&FileEntry>,
    after: Option<&FileEntry>,
) -> ReviewOperation {
    ReviewOperation {
        kind,
        path,
        target: after.and_then(|entry| entry.target.clone()),
        baseline_hash: before.map(|entry| entry.hash.clone()),
        captured_hash: after.map(|entry| entry.hash.clone()),
        baseline_kind: before.map(|entry| ReviewEntryKind::from(&entry.kind)),
        captured_kind: after.map(|entry| ReviewEntryKind::from(&entry.kind)),
        review_visibility: ReviewFileVisibility::Normal,
        default_selected: None,
    }
}

pub(super) fn apply_review_selection_with_event(
    context: ReviewEventContext<'_>,
    session: &ReviewSession,
    targets: &[ReviewTarget],
    selection: &ReviewSelection,
    journal: &mut ReviewJournal,
) -> Result<()> {
    if let Err(error) = apply_review_selection(session, targets, selection, journal) {
        context.event_log.append(&review_event(
            context.project,
            context.mode,
            context.command,
            session,
            Decision::Failed,
            &format!("review apply failed: {error:#}"),
        ))?;
        return Err(error);
    }
    context.event_log.append(&review_event(
        context.project,
        context.mode,
        context.command,
        session,
        Decision::Accepted,
        "review changes accepted",
    ))?;
    Ok(())
}

pub(super) fn apply_review_selection(
    session: &ReviewSession,
    targets: &[ReviewTarget],
    selection: &ReviewSelection,
    journal: &mut ReviewJournal,
) -> Result<()> {
    let conflicts = selected_conflicts(targets, selection)?;
    if !conflicts.is_empty() {
        bail!("review apply conflict for: {}", conflicts.join(", "));
    }

    let backup_dir = session.session_dir.join("backup");
    let mut applied = Vec::new();
    let result: Result<()> = (|| {
        for (target_index, operation_index) in &selection.selected {
            let target = targets
                .get(*target_index)
                .ok_or_else(|| anyhow::anyhow!("unknown review target {target_index}"))?;
            let operation = target.operations.get(*operation_index).ok_or_else(|| {
                anyhow::anyhow!(
                    "unknown review operation {operation_index} for target {}",
                    target.id
                )
            })?;
            backup_target_path(&backup_dir, *target_index, target, operation)?;
            applied.push((*target_index, operation.path.clone()));
            apply_target_operation(target, operation)?;
        }
        Ok(())
    })();
    if let Err(error) = result {
        if let Err(rollback_error) = rollback_targets(&backup_dir, targets, &applied) {
            return Err(error.context(format!("{rollback_error}")));
        }
        return Err(error);
    }
    journal.accepted = true;
    Ok(())
}

fn selected_conflicts(
    targets: &[ReviewTarget],
    selection: &ReviewSelection,
) -> Result<Vec<String>> {
    let mut conflicts = Vec::new();
    for (target_index, operation_index) in &selection.selected {
        let Some(target) = targets.get(*target_index) else {
            conflicts.push(format!("unknown-target-{target_index}"));
            continue;
        };
        let Some(operation) = target.operations.get(*operation_index) else {
            conflicts.push(format!("{}:<unknown-{operation_index}>", target.id));
            continue;
        };
        let live = file_entry_at(&target.apply_root.join(&operation.path))?;
        if operation_conflicts_with_entry(operation, live.as_ref()) {
            conflicts.push(format!("{}:{}", target.id, operation.path));
        }
    }
    Ok(conflicts)
}

pub(super) fn operation_conflicts_with_entry(
    operation: &ReviewOperation,
    live: Option<&FileEntry>,
) -> bool {
    match operation.kind {
        ReviewOpKind::Create | ReviewOpKind::Symlink if operation.baseline_hash.is_none() => {
            live.is_some()
        }
        ReviewOpKind::Modify | ReviewOpKind::Delete | ReviewOpKind::Symlink => {
            !operation_baseline_matches(operation, live)
        }
        ReviewOpKind::Rename | ReviewOpKind::Metadata => true,
        ReviewOpKind::Create => live.is_some(),
    }
}

fn operation_baseline_matches(operation: &ReviewOperation, live: Option<&FileEntry>) -> bool {
    match (operation.baseline_hash.as_ref(), live) {
        (None, None) => true,
        (None, Some(_)) | (Some(_), None) => false,
        (Some(expected_hash), Some(live)) => {
            if &live.hash != expected_hash {
                return false;
            }
            operation
                .baseline_kind
                .as_ref()
                .map(|expected_kind| *expected_kind == ReviewEntryKind::from(&live.kind))
                .unwrap_or(true)
        }
    }
}

fn path_lexically_exists(path: &Path) -> bool {
    fs::symlink_metadata(path).is_ok()
}

fn backup_target_path(
    backup_dir: &Path,
    target_index: usize,
    target: &ReviewTarget,
    operation: &ReviewOperation,
) -> Result<()> {
    let live_path = target.apply_root.join(&operation.path);
    if !path_lexically_exists(&live_path) {
        return Ok(());
    }
    let backup_path = backup_dir
        .join(target_index.to_string())
        .join(&operation.path);
    if let Some(parent) = backup_path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }
    copy_entry(&live_path, &backup_path)
}

fn apply_target_operation(target: &ReviewTarget, operation: &ReviewOperation) -> Result<()> {
    let live_path = target.apply_root.join(&operation.path);
    match operation.kind {
        ReviewOpKind::Delete => remove_path(&live_path),
        ReviewOpKind::Create | ReviewOpKind::Modify | ReviewOpKind::Symlink => {
            let captured_path = target.current_root.join(&operation.path);
            if let Some(parent) = live_path.parent() {
                fs::create_dir_all(parent)
                    .with_context(|| format!("failed to create {}", parent.display()))?;
            }
            if path_lexically_exists(&live_path) {
                remove_path(&live_path)?;
            }
            copy_entry(&captured_path, &live_path)
        }
        ReviewOpKind::Rename | ReviewOpKind::Metadata => {
            bail!(
                "operation {:?} is recorded but not applyable yet",
                operation.kind
            )
        }
    }
}

fn rollback_targets(
    backup_dir: &Path,
    targets: &[ReviewTarget],
    applied: &[(usize, String)],
) -> Result<()> {
    let mut failures = Vec::new();
    for (target_index, path) in applied.iter().rev() {
        let Some(target) = targets.get(*target_index) else {
            continue;
        };
        let live_path = target.apply_root.join(path);
        let backup_path = backup_dir.join(target_index.to_string()).join(path);
        let restore = (|| -> Result<()> {
            if path_lexically_exists(&backup_path) {
                if path_lexically_exists(&live_path) {
                    remove_path(&live_path)?;
                }
                copy_entry(&backup_path, &live_path)?;
            } else if path_lexically_exists(&live_path) {
                remove_path(&live_path)?;
            }
            Ok(())
        })();
        if let Err(error) = restore {
            failures.push(format!("{}: {error:#}", live_path.display()));
        }
    }
    if failures.is_empty() {
        Ok(())
    } else {
        bail!(
            "rollback incomplete after review apply failure; project tree may be partially modified ({})",
            failures.join("; ")
        )
    }
}

fn operation_conflicts(
    operation: &ReviewOperation,
    live_hashes: &BTreeMap<String, String>,
) -> bool {
    match operation.kind {
        ReviewOpKind::Create | ReviewOpKind::Symlink if operation.baseline_hash.is_none() => {
            live_hashes.contains_key(&operation.path)
        }
        ReviewOpKind::Modify | ReviewOpKind::Delete | ReviewOpKind::Symlink => live_hashes
            .get(&operation.path)
            .map(|hash| Some(hash) != operation.baseline_hash.as_ref())
            .unwrap_or(operation.baseline_hash.is_some()),
        ReviewOpKind::Rename | ReviewOpKind::Metadata => true,
        ReviewOpKind::Create => live_hashes.contains_key(&operation.path),
    }
}

fn remove_path(path: &Path) -> Result<()> {
    if !path.exists() && fs::symlink_metadata(path).is_err() {
        return Ok(());
    }
    let metadata = fs::symlink_metadata(path)
        .with_context(|| format!("failed to inspect {}", path.display()))?;
    if metadata.is_dir() && !metadata.file_type().is_symlink() {
        fs::remove_dir_all(path).with_context(|| format!("failed to remove {}", path.display()))
    } else {
        fs::remove_file(path).with_context(|| format!("failed to remove {}", path.display()))
    }
}

fn review_event(
    project: &ProjectContext,
    mode: ExecutionMode,
    command: &[String],
    session: &ReviewSession,
    decision: Decision,
    reason: &str,
) -> Event {
    Event {
        schema_version: EVENT_SCHEMA_VERSION,
        timestamp: Utc::now(),
        event_type: EventType::ReviewApply,
        project_id: project.id.clone(),
        project_root: project.root.display().to_string(),
        mode,
        command: redact_command(command),
        subject: session.id.to_string(),
        decision,
        decision_source: DecisionSource::Runtime,
        suggested_allow: None,
        reason: crate::model::events::redact_reason(reason),
    }
}

pub(super) fn risk_flags(operations: &[ReviewOperation]) -> Vec<String> {
    let mut flags = BTreeSet::new();
    for operation in operations {
        let path = operation.path.as_str();
        if path == ".env" || path.starts_with(".env.") {
            flags.insert("environment file changed".to_string());
        }
        if path.starts_with(".ci/") {
            flags.insert("workflow/config changed".to_string());
        }
        if path.starts_with(".git/hooks/") {
            flags.insert("git hook changed".to_string());
        }
        if path.starts_with(".agent/") || path.starts_with(".agents/") {
            flags.insert("agent config changed".to_string());
        }
        if matches!(operation.kind, ReviewOpKind::Symlink) {
            flags.insert("symlink changed".to_string());
        }
    }
    flags.into_iter().collect()
}

pub(super) fn hash_file(path: &Path) -> Result<String> {
    let mut file =
        fs::File::open(path).with_context(|| format!("failed to open {}", path.display()))?;
    let mut hasher = Sha256::new();
    let mut buffer = [0; 8192];
    loop {
        let read = file
            .read(&mut buffer)
            .with_context(|| format!("failed to read {}", path.display()))?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

pub(super) fn hash_bytes(bytes: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    format!("{:x}", hasher.finalize())
}
