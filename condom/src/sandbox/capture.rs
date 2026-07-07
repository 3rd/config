use std::collections::BTreeMap;
use std::fs;
use std::path::{Component, Path, PathBuf};
use std::process::Command;

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};

use crate::app::env::{current_environment, sanitized_environment};
use crate::kernel::seccomp;
use crate::model::config::{CondomConfig, ExecutionMode};
use crate::model::events::{
    Decision, DecisionSource, Event, EventLog, EventType, EVENT_SCHEMA_VERSION,
};
use crate::model::policy::PolicySnapshot;
use crate::model::project::ProjectContext;
use crate::model::state::StatePaths;
use crate::sandbox::landlock;

pub const FUSE_OVERLAYFS_ENV: &str = "CONDOM_FUSE_OVERLAYFS";

pub struct OverlayCaptureMount<'a> {
    pub lower_dir: &'a Path,
    pub upper_dir: &'a Path,
    pub work_dir: &'a Path,
    pub merged_dir: &'a Path,
    pub fuse_overlayfs: &'a Path,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EphemeralOverlay {
    pub source: PathBuf,
    pub destination: PathBuf,
}

#[derive(Debug)]
pub struct MountedOverlayCapture {
    merged_dir: PathBuf,
    mounted: bool,
}

#[derive(Debug, Default)]
pub struct MountedEphemeralOverlays {
    mounts: Vec<MountedOverlayCapture>,
}

pub struct BindCaptureRun<'a> {
    pub project: &'a ProjectContext,
    pub state: &'a StatePaths,
    pub session_dir: &'a Path,
    pub workspace_dir: &'a Path,
    pub config: &'a CondomConfig,
    pub mode: ExecutionMode,
    pub command: &'a [String],
    pub extra_env: &'a BTreeMap<String, String>,
    pub event_log: &'a EventLog,
    pub policy_snapshot: &'a PolicySnapshot,
    pub runner_path: Option<&'a Path>,
    pub runtime_path: Option<&'a str>,
    pub ephemeral_overlays: &'a [EphemeralOverlay],
    pub mediate_filesystem: bool,
    pub review_inspection: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum CaptureProbe {
    Ready { path: PathBuf },
    MissingFuseDevice { path: PathBuf, message: String },
    MissingTool { path: PathBuf, message: String },
    Failed { path: PathBuf, message: String },
}

pub fn probe_configured_capture_backend() -> CaptureProbe {
    probe_capture_backend(Path::new("/dev/fuse"), &configured_fuse_overlayfs_path())
}

pub fn configured_fuse_overlayfs_path() -> PathBuf {
    std::env::var_os(FUSE_OVERLAYFS_ENV)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("fuse-overlayfs"))
}

pub fn probe_capture_backend(fuse_device: &Path, fuse_overlayfs: &Path) -> CaptureProbe {
    if !fuse_device.exists() {
        return CaptureProbe::MissingFuseDevice {
            path: fuse_overlayfs.to_path_buf(),
            message: format!("{} is missing", fuse_device.display()),
        };
    }

    match Command::new(fuse_overlayfs).arg("--help").output() {
        Ok(output) if output.status.success() => CaptureProbe::Ready {
            path: fuse_overlayfs.to_path_buf(),
        },
        Ok(output) => CaptureProbe::Failed {
            path: fuse_overlayfs.to_path_buf(),
            message: format!(
                "fuse-overlayfs exited with status {}; stderr: {}",
                output.status.code().unwrap_or(1),
                String::from_utf8_lossy(&output.stderr).trim()
            ),
        },
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => CaptureProbe::MissingTool {
            path: fuse_overlayfs.to_path_buf(),
            message: format!(
                "capture backend `{}` was not found",
                fuse_overlayfs.display()
            ),
        },
        Err(error) => CaptureProbe::Failed {
            path: fuse_overlayfs.to_path_buf(),
            message: format!("failed to start capture backend: {error}"),
        },
    }
}

pub fn mount_overlay_capture(mount: OverlayCaptureMount<'_>) -> Result<MountedOverlayCapture> {
    match probe_capture_backend(Path::new("/dev/fuse"), mount.fuse_overlayfs) {
        CaptureProbe::Ready { .. } => {}
        CaptureProbe::MissingFuseDevice { message, .. }
        | CaptureProbe::MissingTool { message, .. }
        | CaptureProbe::Failed { message, .. } => bail!("{message}"),
    }

    ensure_overlay_capture_dirs(mount.upper_dir, mount.work_dir, mount.merged_dir)?;
    let options = overlay_mount_options(mount.lower_dir, mount.upper_dir, mount.work_dir)?;
    let output = Command::new(mount.fuse_overlayfs)
        .arg("-o")
        .arg(&options)
        .arg(mount.merged_dir)
        .output()
        .with_context(|| format!("failed to start {}", mount.fuse_overlayfs.display()))?;
    if !output.status.success() {
        bail!(
            "{} failed to mount review capture at {}; status {}; stderr: {}",
            mount.fuse_overlayfs.display(),
            mount.merged_dir.display(),
            output.status.code().unwrap_or(1),
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }

    Ok(MountedOverlayCapture {
        merged_dir: mount.merged_dir.to_path_buf(),
        mounted: true,
    })
}

pub fn run_with_bind_capture(run: BindCaptureRun<'_>) -> Result<i32> {
    ensure_bubblewrap()?;
    let policy_snapshot = bind_capture_policy_snapshot(
        run.project,
        run.state,
        run.policy_snapshot,
        run.ephemeral_overlays,
    )?;
    let runtime_project_dir = run.state.runtime_dir.clone();
    ensure_bind_capture_dirs(&run.project.root.join(".condom"), &runtime_project_dir)?;
    let env = bind_capture_environment(
        run.project,
        run.state,
        run.config,
        run.mode,
        run.extra_env,
        &policy_snapshot,
    );
    let sandboxed_command = if run.mediate_filesystem {
        let runtime_path = run
            .runtime_path
            .or_else(|| env.get("PATH").map(String::as_str));
        if let Some(runner_path) = run.runner_path {
            landlock::wrap_command_with_runner_path(
                runner_path,
                &policy_snapshot,
                run.command,
                runtime_path,
            )
        } else {
            landlock::wrap_command_path(&policy_snapshot, run.command, runtime_path)
        }
        .context("failed to prepare Landlock command wrapper")?
    } else {
        run.command.to_vec()
    };
    let args = bind_capture_args(BindCaptureArgs {
        project: run.project,
        session_dir: run.session_dir,
        workspace_dir: run.workspace_dir,
        allow_loopback: policy_snapshot.network.allow_loopback,
        policy_snapshot: &policy_snapshot,
        runner_path: run.runner_path,
        runtime_project_dir: &runtime_project_dir,
        state_xdg_dir: &run.state.xdg_state_dir,
        ephemeral_overlays: run.ephemeral_overlays,
        review_inspection: run.review_inspection,
        command: &sandboxed_command,
    })?;

    if run.config.events.require_logging {
        run.event_log.append(&capture_runtime_event(
            run.project,
            run.mode,
            run.command,
            Decision::Allowed,
            "starting command through bind-mounted capture namespace",
        ))?;
    }

    let mut command = Command::new("bwrap");
    command.args(args).env_clear().envs(env);
    seccomp::install_socket_filter(
        &mut command,
        seccomp::SocketFilterPolicy {
            deny_internet_udp: crate::model::policy::network_mediation_required(
                &policy_snapshot.network,
            ),
        },
    );
    let status = command
        .status()
        .context("failed to start bubblewrap capture namespace")?;
    let code = status.code().unwrap_or(1);

    if run.config.events.require_logging {
        run.event_log.append(&capture_runtime_event(
            run.project,
            run.mode,
            run.command,
            if code == 0 {
                Decision::Allowed
            } else {
                Decision::Failed
            },
            &format!("command exited with status {code}"),
        ))?;
    }

    Ok(code)
}

fn bind_capture_policy_snapshot(
    project: &ProjectContext,
    virtual_state: &StatePaths,
    policy_snapshot: &PolicySnapshot,
    ephemeral_overlays: &[EphemeralOverlay],
) -> Result<PolicySnapshot> {
    let mut snapshot = policy_snapshot.clone();
    let mut changed = false;
    if !ephemeral_overlays.is_empty() {
        let virtual_state_dir = virtual_state.xdg_state_dir.display().to_string();
        changed |= push_unique_policy_path(
            &mut snapshot.filesystem.allow_read,
            virtual_state_dir.clone(),
        );
        changed |= push_unique_policy_path(&mut snapshot.filesystem.allow_write, virtual_state_dir);
    }
    for overlay in ephemeral_overlays {
        let destination = ephemeral_overlay_absolute_destination(&project.root, overlay)?;
        let destination = destination.display().to_string();
        changed |=
            push_unique_policy_path(&mut snapshot.filesystem.allow_read, destination.clone());
        changed |= push_unique_policy_path(&mut snapshot.filesystem.allow_write, destination);
    }
    if !changed {
        return Ok(snapshot);
    }
    fs::create_dir_all(&virtual_state.policy_dir)
        .with_context(|| format!("failed to create {}", virtual_state.policy_dir.display()))?;
    snapshot.path = virtual_state
        .policy_dir
        .join(format!("{}-capture.json", snapshot.id));
    fs::write(&snapshot.path, serde_json::to_string_pretty(&snapshot)?)
        .with_context(|| format!("failed to write {}", snapshot.path.display()))?;
    Ok(snapshot)
}

fn push_unique_policy_path(paths: &mut Vec<String>, path: String) -> bool {
    if paths.contains(&path) {
        return false;
    }
    paths.push(path);
    true
}

impl MountedOverlayCapture {
    pub fn unmount(&mut self) -> Result<()> {
        if !self.mounted {
            return Ok(());
        }
        unmount_overlay_capture(&self.merged_dir)?;
        self.mounted = false;
        Ok(())
    }
}

impl MountedEphemeralOverlays {
    pub fn unmount(&mut self) -> Result<()> {
        let mut failures = Vec::new();
        for mount in self.mounts.iter_mut().rev() {
            if let Err(error) = mount.unmount() {
                failures.push(error.to_string());
            }
        }
        if !failures.is_empty() {
            bail!("{}", failures.join("; "));
        }
        Ok(())
    }
}

impl Drop for MountedOverlayCapture {
    fn drop(&mut self) {
        if self.mounted {
            let _ = unmount_overlay_capture(&self.merged_dir);
        }
    }
}

impl Drop for MountedEphemeralOverlays {
    fn drop(&mut self) {
        let _ = self.unmount();
    }
}

pub fn mount_ephemeral_overlays(
    project_root: &Path,
    session_dir: &Path,
    overlays: &[EphemeralOverlay],
    fuse_overlayfs: &Path,
) -> Result<MountedEphemeralOverlays> {
    let mut mounted = MountedEphemeralOverlays::default();
    for (index, overlay) in overlays.iter().enumerate() {
        let source = fs::canonicalize(&overlay.source).with_context(|| {
            format!(
                "failed to resolve ephemeral overlay source {}",
                overlay.source.display()
            )
        })?;
        if !source.is_dir() {
            bail!(
                "ephemeral overlay source {} must be a directory",
                overlay.source.display()
            );
        }
        ephemeral_overlay_absolute_destination(project_root, overlay)?;
        let overlay_dir = session_dir
            .join("ephemeral-overlays")
            .join(index.to_string());
        let mount = mount_overlay_capture(OverlayCaptureMount {
            lower_dir: &source,
            upper_dir: &overlay_dir.join("upper"),
            work_dir: &overlay_dir.join("work"),
            merged_dir: &ephemeral_overlay_session_mount(session_dir, index),
            fuse_overlayfs,
        })?;
        mounted.mounts.push(mount);
    }
    Ok(mounted)
}

fn ensure_bubblewrap() -> Result<()> {
    let output = Command::new("bwrap")
        .arg("--version")
        .output()
        .context("bubblewrap is required for bind-mounted review capture")?;
    if !output.status.success() {
        bail!(
            "bubblewrap is required for bind-mounted review capture; bwrap --version exited with status {}",
            output.status.code().unwrap_or(1)
        );
    }
    Ok(())
}

fn ensure_bind_capture_dirs(project_state_dir: &Path, runtime_project_dir: &Path) -> Result<()> {
    for path in [
        runtime_project_dir.to_path_buf(),
        runtime_project_dir.join("home"),
        runtime_project_dir.join("tmp"),
        runtime_project_dir.join("xdg/cache"),
        runtime_project_dir.join("xdg/config"),
        runtime_project_dir.join("xdg/data"),
        runtime_project_dir.join("xdg/state"),
    ] {
        fs::create_dir_all(&path)
            .with_context(|| format!("failed to create {}", path.display()))?;
    }
    let project_config = project_state_dir.join("config.toml");
    if project_config.is_file() {
        fs::copy(&project_config, runtime_project_dir.join("config.toml"))
            .with_context(|| format!("failed to copy {}", project_config.display()))?;
    }
    Ok(())
}

fn ensure_overlay_capture_dirs(upper_dir: &Path, work_dir: &Path, merged_dir: &Path) -> Result<()> {
    for path in [upper_dir, work_dir, merged_dir] {
        fs::create_dir_all(path).with_context(|| format!("failed to create {}", path.display()))?;
    }
    Ok(())
}

fn overlay_mount_options(lower_dir: &Path, upper_dir: &Path, work_dir: &Path) -> Result<String> {
    let uid = unsafe { libc::geteuid() };
    let gid = unsafe { libc::getegid() };
    Ok(format!(
        "lowerdir={},upperdir={},workdir={},squash_to_uid={},squash_to_gid={}",
        overlay_option_path("lowerdir", lower_dir)?,
        overlay_option_path("upperdir", upper_dir)?,
        overlay_option_path("workdir", work_dir)?,
        uid,
        gid
    ))
}

fn overlay_option_path(name: &str, path: &Path) -> Result<String> {
    let value = path.display().to_string();
    if value.contains(',') {
        bail!("{name} path {} cannot contain `,`", path.display());
    }
    if name == "lowerdir" && value.contains(':') {
        bail!("{name} path {} cannot contain `:`", path.display());
    }
    Ok(value)
}

fn unmount_overlay_capture(merged_dir: &Path) -> Result<()> {
    let mut failures = Vec::new();
    for (command, args) in [
        ("fusermount3", vec!["-u"]),
        ("fusermount", vec!["-u"]),
        ("umount", Vec::new()),
    ] {
        match Command::new(command).args(args).arg(merged_dir).output() {
            Ok(output) if output.status.success() => return Ok(()),
            Ok(output) => failures.push(format!(
                "{command} exited with status {}; stderr: {}",
                output.status.code().unwrap_or(1),
                String::from_utf8_lossy(&output.stderr).trim()
            )),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                failures.push(format!("{command} not found"));
            }
            Err(error) => failures.push(format!("{command} failed to start: {error}")),
        }
    }
    bail!(
        "failed to unmount review capture at {}: {}",
        merged_dir.display(),
        failures.join("; ")
    )
}

fn bind_capture_environment(
    project: &ProjectContext,
    virtual_state: &StatePaths,
    config: &CondomConfig,
    mode: ExecutionMode,
    extra_env: &BTreeMap<String, String>,
    policy_snapshot: &PolicySnapshot,
) -> BTreeMap<String, String> {
    let mut env = sanitized_environment(
        &current_environment(),
        mode,
        project,
        virtual_state,
        &config.environment,
    );
    env.extend(extra_env.clone());
    env.insert(
        "CONDOM_POLICY_SNAPSHOT_ID".into(),
        policy_snapshot.id.to_string(),
    );
    env.insert(
        "CONDOM_POLICY_SNAPSHOT".into(),
        policy_snapshot.path.display().to_string(),
    );
    env
}

struct BindCaptureArgs<'a> {
    project: &'a ProjectContext,
    session_dir: &'a Path,
    workspace_dir: &'a Path,
    allow_loopback: bool,
    policy_snapshot: &'a PolicySnapshot,
    runner_path: Option<&'a Path>,
    runtime_project_dir: &'a Path,
    state_xdg_dir: &'a Path,
    ephemeral_overlays: &'a [EphemeralOverlay],
    review_inspection: bool,
    command: &'a [String],
}

fn bind_capture_args(input: BindCaptureArgs<'_>) -> Result<Vec<String>> {
    let BindCaptureArgs {
        project,
        session_dir,
        workspace_dir,
        allow_loopback,
        policy_snapshot,
        runner_path,
        runtime_project_dir,
        state_xdg_dir,
        ephemeral_overlays,
        review_inspection,
        command,
    } = input;
    let mut args = vec![
        "--die-with-parent".to_string(),
        "--unshare-pid".to_string(),
        "--proc".to_string(),
        "/proc".to_string(),
        "--dev".to_string(),
        "/dev".to_string(),
        "--tmpfs".to_string(),
        "/tmp".to_string(),
    ];

    for path in destination_parent_dirs(&project.root) {
        args.push("--dir".into());
        args.push(path.display().to_string());
    }
    args.push("--bind".into());
    args.push(workspace_dir.display().to_string());
    args.push(project.root.display().to_string());
    for path in destination_parent_dirs(runtime_project_dir) {
        args.push("--dir".into());
        args.push(path.display().to_string());
    }
    args.push("--dir".into());
    args.push(runtime_project_dir.display().to_string());
    args.push("--bind".into());
    args.push(runtime_project_dir.display().to_string());
    args.push(runtime_project_dir.display().to_string());
    let project_state_dir = project.root.join(".condom");
    args.push("--dir".into());
    args.push(project_state_dir.display().to_string());
    args.push("--bind".into());
    args.push(runtime_project_dir.display().to_string());
    args.push(project_state_dir.display().to_string());
    for path in destination_parent_dirs(state_xdg_dir) {
        args.push("--dir".into());
        args.push(path.display().to_string());
    }
    args.push("--dir".into());
    args.push(state_xdg_dir.display().to_string());
    args.push("--bind".into());
    args.push(state_xdg_dir.display().to_string());
    args.push(state_xdg_dir.display().to_string());

    for path in readonly_system_paths() {
        if path.exists() {
            args.push("--ro-bind".into());
            args.push(path.display().to_string());
            args.push(path.display().to_string());
        }
    }
    for path in bind_capture_support_paths(project, policy_snapshot, runner_path) {
        if path.exists() {
            for parent in destination_parent_dirs(&path) {
                args.push("--dir".into());
                args.push(parent.display().to_string());
            }
            args.push("--ro-bind".into());
            args.push(path.display().to_string());
            args.push(path.display().to_string());
        }
    }

    for (index, overlay) in ephemeral_overlays.iter().enumerate() {
        let session_mount = ephemeral_overlay_session_mount(session_dir, index);
        let destination = ephemeral_overlay_absolute_destination(&project.root, overlay)?;
        for parent in destination_parent_dirs(&destination) {
            args.push("--dir".into());
            args.push(parent.display().to_string());
        }
        args.push("--dir".into());
        args.push(destination.display().to_string());
        args.push("--bind".into());
        args.push(session_mount.display().to_string());
        args.push(destination.display().to_string());
    }

    if review_inspection {
        add_review_inspection_binds(project, session_dir, ephemeral_overlays, &mut args)?;
    }

    if allow_loopback {
        args.push("--share-net".into());
    } else {
        args.push("--unshare-net".into());
    }
    args.push("--chdir".into());
    args.push(project.root.display().to_string());
    args.push("--".into());
    args.extend(command.iter().cloned());
    Ok(args)
}

fn add_review_inspection_binds(
    project: &ProjectContext,
    session_dir: &Path,
    ephemeral_overlays: &[EphemeralOverlay],
    args: &mut Vec<String>,
) -> Result<()> {
    let inspection_root = project.root.join(".condom/review");
    let baseline = inspection_root.join("baseline");
    bind_readonly_at(project.root.as_path(), &baseline, args);
    bind_readonly_at(
        &session_dir.join("upper"),
        &inspection_root.join("upper"),
        args,
    );
    let review_ui = std::env::current_exe().context("failed to locate condom executable")?;
    bind_file_readonly_at(
        &review_ui,
        &inspection_root.join("bin/condom-review-ui"),
        args,
    );

    for (index, overlay) in ephemeral_overlays.iter().enumerate() {
        let source = fs::canonicalize(&overlay.source).with_context(|| {
            format!(
                "failed to resolve ephemeral overlay source {}",
                overlay.source.display()
            )
        })?;
        bind_readonly_at(
            &source,
            &inspection_root
                .join("overlays")
                .join(index.to_string())
                .join("baseline"),
            args,
        );
        bind_readonly_at(
            &ephemeral_overlay_session_upper_dir(session_dir, index),
            &inspection_root
                .join("overlays")
                .join(index.to_string())
                .join("upper"),
            args,
        );
    }

    Ok(())
}

fn bind_readonly_at(source: &Path, destination: &Path, args: &mut Vec<String>) {
    for parent in destination_parent_dirs(destination) {
        args.push("--dir".into());
        args.push(parent.display().to_string());
    }
    args.push("--dir".into());
    args.push(destination.display().to_string());
    args.push("--ro-bind".into());
    args.push(source.display().to_string());
    args.push(destination.display().to_string());
}

fn bind_file_readonly_at(source: &Path, destination: &Path, args: &mut Vec<String>) {
    if let Some(parent) = destination.parent() {
        for path in destination_parent_dirs(parent) {
            args.push("--dir".into());
            args.push(path.display().to_string());
        }
        args.push("--dir".into());
        args.push(parent.display().to_string());
    }
    args.push("--ro-bind".into());
    args.push(source.display().to_string());
    args.push(destination.display().to_string());
}

fn bind_capture_support_paths(
    project: &ProjectContext,
    policy_snapshot: &PolicySnapshot,
    runner_path: Option<&Path>,
) -> Vec<PathBuf> {
    let mut paths = landlock::fence_support_read_paths(policy_snapshot, runner_path)
        .into_iter()
        .chain(landlock::fence_support_execute_paths())
        .map(PathBuf::from)
        .filter(|path| !path.starts_with(&project.root))
        .collect::<Vec<_>>();
    paths.sort();
    paths.dedup();
    paths
}

fn destination_parent_dirs(destination: &Path) -> Vec<PathBuf> {
    let mut parents = destination
        .ancestors()
        .skip(1)
        .filter(|path| !path.as_os_str().is_empty() && *path != Path::new("/"))
        .map(Path::to_path_buf)
        .collect::<Vec<_>>();
    parents.reverse();
    parents
}

pub(crate) fn ephemeral_overlay_session_mount(session_dir: &Path, index: usize) -> PathBuf {
    ephemeral_overlay_session_dir(session_dir, index).join("merged")
}

pub(crate) fn ephemeral_overlay_session_upper_dir(session_dir: &Path, index: usize) -> PathBuf {
    ephemeral_overlay_session_dir(session_dir, index).join("upper")
}

fn ephemeral_overlay_session_dir(session_dir: &Path, index: usize) -> PathBuf {
    session_dir
        .join("ephemeral-overlays")
        .join(index.to_string())
}

pub(crate) fn bind_capture_runtime_project_dir(session_dir: &Path) -> PathBuf {
    session_dir.join("runtime").join(".condom")
}

pub(crate) fn ephemeral_overlay_absolute_destination(
    project_root: &Path,
    overlay: &EphemeralOverlay,
) -> Result<PathBuf> {
    if overlay.destination.is_absolute() {
        return ephemeral_overlay_absolute_temp_destination(&overlay.destination);
    }
    let relative = ephemeral_overlay_relative_destination(project_root, &overlay.destination)?;
    Ok(project_root.join(relative))
}

fn ephemeral_overlay_absolute_temp_destination(destination: &Path) -> Result<PathBuf> {
    let cleaned = clean_absolute_ephemeral_overlay_destination(destination)?;
    if !cleaned.starts_with("/tmp") || cleaned == Path::new("/tmp") {
        bail!(
            "ephemeral overlay destination {} must be under /tmp or relative to project root",
            destination.display()
        );
    }
    Ok(cleaned)
}

fn clean_absolute_ephemeral_overlay_destination(destination: &Path) -> Result<PathBuf> {
    let mut cleaned = PathBuf::new();
    for component in destination.components() {
        match component {
            Component::RootDir => cleaned.push(Path::new("/")),
            Component::Normal(part) => cleaned.push(part),
            Component::CurDir => {}
            _ => bail!(
                "ephemeral overlay destination {} must stay under /tmp",
                destination.display()
            ),
        }
    }
    Ok(cleaned)
}

fn ephemeral_overlay_relative_destination(
    project_root: &Path,
    destination: &Path,
) -> Result<PathBuf> {
    let absolute_destination = project_root.join(destination);
    let relative = absolute_destination
        .strip_prefix(project_root)
        .with_context(|| {
            format!(
                "ephemeral overlay destination {} must be under project root {}",
                destination.display(),
                project_root.display()
            )
        })?;
    let mut cleaned = PathBuf::new();
    for component in relative.components() {
        match component {
            std::path::Component::Normal(part) => cleaned.push(part),
            std::path::Component::CurDir => {}
            _ => bail!(
                "ephemeral overlay destination {} must stay under project root {}",
                destination.display(),
                project_root.display()
            ),
        }
    }
    if cleaned.as_os_str().is_empty() {
        bail!("ephemeral overlay destination cannot be the project root");
    }
    Ok(cleaned)
}

fn readonly_system_paths() -> Vec<PathBuf> {
    [
        "/nix",
        "/run/current-system/sw",
        "/etc/static",
        "/etc/ssl",
        "/etc/pki",
        "/etc/hosts",
        "/etc/resolv.conf",
    ]
    .into_iter()
    .map(PathBuf::from)
    .collect()
}

fn capture_runtime_event(
    project: &ProjectContext,
    mode: ExecutionMode,
    command: &[String],
    decision: Decision,
    reason: &str,
) -> Event {
    Event {
        schema_version: EVENT_SCHEMA_VERSION,
        timestamp: chrono::Utc::now(),
        event_type: EventType::Runtime,
        project_id: project.id.clone(),
        project_root: project.root.display().to_string(),
        mode,
        command: crate::model::events::redact_command(command),
        subject: "review-bind-capture".into(),
        decision,
        decision_source: DecisionSource::Runtime,
        suggested_allow: None,
        reason: crate::model::events::redact_reason(reason),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_fuse_device_fails_before_tool_probe() {
        let probe = probe_capture_backend(
            Path::new("/definitely/missing/fuse"),
            Path::new("/definitely/missing/fuse-overlayfs"),
        );

        assert!(matches!(probe, CaptureProbe::MissingFuseDevice { .. }));
    }

    #[test]
    fn bind_capture_runtime_dirs_are_prepared_outside_workspace() {
        let temp = tempfile::tempdir().unwrap();
        let project_state_dir = temp.path().join("project/.condom");
        let runtime_project_dir = temp.path().join("session/runtime/.condom");
        fs::create_dir_all(&project_state_dir).unwrap();
        fs::write(
            project_state_dir.join("config.toml"),
            "[proxy]\ncacheTtlSeconds = 60\n",
        )
        .unwrap();

        ensure_bind_capture_dirs(&project_state_dir, &runtime_project_dir).unwrap();

        assert!(runtime_project_dir.join("home").is_dir());
        assert!(runtime_project_dir.join("tmp").is_dir());
        assert!(runtime_project_dir.join("xdg/cache").is_dir());
        assert_eq!(
            fs::read_to_string(runtime_project_dir.join("config.toml")).unwrap(),
            "[proxy]\ncacheTtlSeconds = 60\n"
        );
    }

    #[test]
    fn bind_capture_args_mount_workspace_at_project_root() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "id".into(),
            origin: None,
        };
        fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();
        let snapshot = crate::model::policy::write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["pwd".into()],
            &[],
        )
        .unwrap();
        let command = vec!["pwd".into()];
        let args = bind_capture_args(BindCaptureArgs {
            project: &project,
            session_dir: Path::new("/tmp/session"),
            workspace_dir: Path::new("/tmp/session/workspace"),
            allow_loopback: snapshot.network.allow_loopback,
            policy_snapshot: &snapshot,
            runner_path: None,
            runtime_project_dir: Path::new("/tmp/session/runtime/.condom"),
            state_xdg_dir: &state.xdg_state_dir,
            ephemeral_overlays: &[],
            review_inspection: false,
            command: &command,
        })
        .unwrap();
        let project_root = project.root.display().to_string();
        let project_state_dir = project.root.join(".condom").display().to_string();

        assert!(args.windows(3).any(|window| {
            window[0] == "--bind"
                && window[1] == "/tmp/session/workspace"
                && window[2] == project_root
        }));
        assert!(args.windows(3).any(|window| {
            window[0] == "--bind"
                && window[1] == "/tmp/session/runtime/.condom"
                && window[2] == "/tmp/session/runtime/.condom"
        }));
        assert!(args.windows(3).any(|window| {
            window[0] == "--bind"
                && window[1] == "/tmp/session/runtime/.condom"
                && window[2] == project_state_dir
        }));
        let state_xdg_dir = state.xdg_state_dir.display().to_string();
        assert!(args.windows(3).any(|window| {
            window[0] == "--bind" && window[1] == state_xdg_dir && window[2] == state_xdg_dir
        }));
        assert!(args
            .windows(2)
            .any(|window| window[0] == "--chdir" && window[1] == project_root));
        assert!(args.windows(3).any(|window| {
            window[0] == "--ro-bind"
                && window[1] == snapshot.path.display().to_string()
                && window[2] == snapshot.path.display().to_string()
        }));
        let runner = std::env::current_exe().unwrap().display().to_string();
        assert!(args.windows(3).any(|window| {
            window[0] == "--ro-bind" && window[1] == runner && window[2] == runner
        }));
    }

    #[test]
    fn bind_capture_args_mount_ephemeral_overlay_destination() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "id".into(),
            origin: None,
        };
        fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();
        let snapshot = crate::model::policy::write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["pwd".into()],
            &[],
        )
        .unwrap();
        let destination = PathBuf::from("/tmp/condom-capture-test/runtime/data/lazy");
        let overlay = EphemeralOverlay {
            source: temp.path().join("lazy"),
            destination: destination.clone(),
        };
        let command = vec!["pwd".into()];
        let overlays = vec![overlay];
        let args = bind_capture_args(BindCaptureArgs {
            project: &project,
            session_dir: Path::new("/tmp/session"),
            workspace_dir: Path::new("/tmp/session/workspace"),
            allow_loopback: snapshot.network.allow_loopback,
            policy_snapshot: &snapshot,
            runner_path: None,
            runtime_project_dir: Path::new("/tmp/session/runtime/.condom"),
            state_xdg_dir: &state.xdg_state_dir,
            ephemeral_overlays: &overlays,
            review_inspection: false,
            command: &command,
        })
        .unwrap();

        assert!(args.windows(3).any(|window| {
            window[0] == "--bind"
                && window[1] == "/tmp/session/ephemeral-overlays/0/merged"
                && window[2] == destination.display().to_string()
        }));
    }

    #[test]
    fn bind_capture_policy_snapshot_allows_ephemeral_overlay_destinations() {
        let temp = tempfile::tempdir().unwrap();
        let destination_root = tempfile::tempdir_in("/tmp").unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "id".into(),
            origin: None,
        };
        fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let virtual_state = StatePaths::from_base(&project, &temp.path().join("session"));
        let config = CondomConfig::default();
        let snapshot = crate::model::policy::write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["pwd".into()],
            &[],
        )
        .unwrap();
        let destination = destination_root.path().join("runtime/data/nvim/lazy");
        let overlay = EphemeralOverlay {
            source: temp.path().join("lazy"),
            destination: destination.clone(),
        };

        let adjusted =
            bind_capture_policy_snapshot(&project, &virtual_state, &snapshot, &[overlay]).unwrap();
        let persisted = crate::model::policy::read_snapshot(&adjusted.path).unwrap();
        let destination = destination.display().to_string();

        assert!(adjusted.path.starts_with(&virtual_state.policy_dir));
        let virtual_state_dir = virtual_state.xdg_state_dir.display().to_string();
        assert!(persisted.filesystem.allow_read.contains(&virtual_state_dir));
        assert!(persisted
            .filesystem
            .allow_write
            .contains(&virtual_state_dir));
        assert!(persisted.filesystem.allow_read.contains(&destination));
        assert!(persisted.filesystem.allow_write.contains(&destination));
    }

    #[test]
    fn ephemeral_overlay_destination_allows_absolute_tmp_path() {
        let project_root = PathBuf::from("/home/example/project");
        let overlay = EphemeralOverlay {
            source: PathBuf::from("/tmp/lazy"),
            destination: PathBuf::from("/tmp/condom-nvim/runtime/data/nvim/lazy"),
        };

        let destination = ephemeral_overlay_absolute_destination(&project_root, &overlay).unwrap();

        assert_eq!(
            destination,
            PathBuf::from("/tmp/condom-nvim/runtime/data/nvim/lazy")
        );
    }

    #[test]
    fn ephemeral_overlay_absolute_destination_must_stay_under_tmp() {
        let project_root = PathBuf::from("/home/example/project");
        let overlay = EphemeralOverlay {
            source: PathBuf::from("/tmp/lazy"),
            destination: PathBuf::from("/home/example/runtime/lazy"),
        };

        let error = ephemeral_overlay_absolute_destination(&project_root, &overlay).unwrap_err();

        assert!(error
            .to_string()
            .contains("must be under /tmp or relative to project root"));
    }

    #[test]
    fn relative_ephemeral_overlay_destination_must_stay_under_project_root() {
        let temp = tempfile::tempdir().unwrap();
        let project_root = temp.path().join("project");
        let overlay = EphemeralOverlay {
            source: temp.path().join("lazy"),
            destination: PathBuf::from("../outside"),
        };

        let error = ephemeral_overlay_absolute_destination(&project_root, &overlay).unwrap_err();

        assert!(error.to_string().contains("must stay under project root"));
    }

    #[test]
    fn bind_capture_environment_includes_proxy_env_and_policy_snapshot() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "id".into(),
            origin: None,
        };
        fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let virtual_state = StatePaths::from_base(&project, &temp.path().join("session"));
        let config = CondomConfig::default();
        let snapshot = crate::model::policy::write_snapshot(
            &project,
            &state,
            &config,
            ExecutionMode::Run,
            &["curl".into()],
            &[32123],
        )
        .unwrap();
        let mut extra_env = BTreeMap::new();
        extra_env.insert("NPM_CONFIG_PROXY".into(), "http://127.0.0.1:32123".into());

        let env = bind_capture_environment(
            &project,
            &virtual_state,
            &config,
            ExecutionMode::Run,
            &extra_env,
            &snapshot,
        );

        assert_eq!(
            env.get("NPM_CONFIG_PROXY").map(String::as_str),
            Some("http://127.0.0.1:32123")
        );
        assert_eq!(
            env.get("CONDOM_POLICY_SNAPSHOT_ID"),
            Some(&snapshot.id.to_string())
        );
        assert_eq!(
            env.get("CONDOM_POLICY_SNAPSHOT"),
            Some(&snapshot.path.display().to_string())
        );
        assert_eq!(env.get("CONDOM_MODE").map(String::as_str), Some("run"));
    }

    #[test]
    fn overlay_mount_options_include_lower_upper_and_work_dirs() {
        let options = overlay_mount_options(
            Path::new("/tmp/project"),
            Path::new("/tmp/session/upper"),
            Path::new("/tmp/session/work"),
        )
        .unwrap();

        assert_eq!(
            options,
            format!(
                "lowerdir=/tmp/project,upperdir=/tmp/session/upper,workdir=/tmp/session/work,squash_to_uid={},squash_to_gid={}",
                unsafe { libc::geteuid() },
                unsafe { libc::getegid() }
            )
        );
    }

    #[test]
    fn overlay_mount_options_reject_ambiguous_paths() {
        let error = overlay_mount_options(
            Path::new("/tmp/project:bad"),
            Path::new("/tmp/session/upper"),
            Path::new("/tmp/session/work"),
        )
        .unwrap_err();

        assert!(error.to_string().contains("cannot contain `:`"));
    }
}
