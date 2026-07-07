use super::*;

pub fn wrap_command(
    policy_snapshot: &PolicySnapshot,
    command: &[String],
) -> io::Result<Vec<String>> {
    wrap_command_with_runner(&runner_path()?, policy_snapshot, command)
}

pub fn wrap_command_path(
    policy_snapshot: &PolicySnapshot,
    command: &[String],
    runtime_path: Option<&str>,
) -> io::Result<Vec<String>> {
    wrap_command_with_runner_path_options(
        &runner_path()?,
        policy_snapshot,
        command,
        runtime_path,
        false,
    )
}

pub fn wrap_interactive_command_path(
    policy_snapshot: &PolicySnapshot,
    command: &[String],
    runtime_path: Option<&str>,
) -> io::Result<Vec<String>> {
    wrap_command_with_runner_path_options(
        &runner_path()?,
        policy_snapshot,
        command,
        runtime_path,
        true,
    )
}

pub fn wrap_command_with_runner(
    runner: &Path,
    policy_snapshot: &PolicySnapshot,
    command: &[String],
) -> io::Result<Vec<String>> {
    wrap_command_with_runner_path(runner, policy_snapshot, command, None)
}

pub fn wrap_command_with_runner_path(
    runner: &Path,
    policy_snapshot: &PolicySnapshot,
    command: &[String],
    runtime_path: Option<&str>,
) -> io::Result<Vec<String>> {
    wrap_command_with_runner_path_options(runner, policy_snapshot, command, runtime_path, false)
}

pub fn wrap_interactive_command_with_runner_path(
    runner: &Path,
    policy_snapshot: &PolicySnapshot,
    command: &[String],
    runtime_path: Option<&str>,
) -> io::Result<Vec<String>> {
    wrap_command_with_runner_path_options(runner, policy_snapshot, command, runtime_path, true)
}

fn wrap_command_with_runner_path_options(
    runner: &Path,
    policy_snapshot: &PolicySnapshot,
    command: &[String],
    runtime_path: Option<&str>,
    interactive_pty: bool,
) -> io::Result<Vec<String>> {
    let mut wrapped = vec![
        runner.display().to_string(),
        "__landlock-exec".into(),
        "--policy-snapshot".into(),
        policy_snapshot.path.display().to_string(),
    ];
    if let Some(runtime_path) = runtime_path {
        wrapped.extend([RUNTIME_PATH_ARG.into(), runtime_path.into()]);
    }
    if interactive_pty {
        wrapped.push(INTERACTIVE_PTY_ARG.into());
    }
    wrapped.push("--".into());
    wrapped.extend(command.iter().cloned());
    Ok(wrapped)
}

pub fn fence_support_read_paths(
    policy_snapshot: &PolicySnapshot,
    runner: Option<&Path>,
) -> Vec<String> {
    let mut paths = vec![policy_snapshot.path.display().to_string()];
    if let Some(runner) = runner {
        paths.push(runner.display().to_string());
    } else if let Ok(runner) = runner_path() {
        paths.push(runner.display().to_string());
    }
    paths
}

pub fn fence_support_execute_paths() -> Vec<String> {
    runner_path()
        .map(|path| vec![path.display().to_string()])
        .unwrap_or_default()
}

pub fn tcp_connect_restrictions_supported() -> bool {
    landlock_abi().map(|abi| abi >= 4).unwrap_or(false)
}

pub fn exec_with_snapshot(
    policy_snapshot_path: &Path,
    command: &[String],
    runtime_path: Option<&str>,
    interactive_pty: bool,
) -> Result<i32> {
    if command.is_empty() {
        bail!("missing command after --");
    }
    let content = fs::read_to_string(policy_snapshot_path)
        .with_context(|| format!("failed to read {}", policy_snapshot_path.display()))?;
    let mut policy_snapshot: PolicySnapshot = serde_json::from_str(&content)
        .with_context(|| format!("failed to parse {}", policy_snapshot_path.display()))?;
    policy_snapshot.path = policy_snapshot_path.to_path_buf();
    let filesystem_notifications = filesystem_notification_runtime_supported();
    crate::debug_log!(
        "landlock runner interactive_pty={interactive_pty} filesystem_notifications={filesystem_notifications}",
    );
    if interactive_pty {
        if filesystem_notifications {
            crate::debug_log!("landlock runner backend=pty-filesystem-notifications");
            return run_pty_command_with_filesystem_notifications(
                &policy_snapshot,
                command,
                runtime_path,
            );
        }
        crate::debug_log!("landlock runner backend=pty-static-landlock");
        return run_pty_command_with_landlock_rules(&policy_snapshot, command, runtime_path);
    }
    if filesystem_notifications {
        crate::debug_log!("landlock runner backend=filesystem-notifications");
        return run_command_with_filesystem_notifications(&policy_snapshot, command, runtime_path);
    }
    crate::debug_log!("landlock runner backend=static-landlock");
    exec_command_with_landlock_rules(&policy_snapshot, command, runtime_path)
}

pub(super) struct OpenedLandlockPath {
    pub(super) fd: OwnedFd,
    pub(super) is_dir: bool,
}

fn exec_command_with_landlock_rules(
    policy_snapshot: &PolicySnapshot,
    command: &[String],
    runtime_path: Option<&str>,
) -> Result<i32> {
    LandlockPlan::from_snapshot(policy_snapshot)
        .context("failed to plan Landlock enforcement")?
        .apply()
        .context("failed to install Landlock enforcement")?;
    let mut command_process = Command::new(&command[0]);
    command_process.args(&command[1..]);
    if let Some(runtime_path) = runtime_path {
        command_process.env("PATH", runtime_path);
    }
    prompt::remove_approval_prompt_environment(&mut command_process);
    remove_internal_control_environment(&mut command_process);
    let error = command_process.exec();
    Err(error).with_context(|| format!("failed to exec {}", command[0]))
}

pub(super) fn insert_path_rule(rules: &mut BTreeMap<PathBuf, u64>, path: &str, access: u64) {
    if let Some(path) = concrete_policy_path(path) {
        rules
            .entry(path)
            .and_modify(|existing| *existing |= access)
            .or_insert(access);
    }
}

pub(super) fn execution_support_paths(policy_snapshot: &PolicySnapshot) -> Vec<String> {
    let mut paths = vec![
        policy_snapshot.project_root.clone(),
        "/nix/store".into(),
        "/run/current-system/sw".into(),
    ];
    paths.extend(policy_snapshot.filesystem.allow_execute.clone());
    paths
}

pub(super) fn runtime_support_rules() -> Vec<(String, u64)> {
    vec![
        ("/dev".into(), READ_ACCESS),
        ("/dev/null".into(), WRITE_ACCESS_BASE),
        ("/dev/tty".into(), WRITE_ACCESS_BASE),
        ("/etc/pki/tls/certs".into(), READ_ACCESS),
        ("/etc/ssl/certs".into(), READ_ACCESS),
        ("/proc".into(), PROC_SUPPORT_ACCESS),
    ]
}

pub(super) fn is_project_parent_directory(project_root: &Path, subject: &str) -> bool {
    let subject = Path::new(subject);
    if subject == Path::new("/") {
        return true;
    }
    project_root
        .ancestors()
        .skip(1)
        .any(|parent| subject == parent)
}

pub(super) fn is_allowed_read_parent_directory(
    policy_snapshot: &PolicySnapshot,
    subject: &str,
) -> bool {
    let subject = Path::new(subject);
    let mut paths = policy_snapshot.filesystem.allow_read.clone();
    paths.extend(execution_support_paths(policy_snapshot));
    paths.extend(
        runtime_support_rules()
            .into_iter()
            .filter_map(|(path, access)| (access & READ_ACCESS != 0).then_some(path)),
    );

    paths
        .iter()
        .filter_map(|path| concrete_policy_path(path))
        .any(|path| is_parent_directory(&path, subject))
}

pub(super) fn is_parent_directory(path: &Path, subject: &Path) -> bool {
    path.ancestors().skip(1).any(|parent| subject == parent)
}

pub(super) fn network_rules(
    policy_snapshot: &PolicySnapshot,
    handled_access_net: u64,
) -> Vec<LandlockNetworkRule> {
    if handled_access_net & LANDLOCK_ACCESS_NET_CONNECT_TCP == 0 {
        return Vec::new();
    }
    let mut ports = policy_snapshot.allowed_loopback_ports.clone();
    if policy_snapshot.transparent_proxy.enabled {
        ports.extend(policy_snapshot.transparent_proxy.tcp_ports.clone());
    }
    ports.sort_unstable();
    ports.dedup();
    ports
        .into_iter()
        .map(|port| LandlockNetworkRule {
            port,
            allowed_access: LANDLOCK_ACCESS_NET_CONNECT_TCP,
        })
        .collect()
}

fn runner_path() -> io::Result<PathBuf> {
    std::env::current_exe()
}

pub(super) fn concrete_policy_path(path: &str) -> Option<PathBuf> {
    let path = expand_home(path);
    let path = path
        .strip_suffix("/**")
        .or_else(|| path.strip_suffix("/*"))
        .unwrap_or(&path)
        .to_string();
    if path.contains('*') {
        return None;
    }
    let path = PathBuf::from(path);
    path.is_absolute().then_some(path)
}

pub(super) fn open_landlock_path(path: &Path) -> io::Result<Option<OpenedLandlockPath>> {
    let metadata = match fs::metadata(path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(error),
    };
    let path = CString::new(path.as_os_str().as_bytes()).map_err(|_| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("Landlock path contains NUL: {}", path.display()),
        )
    })?;
    let fd = unsafe { libc::open(path.as_ptr(), libc::O_PATH | libc::O_CLOEXEC) };
    if fd >= 0 {
        let fd = unsafe { OwnedFd::from_raw_fd(fd) };
        return Ok(Some(OpenedLandlockPath {
            fd,
            is_dir: metadata.is_dir(),
        }));
    }
    match io::Error::last_os_error().kind() {
        io::ErrorKind::NotFound => Ok(None),
        _ => Err(io::Error::last_os_error()),
    }
}

pub(super) fn open_redacted_file(path: &Path) -> io::Result<OwnedFd> {
    let path = CString::new(path.as_os_str().as_bytes()).map_err(|_| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("redacted path contains NUL: {}", path.display()),
        )
    })?;
    let fd = unsafe { libc::open(path.as_ptr(), libc::O_RDONLY | libc::O_CLOEXEC) };
    if fd < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(unsafe { OwnedFd::from_raw_fd(fd) })
}

pub(super) fn allowed_access_for_opened_path(access: u64, is_dir: bool) -> u64 {
    if is_dir {
        access
    } else {
        access & !DIRECTORY_ONLY_ACCESS & !LANDLOCK_ACCESS_FS_TRUNCATE
    }
}
