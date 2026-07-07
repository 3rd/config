use super::*;

impl LandlockPlan {
    pub(super) fn from_snapshot(policy_snapshot: &PolicySnapshot) -> io::Result<Self> {
        Self::from_snapshot_with_filesystem_rules(policy_snapshot, true)
    }

    pub(super) fn from_snapshot_for_filesystem_notifications(
        policy_snapshot: &PolicySnapshot,
    ) -> io::Result<Self> {
        Self::from_snapshot_with_filesystem_rules(policy_snapshot, true)
    }

    pub(super) fn from_snapshot_with_filesystem_rules(
        policy_snapshot: &PolicySnapshot,
        include_filesystem_rules: bool,
    ) -> io::Result<Self> {
        let abi = landlock_abi()?;
        let handled_access_fs = if include_filesystem_rules {
            handled_filesystem_access(abi)
        } else {
            0
        };
        let handled_access_net = handled_network_access(abi, policy_snapshot)?;
        let scoped = scoped_restrictions(abi)?;
        let mut rules = BTreeMap::new();

        if include_filesystem_rules {
            for path in &policy_snapshot.filesystem.allow_read {
                insert_path_rule(&mut rules, path, READ_ACCESS);
            }
            for path in &policy_snapshot.filesystem.allow_write {
                insert_path_rule(
                    &mut rules,
                    path,
                    WRITE_ACCESS_BASE | abi_write_extensions(abi),
                );
            }
            for path in execution_support_paths(policy_snapshot) {
                insert_path_rule(&mut rules, &path, EXECUTE_ACCESS);
            }
            for (path, access) in runtime_support_rules() {
                insert_path_rule(&mut rules, &path, access);
            }
        }

        let mut opened_rules = Vec::new();
        for (path, access) in rules {
            let allowed_access = access & handled_access_fs;
            if allowed_access == 0 {
                continue;
            }
            if let Some(opened) = open_landlock_path(&path)? {
                let allowed_access = allowed_access_for_opened_path(allowed_access, opened.is_dir);
                if allowed_access != 0 {
                    opened_rules.push(LandlockPathRule {
                        path,
                        fd: opened.fd,
                        allowed_access,
                    });
                }
            }
        }

        Ok(Self {
            handled_access_fs,
            handled_access_net,
            scoped,
            rules: opened_rules,
            network_rules: network_rules(policy_snapshot, handled_access_net),
        })
    }

    pub(super) fn apply(&self) -> io::Result<()> {
        let attr = LandlockRulesetAttr {
            handled_access_fs: self.handled_access_fs,
            handled_access_net: self.handled_access_net,
            scoped: self.scoped,
        };
        let ruleset_fd = landlock_create_ruleset(&attr)?;
        for rule in &self.rules {
            landlock_add_path_rule(ruleset_fd, rule).map_err(|error| {
                io::Error::new(
                    error.kind(),
                    format!(
                        "failed to add Landlock rule for {} with access {:#x}: {error}",
                        rule.path.display(),
                        rule.allowed_access
                    ),
                )
            })?;
        }
        for rule in &self.network_rules {
            landlock_add_network_rule(ruleset_fd, rule).map_err(|error| {
                io::Error::new(
                    error.kind(),
                    format!(
                        "failed to add Landlock TCP rule for port {} with access {:#x}: {error}",
                        rule.port, rule.allowed_access
                    ),
                )
            })?;
        }
        unsafe {
            if libc::prctl(libc::PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0 {
                close_fd(ruleset_fd);
                return Err(io::Error::last_os_error());
            }
        }
        if landlock_restrict_self(ruleset_fd).is_err() {
            let error = io::Error::last_os_error();
            close_fd(ruleset_fd);
            return Err(error);
        }
        close_fd(ruleset_fd);
        Ok(())
    }
}

#[derive(Clone, Debug)]
pub(super) struct FilesystemAccess {
    pub(super) kind: ApprovalKind,
    pub(super) path: String,
}

struct OpenNotification {
    pub(super) path: String,
    pub(super) flags: i32,
    pub(super) mode: libc::mode_t,
}

pub(super) struct FilesystemNotificationAuthorizer {
    pub(super) project: ProjectContext,
    pub(super) state: StatePaths,
    pub(super) state_root: Option<PathBuf>,
    pub(super) config: CondomConfig,
    pub(super) event_log: EventLog,
    pub(super) helper_endpoint: Option<HelperEndpoint>,
    pub(super) authorization_cache: Mutex<Vec<CachedFilesystemAuthorization>>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) struct CachedFilesystemAuthorization {
    pub(super) kind: ApprovalKind,
    pub(super) subject: String,
    pub(super) allowed: bool,
}

impl FilesystemNotificationAuthorizer {
    pub(super) fn new(policy_snapshot: &PolicySnapshot) -> Result<Self> {
        Self::from_snapshot(policy_snapshot)
    }

    fn from_snapshot(policy_snapshot: &PolicySnapshot) -> Result<Self> {
        let mut project = ProjectContext::from_root(PathBuf::from(&policy_snapshot.project_root))?;
        project.id = policy_snapshot.project_id.clone();
        let state_root = state_base_from_snapshot_path(&policy_snapshot.path);
        let state = state_root
            .as_deref()
            .map(|state_root| StatePaths::from_base(&project, state_root))
            .unwrap_or_else(|| StatePaths::from_environment(&project));
        let global_config = default_global_config_path(
            std::env::var_os("XDG_CONFIG_HOME").map(PathBuf::from),
            std::env::var_os("HOME").map(PathBuf::from),
        );
        let config = CondomConfig::load(&project.root, global_config.as_deref())?;
        let event_log = EventLog::new(state.events_file.clone());
        let helper_endpoint = helper::configured_supervisor_authorization_endpoint();
        crate::debug_log!(
            "filesystem authorizer helper_endpoint={}",
            helper_endpoint_kind(helper_endpoint.as_ref()),
        );
        Ok(Self {
            project,
            state,
            state_root,
            config,
            event_log,
            helper_endpoint,
            authorization_cache: Mutex::new(Vec::new()),
        })
    }

    pub(super) fn authorize(
        &self,
        policy_snapshot: &PolicySnapshot,
        access: &FilesystemAccess,
    ) -> Result<bool> {
        if snapshot_denies_access(policy_snapshot, access) {
            return Ok(false);
        }
        if access.kind != ApprovalKind::FsRead
            && redact_read_pattern_matches(policy_snapshot, &access.path)
        {
            return Ok(false);
        }
        if redacted_read_matches(policy_snapshot, access) {
            return Ok(true);
        }
        if self.runtime_support_allows(policy_snapshot, access) {
            return Ok(true);
        }
        if missing_read_or_exec_path(access) {
            return Ok(true);
        }
        if let Some(authorization) = self.cached_authorization(access) {
            return Ok(authorization);
        }
        if let Some(authorization) = self.authorize_with_helper(policy_snapshot, access)? {
            let allowed = authorization.decision == ApprovalDecision::Allow;
            crate::debug_log!(
                "filesystem authorization source=helper kind={:?} allowed={allowed} cacheable={}",
                access.kind,
                authorization.is_cacheable(),
            );
            if authorization.is_cacheable() {
                self.cache_authorization(access, &authorization);
            }
            return Ok(allowed);
        }
        let authorization = authorize_filesystem_access(FilesystemAuthorizationContext {
            config: &self.config,
            project: &self.project,
            state: &self.state,
            mode: policy_snapshot.mode,
            command: &policy_snapshot.command,
            kind: access.kind,
            subject: &access.path,
            policy_snapshot: Some(policy_snapshot),
            prompt_environment: None,
            event_log: &self.event_log,
        })?;
        let allowed = authorization.decision == ApprovalDecision::Allow;
        crate::debug_log!(
            "filesystem authorization source=local kind={:?} allowed={allowed} cacheable={}",
            access.kind,
            authorization.is_cacheable(),
        );
        if authorization.is_cacheable() {
            self.cache_authorization(access, &authorization);
        }
        Ok(allowed)
    }

    pub(super) fn authorize_with_helper(
        &self,
        policy_snapshot: &PolicySnapshot,
        access: &FilesystemAccess,
    ) -> Result<Option<FilesystemAuthorization>> {
        let Some(endpoint) = &self.helper_endpoint else {
            return Ok(None);
        };
        let authorization = helper::request_filesystem_authorization(
            endpoint,
            &HelperRequest::AuthorizeFilesystem {
                protocol_version: HELPER_PROTOCOL_VERSION,
                project_root: self.project.root.display().to_string(),
                project_id: self.project.id.clone(),
                state_root: self
                    .state_root
                    .as_ref()
                    .map(|path| path.display().to_string()),
                mode: policy_snapshot.mode,
                command: policy_snapshot.command.clone(),
                kind: access.kind,
                path: access.path.clone(),
                policy_snapshot_id: Some(policy_snapshot.id.to_string()),
                prompt_environment: prompt::approval_prompt_environment(),
                caller_env: crate::app::env::current_user_environment(),
            },
        )
        .context("configured helper failed to authorize filesystem access")?;
        Ok(Some(authorization))
    }

    pub(super) fn cached_authorization(&self, access: &FilesystemAccess) -> Option<bool> {
        self.authorization_cache
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .iter()
            .find(|entry| cached_authorization_matches(entry, access))
            .map(|entry| entry.allowed)
    }

    pub(super) fn cache_authorization(
        &self,
        access: &FilesystemAccess,
        authorization: &FilesystemAuthorization,
    ) {
        let cache_entries = authorization_cache_entries(access, authorization);
        let mut cache = self
            .authorization_cache
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        for entry in cache_entries {
            if let Some(existing) = cache
                .iter_mut()
                .find(|existing| existing.kind == entry.kind && existing.subject == entry.subject)
            {
                existing.allowed = entry.allowed;
            } else {
                cache.push(entry);
            }
        }
    }

    pub(super) fn runtime_support_allows(
        &self,
        policy_snapshot: &PolicySnapshot,
        access: &FilesystemAccess,
    ) -> bool {
        if access.kind == ApprovalKind::FsRead
            && is_project_parent_directory(&self.project.root, &access.path)
        {
            return true;
        }
        if access.kind == ApprovalKind::FsRead
            && is_allowed_read_parent_directory(policy_snapshot, &access.path)
        {
            return true;
        }
        let support_paths =
            match access.kind {
                ApprovalKind::FsRead => {
                    let mut paths = fence_support_read_paths(policy_snapshot, None);
                    paths.push(self.state.xdg_state_dir.display().to_string());
                    paths.extend(execution_support_paths(policy_snapshot));
                    paths.extend(
                        runtime_support_rules()
                            .into_iter()
                            .filter_map(|(path, access)| {
                                (access & READ_ACCESS != 0).then_some(path)
                            }),
                    );
                    paths
                }
                ApprovalKind::FsWrite => {
                    let mut paths = vec![self.state.xdg_state_dir.display().to_string()];
                    paths.extend(runtime_support_rules().into_iter().filter_map(
                        |(path, access)| (access & WRITE_ACCESS_BASE != 0).then_some(path),
                    ));
                    paths
                }
                ApprovalKind::FsExec => execution_support_paths(policy_snapshot),
                _ => Vec::new(),
            };
        support_paths
            .iter()
            .any(|pattern| policy_pattern_matches(pattern, &access.path))
    }
}

fn helper_endpoint_kind(endpoint: Option<&HelperEndpoint>) -> &'static str {
    match endpoint {
        Some(HelperEndpoint::Socket(_)) => "socket",
        Some(HelperEndpoint::Binary(_)) => "binary",
        None => "none",
    }
}

fn missing_read_or_exec_path(access: &FilesystemAccess) -> bool {
    matches!(access.kind, ApprovalKind::FsRead | ApprovalKind::FsExec)
        && matches!(
            fs::symlink_metadata(&access.path),
            Err(error) if error.kind() == io::ErrorKind::NotFound
        )
}

pub(super) fn run_command_with_filesystem_notifications(
    policy_snapshot: &PolicySnapshot,
    command: &[String],
    runtime_path: Option<&str>,
) -> Result<i32> {
    let landlock_plan = LandlockPlan::from_snapshot_for_filesystem_notifications(policy_snapshot)
        .context("failed to plan Landlock enforcement")?;
    let authorizer = FilesystemNotificationAuthorizer::new(policy_snapshot)?;
    let (parent_socket, child_socket) =
        UnixStream::pair().context("failed to create filesystem notification socket")?;
    let parent_fd = parent_socket.as_raw_fd();
    let child_fd = child_socket.as_raw_fd();
    let child = fork_mediated_child(command, runtime_path, parent_fd, child_fd, &landlock_plan)
        .with_context(|| format!("failed to start {}", command[0]))?;
    drop(child_socket);
    let listener = match recv_fd(parent_socket.as_raw_fd()) {
        Ok(listener) => listener,
        Err(error) => {
            kill_and_reap_child(child);
            return Err(error).context("failed to receive seccomp listener");
        }
    };
    supervise_filesystem_notifications(child, listener, policy_snapshot, &authorizer)
}

struct PtyPair {
    pub(super) master: OwnedFd,
    pub(super) slave: OwnedFd,
}

struct FilesystemNotificationHandler<'a> {
    pub(super) listener: OwnedFd,
    pub(super) policy_snapshot: &'a PolicySnapshot,
    pub(super) authorizer: &'a FilesystemNotificationAuthorizer,
}

struct TerminalModeGuard {
    pub(super) fd: RawFd,
    pub(super) original: Option<libc::termios>,
}

static PTY_INTERRUPT_RECEIVED: std::sync::atomic::AtomicBool =
    std::sync::atomic::AtomicBool::new(false);

struct InterruptSignalGuard {
    previous_sigint: libc::sigaction,
    previous_sigterm: libc::sigaction,
}

impl TerminalModeGuard {
    pub(super) fn raw(fd: RawFd) -> io::Result<Self> {
        if unsafe { libc::isatty(fd) } != 1 {
            return Ok(Self { fd, original: None });
        }
        let mut raw = unsafe { std::mem::zeroed::<libc::termios>() };
        if unsafe { libc::tcgetattr(fd, &mut raw) } != 0 {
            return Err(io::Error::last_os_error());
        }
        let mut guard = Self {
            fd,
            original: Some(raw),
        };
        guard.enable_raw()?;
        Ok(guard)
    }

    pub(super) fn with_restored<T>(&mut self, action: impl FnOnce() -> Result<T>) -> Result<T> {
        self.restore()
            .context("failed to restore terminal mode for filesystem prompt")?;
        let result = action();
        if pty_interrupt_received() {
            return result;
        }
        self.enable_raw()
            .context("failed to restore raw terminal mode after filesystem prompt")?;
        result
    }

    fn restore(&mut self) -> io::Result<()> {
        if let Some(original) = self.original.as_ref() {
            set_terminal_mode(self.fd, original)?;
        }
        Ok(())
    }

    fn enable_raw(&mut self) -> io::Result<()> {
        let Some(original) = self.original.as_ref() else {
            return Ok(());
        };
        let mut raw = *original;
        unsafe {
            libc::cfmakeraw(&mut raw);
        }
        set_terminal_mode(self.fd, &raw)
    }
}

impl Drop for TerminalModeGuard {
    fn drop(&mut self) {
        let _ = self.restore();
    }
}

fn set_terminal_mode(fd: RawFd, mode: &libc::termios) -> io::Result<()> {
    if unsafe { libc::tcsetattr(fd, libc::TCSANOW, mode) } != 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

impl InterruptSignalGuard {
    fn install() -> io::Result<Self> {
        PTY_INTERRUPT_RECEIVED.store(false, std::sync::atomic::Ordering::SeqCst);
        Ok(Self {
            previous_sigint: install_interrupt_handler(libc::SIGINT)?,
            previous_sigterm: install_interrupt_handler(libc::SIGTERM)?,
        })
    }

    fn interrupted(&self) -> bool {
        pty_interrupt_received()
    }
}

impl Drop for InterruptSignalGuard {
    fn drop(&mut self) {
        restore_signal_handler(libc::SIGINT, &self.previous_sigint);
        restore_signal_handler(libc::SIGTERM, &self.previous_sigterm);
        PTY_INTERRUPT_RECEIVED.store(false, std::sync::atomic::Ordering::SeqCst);
    }
}

fn install_interrupt_handler(signal: libc::c_int) -> io::Result<libc::sigaction> {
    let mut previous = unsafe { std::mem::zeroed::<libc::sigaction>() };
    let mut action = unsafe { std::mem::zeroed::<libc::sigaction>() };
    action.sa_sigaction = mark_pty_interrupt as *const () as usize;
    action.sa_flags = 0;
    unsafe {
        libc::sigemptyset(&mut action.sa_mask);
        if libc::sigaction(signal, &action, &mut previous) != 0 {
            return Err(io::Error::last_os_error());
        }
    }
    Ok(previous)
}

fn restore_signal_handler(signal: libc::c_int, previous: &libc::sigaction) {
    unsafe {
        libc::sigaction(signal, previous, std::ptr::null_mut());
    }
}

extern "C" fn mark_pty_interrupt(_signal: libc::c_int) {
    PTY_INTERRUPT_RECEIVED.store(true, std::sync::atomic::Ordering::SeqCst);
}

fn pty_interrupt_received() -> bool {
    PTY_INTERRUPT_RECEIVED.load(std::sync::atomic::Ordering::SeqCst)
}

pub(super) fn run_pty_command_with_filesystem_notifications(
    policy_snapshot: &PolicySnapshot,
    command: &[String],
    runtime_path: Option<&str>,
) -> Result<i32> {
    let PtyPair { master, slave } = open_pty().context("failed to open interactive PTY")?;
    let landlock_plan = LandlockPlan::from_snapshot_for_filesystem_notifications(policy_snapshot)
        .context("failed to plan Landlock enforcement")?;
    let authorizer = FilesystemNotificationAuthorizer::new(policy_snapshot)?;
    let (parent_socket, child_socket) =
        UnixStream::pair().context("failed to create filesystem notification socket")?;
    let parent_fd = parent_socket.as_raw_fd();
    let child_fd = child_socket.as_raw_fd();
    let child = fork_pty_child(
        command,
        runtime_path,
        master.as_raw_fd(),
        slave.as_raw_fd(),
        Some((parent_fd, child_fd)),
        Some(&landlock_plan),
    )
    .with_context(|| format!("failed to start {}", command[0]))?;
    drop(child_socket);
    drop(slave);
    let listener = match recv_fd(parent_socket.as_raw_fd()) {
        Ok(listener) => listener,
        Err(error) => {
            kill_and_reap_child(child);
            return Err(error).context("failed to receive seccomp listener");
        }
    };
    supervise_pty_child(
        child,
        master,
        Some(FilesystemNotificationHandler {
            listener,
            policy_snapshot,
            authorizer: &authorizer,
        }),
    )
}

pub(super) fn run_pty_command_with_landlock_rules(
    policy_snapshot: &PolicySnapshot,
    command: &[String],
    runtime_path: Option<&str>,
) -> Result<i32> {
    let PtyPair { master, slave } = open_pty().context("failed to open interactive PTY")?;
    LandlockPlan::from_snapshot(policy_snapshot)
        .context("failed to plan Landlock enforcement")?
        .apply()
        .context("failed to install Landlock enforcement")?;
    let child = fork_pty_child(
        command,
        runtime_path,
        master.as_raw_fd(),
        slave.as_raw_fd(),
        None,
        None,
    )
    .with_context(|| format!("failed to start {}", command[0]))?;
    drop(slave);
    supervise_pty_child(child, master, None)
}

fn open_pty() -> io::Result<PtyPair> {
    let mut master = -1;
    let mut slave = -1;
    let mut window_size = terminal_window_size(libc::STDIN_FILENO);
    let window_size_ptr = window_size
        .as_mut()
        .map_or(std::ptr::null(), |size| size as *mut libc::winsize);
    let opened = unsafe {
        libc::openpty(
            &mut master,
            &mut slave,
            std::ptr::null_mut(),
            std::ptr::null(),
            window_size_ptr,
        )
    };
    if opened != 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(PtyPair {
        master: unsafe { OwnedFd::from_raw_fd(master) },
        slave: unsafe { OwnedFd::from_raw_fd(slave) },
    })
}

fn fork_pty_child(
    command: &[String],
    runtime_path: Option<&str>,
    master_fd: RawFd,
    slave_fd: RawFd,
    notification_fds: Option<(RawFd, RawFd)>,
    child_landlock_plan: Option<&LandlockPlan>,
) -> Result<libc::pid_t> {
    let command_cstrings = command
        .iter()
        .map(|argument| CString::new(argument.as_str()))
        .collect::<std::result::Result<Vec<_>, _>>()
        .context("command argument contains NUL byte")?;
    let mut argv = command_cstrings
        .iter()
        .map(|argument| argument.as_ptr())
        .collect::<Vec<_>>();
    argv.push(std::ptr::null());
    let path_key = CString::new("PATH").unwrap();
    let runtime_path = runtime_path
        .map(CString::new)
        .transpose()
        .context("runtime PATH contains NUL byte")?;

    let pid = unsafe { libc::fork() };
    if pid < 0 {
        return Err(io::Error::last_os_error()).context("failed to fork PTY command");
    }
    if pid == 0 {
        unsafe {
            libc::close(master_fd);
            if let Some((parent_fd, _child_fd)) = notification_fds {
                libc::close(parent_fd);
            }
        }
        let code = match prepare_pty_child(slave_fd).and_then(|()| {
            if let Some((_parent_fd, child_fd)) = notification_fds {
                let landlock_plan = child_landlock_plan.ok_or_else(|| {
                    io::Error::new(
                        io::ErrorKind::InvalidInput,
                        "filesystem notification child missing Landlock plan",
                    )
                })?;
                install_filesystem_notification_child(child_fd, landlock_plan)?;
            }
            Ok(())
        }) {
            Ok(()) => {
                if let Some(runtime_path) = &runtime_path {
                    unsafe {
                        libc::setenv(path_key.as_ptr(), runtime_path.as_ptr(), 1);
                    }
                }
                prompt::clear_approval_prompt_environment_for_exec();
                clear_internal_control_environment_for_exec();
                unsafe {
                    libc::execvp(command_cstrings[0].as_ptr(), argv.as_ptr());
                }
                127
            }
            Err(_) => 126,
        };
        unsafe {
            libc::_exit(code);
        }
    }
    Ok(pid)
}

fn prepare_pty_child(slave_fd: RawFd) -> io::Result<()> {
    if unsafe { libc::setsid() } < 0 {
        return Err(io::Error::last_os_error());
    }
    if unsafe { libc::ioctl(slave_fd, libc::TIOCSCTTY, 0) } < 0 {
        return Err(io::Error::last_os_error());
    }
    for fd in [libc::STDIN_FILENO, libc::STDOUT_FILENO, libc::STDERR_FILENO] {
        if unsafe { libc::dup2(slave_fd, fd) } < 0 {
            return Err(io::Error::last_os_error());
        }
    }
    if slave_fd > libc::STDERR_FILENO {
        unsafe {
            libc::close(slave_fd);
        }
    }
    Ok(())
}

fn supervise_pty_child(
    child: libc::pid_t,
    master: OwnedFd,
    notifications: Option<FilesystemNotificationHandler<'_>>,
) -> Result<i32> {
    let mut child_reaped = false;
    let result = supervise_pty_child_inner(child, master, notifications, &mut child_reaped);
    if result.is_err() && !child_reaped {
        kill_and_reap_child(child);
    }
    result
}

fn supervise_pty_child_inner(
    child: libc::pid_t,
    master: OwnedFd,
    notifications: Option<FilesystemNotificationHandler<'_>>,
    child_reaped: &mut bool,
) -> Result<i32> {
    let interrupt_guard =
        InterruptSignalGuard::install().context("failed to install PTY signal handler")?;
    let mut terminal_mode =
        TerminalModeGuard::raw(libc::STDIN_FILENO).context("failed to set terminal raw mode")?;
    let master_fd = master.as_raw_fd();
    let mut child_status = None;
    let mut master_open = true;
    let mut stdin_open = true;
    let mut last_window_size = terminal_window_size(libc::STDIN_FILENO);
    if let Some(window_size) = last_window_size.as_ref() {
        let _ = set_pty_window_size(master_fd, window_size);
    }
    let mut buffer = [0_u8; 8192];

    loop {
        if interrupt_guard.interrupted() {
            kill_and_reap_child(child);
            *child_reaped = true;
            return Ok(130);
        }
        sync_pty_window_size(master_fd, &mut last_window_size);
        if child_status.is_none() {
            child_status = poll_child_exit(child).context("failed to poll PTY command")?;
            if child_status.is_some() {
                *child_reaped = true;
            }
        }
        if let Some(status) = child_status {
            if !master_open {
                return Ok(status);
            }
        }

        let mut poll_fds = Vec::new();
        let master_index = if master_open {
            let index = poll_fds.len();
            poll_fds.push(libc::pollfd {
                fd: master_fd,
                events: libc::POLLIN | libc::POLLHUP | libc::POLLERR,
                revents: 0,
            });
            Some(index)
        } else {
            None
        };
        let stdin_index = if stdin_open {
            let index = poll_fds.len();
            poll_fds.push(libc::pollfd {
                fd: libc::STDIN_FILENO,
                events: libc::POLLIN | libc::POLLHUP | libc::POLLERR,
                revents: 0,
            });
            Some(index)
        } else {
            None
        };
        let notification_index = notifications.as_ref().map(|handler| {
            let index = poll_fds.len();
            poll_fds.push(libc::pollfd {
                fd: handler.listener.as_raw_fd(),
                events: libc::POLLIN | libc::POLLHUP | libc::POLLERR,
                revents: 0,
            });
            index
        });

        if poll_fds.is_empty() {
            return wait_for_child(child)
                .context("failed to wait for PTY command")?
                .context("PTY command disappeared without an exit status");
        }

        if poll_raw_fds(&mut poll_fds, FILESYSTEM_NOTIFICATION_POLL_MS)? == 0 {
            continue;
        }

        if let Some(index) = master_index {
            let revents = poll_fds[index].revents;
            if revents & libc::POLLIN != 0 {
                match read_raw_fd(master_fd, &mut buffer) {
                    Ok(0) => master_open = false,
                    Ok(read) => write_all_raw_fd(libc::STDOUT_FILENO, &buffer[..read])
                        .context("failed to write PTY output")?,
                    Err(error) if error.raw_os_error() == Some(libc::EIO) => master_open = false,
                    Err(error) => return Err(error).context("failed to read PTY output"),
                }
            }
            if revents & (libc::POLLHUP | libc::POLLERR | libc::POLLNVAL) != 0 {
                master_open = false;
            }
        }

        if let Some(index) = stdin_index {
            let revents = poll_fds[index].revents;
            if revents & libc::POLLIN != 0 {
                match read_raw_fd(libc::STDIN_FILENO, &mut buffer) {
                    Ok(0) => stdin_open = false,
                    Ok(read) => write_all_raw_fd(master_fd, &buffer[..read])
                        .context("failed to write PTY input")?,
                    Err(error) => return Err(error).context("failed to read PTY input"),
                }
            }
            if revents & (libc::POLLHUP | libc::POLLERR | libc::POLLNVAL) != 0 {
                stdin_open = false;
            }
        }

        if let (Some(index), Some(handler)) = (notification_index, notifications.as_ref()) {
            let revents = poll_fds[index].revents;
            if revents & libc::POLLIN != 0 {
                let result =
                    terminal_mode.with_restored(|| handle_filesystem_notification(handler));
                if interrupt_guard.interrupted() {
                    kill_and_reap_child(child);
                    *child_reaped = true;
                    return Ok(130);
                }
                result?;
            }
        }
    }
}

fn handle_filesystem_notification(handler: &FilesystemNotificationHandler<'_>) -> Result<()> {
    let notification = match seccomp::receive_filesystem_notification(&handler.listener) {
        Ok(notification) => notification,
        Err(error) if error.kind() == io::ErrorKind::Interrupted => return Ok(()),
        Err(error) if error.raw_os_error() == Some(libc::ENOENT) => return Ok(()),
        Err(error) => return Err(error).context("failed to receive filesystem notification"),
    };
    let response = filesystem_notification_response(
        &notification,
        handler.policy_snapshot,
        handler.authorizer,
    )
    .context("failed to authorize filesystem notification")?;
    if let Err(error) =
        seccomp::respond_filesystem_notification(&handler.listener, &notification, response)
    {
        if error.raw_os_error() != Some(libc::ENOENT) {
            return Err(error).context("failed to answer filesystem notification");
        }
    }
    Ok(())
}

fn read_raw_fd(fd: RawFd, buffer: &mut [u8]) -> io::Result<usize> {
    loop {
        let read = unsafe { libc::read(fd, buffer.as_mut_ptr().cast(), buffer.len()) };
        if read >= 0 {
            return Ok(read as usize);
        }
        let error = io::Error::last_os_error();
        if error.kind() == io::ErrorKind::Interrupted {
            continue;
        }
        return Err(error);
    }
}

fn write_all_raw_fd(fd: RawFd, mut buffer: &[u8]) -> io::Result<()> {
    while !buffer.is_empty() {
        let written = unsafe { libc::write(fd, buffer.as_ptr().cast(), buffer.len()) };
        if written > 0 {
            buffer = &buffer[written as usize..];
            continue;
        }
        if written == 0 {
            return Err(io::Error::new(
                io::ErrorKind::WriteZero,
                "write returned zero",
            ));
        }
        let error = io::Error::last_os_error();
        if error.kind() != io::ErrorKind::Interrupted {
            return Err(error);
        }
    }
    Ok(())
}

fn poll_raw_fds(fds: &mut [libc::pollfd], timeout_ms: i32) -> io::Result<i32> {
    loop {
        let result = unsafe { libc::poll(fds.as_mut_ptr(), fds.len() as libc::nfds_t, timeout_ms) };
        if result >= 0 {
            return Ok(result);
        }
        let error = io::Error::last_os_error();
        if error.kind() == io::ErrorKind::Interrupted {
            continue;
        }
        return Err(error);
    }
}

fn terminal_window_size(fd: RawFd) -> Option<libc::winsize> {
    let mut window_size = unsafe { std::mem::zeroed::<libc::winsize>() };
    let result = unsafe { libc::ioctl(fd, libc::TIOCGWINSZ, &mut window_size) };
    (result == 0 && window_size.ws_row > 0 && window_size.ws_col > 0).then_some(window_size)
}

fn sync_pty_window_size(master_fd: RawFd, previous: &mut Option<libc::winsize>) {
    let Some(current) = terminal_window_size(libc::STDIN_FILENO) else {
        return;
    };
    if previous
        .as_ref()
        .is_some_and(|last| same_window_size(last, &current))
    {
        return;
    }
    if set_pty_window_size(master_fd, &current).is_ok() {
        *previous = Some(current);
    }
}

fn set_pty_window_size(master_fd: RawFd, window_size: &libc::winsize) -> io::Result<()> {
    if unsafe { libc::ioctl(master_fd, libc::TIOCSWINSZ, window_size) } < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

fn same_window_size(left: &libc::winsize, right: &libc::winsize) -> bool {
    left.ws_row == right.ws_row
        && left.ws_col == right.ws_col
        && left.ws_xpixel == right.ws_xpixel
        && left.ws_ypixel == right.ws_ypixel
}

fn supervise_filesystem_notifications(
    child: libc::pid_t,
    listener: OwnedFd,
    policy_snapshot: &PolicySnapshot,
    authorizer: &FilesystemNotificationAuthorizer,
) -> Result<i32> {
    loop {
        if let Some(status) = poll_child_exit(child).context("failed to poll mediated command")? {
            return Ok(status);
        }
        if !poll_fd(listener.as_raw_fd(), FILESYSTEM_NOTIFICATION_POLL_MS)? {
            continue;
        }
        let notification = match seccomp::receive_filesystem_notification(&listener) {
            Ok(notification) => notification,
            Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
            Err(error) if error.raw_os_error() == Some(libc::ENOENT) => continue,
            Err(error) => return Err(error).context("failed to receive filesystem notification"),
        };
        let response = filesystem_notification_response(&notification, policy_snapshot, authorizer)
            .context("failed to authorize filesystem notification")?;
        if let Err(error) =
            seccomp::respond_filesystem_notification(&listener, &notification, response)
        {
            if error.raw_os_error() != Some(libc::ENOENT) {
                return Err(error).context("failed to answer filesystem notification");
            }
        }
    }
}

pub(super) fn filesystem_notification_runtime_supported() -> bool {
    if !seccomp::filesystem_notification_supported() {
        return false;
    }
    let Ok((parent_socket, child_socket)) = UnixStream::pair() else {
        return false;
    };
    let parent_fd = parent_socket.as_raw_fd();
    let child_fd = child_socket.as_raw_fd();
    let pid = unsafe { libc::fork() };
    if pid < 0 {
        return false;
    }
    if pid == 0 {
        unsafe {
            libc::close(parent_fd);
            libc::prctl(libc::PR_SET_DUMPABLE, 1, 0, 0, 0);
            libc::prctl(libc::PR_SET_PTRACER, libc::getppid(), 0, 0, 0);
        }
        let code = match seccomp::install_filesystem_notification_filter().and_then(|listener| {
            send_fd(child_fd, listener.as_raw_fd())?;
            Ok(listener)
        }) {
            Ok(_listener) => threaded_open_probe_exit_code(),
            Err(_) => 1,
        };
        unsafe {
            libc::_exit(code);
        }
    }
    drop(child_socket);
    let supported = recv_fd(parent_socket.as_raw_fd())
        .ok()
        .and_then(|listener| {
            if !poll_fd(listener.as_raw_fd(), 100).ok()? {
                return Some(false);
            }
            let notification = seccomp::receive_filesystem_notification(&listener).ok()?;
            let can_read = filesystem_accesses_for_notification(&notification).is_ok();
            let response = if can_read {
                FilesystemNotificationResponse::Continue
            } else {
                FilesystemNotificationResponse::Deny(libc::EACCES)
            };
            let _ = seccomp::respond_filesystem_notification(&listener, &notification, response);
            Some(can_read)
        })
        .unwrap_or(false);
    if !supported {
        kill_and_reap_child(pid);
        return false;
    }
    matches!(wait_for_child(pid), Ok(Some(0)))
}

extern "C" fn open_dev_null_thread(_: *mut libc::c_void) -> *mut libc::c_void {
    let path = b"/dev/null\0";
    let fd = unsafe { libc::open(path.as_ptr() as *const libc::c_char, libc::O_RDONLY) };
    if fd >= 0 {
        unsafe {
            libc::close(fd);
        }
        std::ptr::null_mut()
    } else {
        std::ptr::without_provenance_mut(1)
    }
}

fn threaded_open_probe_exit_code() -> i32 {
    let mut thread = unsafe { std::mem::zeroed::<libc::pthread_t>() };
    let created = unsafe {
        libc::pthread_create(
            &mut thread,
            std::ptr::null(),
            open_dev_null_thread,
            std::ptr::null_mut(),
        )
    };
    if created != 0 {
        return 1;
    }
    let mut retval = std::ptr::null_mut();
    let joined = unsafe { libc::pthread_join(thread, &mut retval) };
    if joined == 0 && retval.is_null() {
        0
    } else {
        1
    }
}

fn wait_for_child(pid: libc::pid_t) -> io::Result<Option<i32>> {
    loop {
        match poll_child_exit(pid)? {
            Some(status) => return Ok(Some(status)),
            None => std::thread::sleep(std::time::Duration::from_millis(1)),
        }
    }
}

pub(super) fn fork_mediated_child(
    command: &[String],
    runtime_path: Option<&str>,
    parent_fd: RawFd,
    child_fd: RawFd,
    child_landlock_plan: &LandlockPlan,
) -> Result<libc::pid_t> {
    let command_cstrings = command
        .iter()
        .map(|argument| CString::new(argument.as_str()))
        .collect::<std::result::Result<Vec<_>, _>>()
        .context("command argument contains NUL byte")?;
    let mut argv = command_cstrings
        .iter()
        .map(|argument| argument.as_ptr())
        .collect::<Vec<_>>();
    argv.push(std::ptr::null());
    let path_key = CString::new("PATH").unwrap();
    let runtime_path = runtime_path
        .map(CString::new)
        .transpose()
        .context("runtime PATH contains NUL byte")?;

    let pid = unsafe { libc::fork() };
    if pid < 0 {
        return Err(io::Error::last_os_error()).context("failed to fork mediated command");
    }
    if pid == 0 {
        unsafe {
            libc::close(parent_fd);
            libc::prctl(libc::PR_SET_DUMPABLE, 1, 0, 0, 0);
            libc::prctl(libc::PR_SET_PTRACER, libc::getppid(), 0, 0, 0);
        }
        let code = match seccomp::install_filesystem_notification_filter().and_then(|listener| {
            send_fd(child_fd, listener.as_raw_fd())?;
            unsafe {
                libc::close(child_fd);
            }
            child_landlock_plan.apply()?;
            Ok(listener)
        }) {
            Ok(_listener) => {
                if let Some(runtime_path) = &runtime_path {
                    unsafe {
                        libc::setenv(path_key.as_ptr(), runtime_path.as_ptr(), 1);
                    }
                }
                prompt::clear_approval_prompt_environment_for_exec();
                clear_internal_control_environment_for_exec();
                unsafe { libc::execvp(command_cstrings[0].as_ptr(), argv.as_ptr()) };
                127
            }
            Err(_) => 126,
        };
        unsafe {
            libc::_exit(code);
        }
    }
    Ok(pid)
}

fn install_filesystem_notification_child(
    child_fd: RawFd,
    landlock_plan: &LandlockPlan,
) -> io::Result<()> {
    let listener = seccomp::install_filesystem_notification_filter()?;
    send_fd(child_fd, listener.as_raw_fd())?;
    unsafe {
        libc::close(child_fd);
    }
    landlock_plan.apply()
}

fn poll_child_exit(pid: libc::pid_t) -> io::Result<Option<i32>> {
    let mut status = 0;
    let waited = unsafe { libc::waitpid(pid, &mut status, libc::WNOHANG) };
    if waited == 0 {
        return Ok(None);
    }
    if waited < 0 {
        let error = io::Error::last_os_error();
        if error.kind() == io::ErrorKind::Interrupted {
            return Ok(None);
        }
        return Err(error);
    }
    if libc::WIFEXITED(status) {
        return Ok(Some(libc::WEXITSTATUS(status)));
    }
    if libc::WIFSIGNALED(status) {
        return Ok(Some(128 + libc::WTERMSIG(status)));
    }
    Ok(None)
}

pub(super) fn kill_and_reap_child(pid: libc::pid_t) {
    unsafe {
        libc::kill(pid, libc::SIGKILL);
    }
    let mut status = 0;
    loop {
        let waited = unsafe { libc::waitpid(pid, &mut status, 0) };
        if waited == pid {
            break;
        }
        if waited < 0 && io::Error::last_os_error().kind() != io::ErrorKind::Interrupted {
            break;
        }
    }
}

#[cfg(test)]
mod pty_signal_tests {
    use super::*;

    fn terminal_attributes(fd: RawFd) -> io::Result<libc::termios> {
        let mut attributes = unsafe { std::mem::zeroed::<libc::termios>() };
        if unsafe { libc::tcgetattr(fd, &mut attributes) } != 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(attributes)
    }

    fn assert_same_terminal_mode(left: &libc::termios, right: &libc::termios) {
        assert_eq!(left.c_iflag, right.c_iflag);
        assert_eq!(left.c_oflag, right.c_oflag);
        assert_eq!(left.c_cflag, right.c_cflag);
        assert_eq!(left.c_lflag, right.c_lflag);
        assert_eq!(left.c_line, right.c_line);
        assert_eq!(left.c_cc, right.c_cc);
    }

    #[test]
    fn pty_interrupt_handler_sets_interrupt_flag() {
        PTY_INTERRUPT_RECEIVED.store(false, std::sync::atomic::Ordering::SeqCst);

        mark_pty_interrupt(libc::SIGINT);

        assert!(PTY_INTERRUPT_RECEIVED.load(std::sync::atomic::Ordering::SeqCst));
        PTY_INTERRUPT_RECEIVED.store(false, std::sync::atomic::Ordering::SeqCst);
    }

    #[test]
    fn terminal_mode_guard_keeps_prompt_mode_after_interrupt() {
        PTY_INTERRUPT_RECEIVED.store(false, std::sync::atomic::Ordering::SeqCst);
        let PtyPair {
            master: _master,
            slave,
        } = open_pty().unwrap();
        let original = terminal_attributes(slave.as_raw_fd()).unwrap();
        let mut guard = TerminalModeGuard::raw(slave.as_raw_fd()).unwrap();

        guard
            .with_restored(|| {
                mark_pty_interrupt(libc::SIGINT);
                Ok(())
            })
            .unwrap();

        let current = terminal_attributes(slave.as_raw_fd()).unwrap();
        assert_same_terminal_mode(&original, &current);
        PTY_INTERRUPT_RECEIVED.store(false, std::sync::atomic::Ordering::SeqCst);
    }

    #[test]
    fn terminal_mode_guard_without_terminal_runs_restored_action() {
        let mut guard = TerminalModeGuard {
            fd: -1,
            original: None,
        };

        assert_eq!(guard.with_restored(|| Ok(42)).unwrap(), 42);
    }
}

fn filesystem_notification_response(
    notification: &libc::seccomp_notif,
    policy_snapshot: &PolicySnapshot,
    authorizer: &FilesystemNotificationAuthorizer,
) -> Result<FilesystemNotificationResponse> {
    let accesses = match filesystem_accesses_for_notification(notification) {
        Ok(accesses) => accesses,
        Err(_) => return Ok(FilesystemNotificationResponse::Deny(libc::EACCES)),
    };
    for access in &accesses {
        if !authorizer.authorize(policy_snapshot, access)? {
            return Ok(FilesystemNotificationResponse::Deny(libc::EACCES));
        }
    }
    if let Some(response) = redacted_read_response_for_notification(
        notification,
        &accesses,
        policy_snapshot,
        authorizer,
    )? {
        return Ok(response);
    }
    if let Some(response) = authorized_open_response_for_notification(notification)? {
        return Ok(response);
    }
    if open_write_requires_kernel_backstop(notification)?
        && !accesses
            .iter()
            .all(|access| kernel_backstop_allows(policy_snapshot, authorizer, access))
    {
        return Ok(FilesystemNotificationResponse::Deny(libc::EACCES));
    }
    Ok(FilesystemNotificationResponse::Continue)
}

fn snapshot_denies_access(policy_snapshot: &PolicySnapshot, access: &FilesystemAccess) -> bool {
    let deny = match access.kind {
        ApprovalKind::FsRead => &policy_snapshot.filesystem.deny_read,
        ApprovalKind::FsWrite => &policy_snapshot.filesystem.deny_write,
        ApprovalKind::FsExec => &policy_snapshot.filesystem.deny_execute,
        _ => return false,
    };
    deny.iter()
        .any(|pattern| policy_pattern_matches(pattern, &access.path))
}

fn kernel_backstop_allows(
    policy_snapshot: &PolicySnapshot,
    authorizer: &FilesystemNotificationAuthorizer,
    access: &FilesystemAccess,
) -> bool {
    if snapshot_denies_access(policy_snapshot, access) {
        return false;
    }
    if authorizer.runtime_support_allows(policy_snapshot, access) {
        return true;
    }
    let Some(allow) = snapshot_allow_rules(policy_snapshot, access.kind) else {
        return false;
    };
    allow
        .iter()
        .any(|pattern| policy_pattern_matches(pattern, &access.path))
}

fn snapshot_allow_rules(
    policy_snapshot: &PolicySnapshot,
    kind: ApprovalKind,
) -> Option<&Vec<String>> {
    match kind {
        ApprovalKind::FsRead => Some(&policy_snapshot.filesystem.allow_read),
        ApprovalKind::FsWrite => Some(&policy_snapshot.filesystem.allow_write),
        ApprovalKind::FsExec => Some(&policy_snapshot.filesystem.allow_execute),
        _ => None,
    }
}

fn cached_authorization_matches(
    entry: &CachedFilesystemAuthorization,
    access: &FilesystemAccess,
) -> bool {
    entry.kind == access.kind && policy_pattern_matches(&entry.subject, &access.path)
}

fn authorization_cache_entries(
    access: &FilesystemAccess,
    authorization: &FilesystemAuthorization,
) -> Vec<CachedFilesystemAuthorization> {
    if authorization.cache_entries.is_empty() {
        return vec![CachedFilesystemAuthorization {
            kind: access.kind,
            subject: access.path.clone(),
            allowed: authorization.decision == ApprovalDecision::Allow,
        }];
    }
    authorization
        .cache_entries
        .iter()
        .map(|entry| cached_authorization_entry(entry, authorization.decision))
        .collect()
}

fn cached_authorization_entry(
    entry: &FilesystemAuthorizationCacheEntry,
    decision: ApprovalDecision,
) -> CachedFilesystemAuthorization {
    CachedFilesystemAuthorization {
        kind: entry.kind,
        subject: entry.subject.clone(),
        allowed: decision == ApprovalDecision::Allow,
    }
}

fn redacted_read_matches(policy_snapshot: &PolicySnapshot, access: &FilesystemAccess) -> bool {
    access.kind == ApprovalKind::FsRead
        && redact_read_pattern_matches(policy_snapshot, &access.path)
}

fn redact_read_pattern_matches(policy_snapshot: &PolicySnapshot, path: &str) -> bool {
    if policy_snapshot.filesystem.redact_read.is_empty() {
        return false;
    }
    if redact_pattern_matches_path(policy_snapshot, path) {
        return true;
    }
    // A symlink whose lexical path escapes every redact pattern but whose real
    // target is a redacted secret must still be redacted. Serving a placeholder
    // (or denying a write) on a racing canonicalize never leaks original bytes,
    // so this additive check is safe.
    if let Ok(canonical) = fs::canonicalize(path) {
        let canonical = canonical.display().to_string();
        if canonical != path {
            return redact_pattern_matches_path(policy_snapshot, &canonical);
        }
    }
    false
}

fn redact_pattern_matches_path(policy_snapshot: &PolicySnapshot, path: &str) -> bool {
    policy_snapshot
        .filesystem
        .redact_read
        .iter()
        .any(|pattern| policy_pattern_matches(pattern, path))
}

fn redacted_read_response_for_notification(
    notification: &libc::seccomp_notif,
    accesses: &[FilesystemAccess],
    policy_snapshot: &PolicySnapshot,
    authorizer: &FilesystemNotificationAuthorizer,
) -> Result<Option<FilesystemNotificationResponse>> {
    if !accesses
        .iter()
        .any(|access| redacted_read_matches(policy_snapshot, access))
    {
        return Ok(None);
    }
    let Some(open) = open_notification(notification)? else {
        return Ok(None);
    };
    if open_flags_kind(open.flags) != ApprovalKind::FsRead {
        return Ok(None);
    }
    if !policy_snapshot
        .filesystem
        .redact_read
        .iter()
        .any(|pattern| policy_pattern_matches(pattern, &open.path))
    {
        return Ok(None);
    }
    let metadata = match fs::metadata(&open.path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(error).context("failed to inspect redacted host path"),
    };
    if !metadata.is_file() {
        return Ok(None);
    }
    let view = redacted::materialize_host_path_view(&authorizer.state.runtime_dir, &open.path)?;
    let fd = open_redacted_file(&view)
        .with_context(|| format!("failed to open redacted view {}", view.display()))?;
    authorizer.event_log.append(&Event::filesystem_decision(
        &authorizer.project,
        policy_snapshot.mode,
        &policy_snapshot.command,
        &open.path,
        Decision::Redacted,
        "served configured redacted filesystem view",
    ))?;
    Ok(Some(FilesystemNotificationResponse::AddFd {
        fd,
        close_on_exec: open.flags & libc::O_CLOEXEC != 0,
    }))
}

fn authorized_open_response_for_notification(
    notification: &libc::seccomp_notif,
) -> Result<Option<FilesystemNotificationResponse>> {
    let Some(open) = open_notification(notification)? else {
        return Ok(None);
    };
    let fd = match open_flags_kind(open.flags) {
        ApprovalKind::FsRead => open_authorized_read_fd(&open),
        ApprovalKind::FsWrite => open_authorized_write_fd(&open),
        _ => None,
    };
    match fd {
        Some(fd) => Ok(Some(FilesystemNotificationResponse::AddFd {
            fd,
            close_on_exec: open.flags & libc::O_CLOEXEC != 0,
        })),
        None => Ok(None),
    }
}

fn open_write_requires_kernel_backstop(notification: &libc::seccomp_notif) -> Result<bool> {
    Ok(open_notification(notification)?
        .as_ref()
        .is_some_and(|open| open_flags_kind(open.flags) == ApprovalKind::FsWrite))
}

fn open_authorized_read_fd(open: &OpenNotification) -> Option<OwnedFd> {
    let path = CString::new(open.path.as_bytes()).ok()?;
    let follow = open.flags & libc::O_NOFOLLOW == 0;
    let probe_flags = libc::O_PATH | libc::O_CLOEXEC | if follow { 0 } else { libc::O_NOFOLLOW };
    // O_PATH never blocks and has no side effects, so it is safe even on a FIFO,
    // device, or socket purely to inspect the file type before a real open.
    let probe = unsafe { libc::open(path.as_ptr(), probe_flags) };
    if probe < 0 {
        return None;
    }
    let probe = unsafe { OwnedFd::from_raw_fd(probe) };
    let mut stat: libc::stat = unsafe { std::mem::zeroed() };
    if unsafe { libc::fstat(probe.as_raw_fd(), &mut stat) } != 0 {
        return None;
    }
    if stat.st_mode & libc::S_IFMT != libc::S_IFREG {
        return None;
    }
    // Reopen the pinned inode through /proc/self/fd so no path component can be
    // swapped between validation and open. Strip O_CLOEXEC (set via AddFd) and
    // O_NOFOLLOW (the /proc magic link must be followed); keep the child's other
    // read flags so mismatches such as O_DIRECTORY still fail naturally.
    let reopen = CString::new(format!("/proc/self/fd/{}", probe.as_raw_fd())).ok()?;
    let reopen_flags = open.flags & !libc::O_CLOEXEC & !libc::O_NOFOLLOW;
    let fd = unsafe { libc::open(reopen.as_ptr(), reopen_flags) };
    if fd < 0 {
        return None;
    }
    Some(unsafe { OwnedFd::from_raw_fd(fd) })
}

fn open_authorized_write_fd(open: &OpenNotification) -> Option<OwnedFd> {
    if open.flags & libc::O_CREAT != 0 {
        return None;
    }
    let path = CString::new(open.path.as_bytes()).ok()?;
    let follow = open.flags & libc::O_NOFOLLOW == 0;
    let probe_flags = libc::O_PATH | libc::O_CLOEXEC | if follow { 0 } else { libc::O_NOFOLLOW };
    let probe = unsafe { libc::open(path.as_ptr(), probe_flags) };
    if probe < 0 {
        return None;
    }
    let probe = unsafe { OwnedFd::from_raw_fd(probe) };
    let mut stat: libc::stat = unsafe { std::mem::zeroed() };
    if unsafe { libc::fstat(probe.as_raw_fd(), &mut stat) } != 0 {
        return None;
    }
    if stat.st_mode & libc::S_IFMT != libc::S_IFREG {
        return None;
    }
    let reopen = CString::new(format!("/proc/self/fd/{}", probe.as_raw_fd())).ok()?;
    let reopen_flags = open.flags & !libc::O_CLOEXEC & !libc::O_NOFOLLOW;
    let fd = unsafe { libc::open(reopen.as_ptr(), reopen_flags, open.mode) };
    if fd < 0 {
        return None;
    }
    Some(unsafe { OwnedFd::from_raw_fd(fd) })
}

fn open_notification(notification: &libc::seccomp_notif) -> Result<Option<OpenNotification>> {
    let pid = notification.pid as libc::pid_t;
    let syscall = notification.data.nr as i64;
    let args = notification.data.args;
    let notification = match syscall {
        x if x == libc::SYS_open => OpenNotification {
            path: resolve_child_path(pid, libc::AT_FDCWD, &read_child_path(pid, args[0])?)?,
            flags: args[1] as i32,
            mode: args[2] as libc::mode_t,
        },
        x if x == libc::SYS_openat => OpenNotification {
            path: resolve_child_path(pid, args[0] as i32, &read_child_path(pid, args[1])?)?,
            flags: args[2] as i32,
            mode: args[3] as libc::mode_t,
        },
        x if x == libc::SYS_openat2 => {
            let how = read_child_value::<OpenHow>(pid, args[2])?;
            OpenNotification {
                path: resolve_child_path(pid, args[0] as i32, &read_child_path(pid, args[1])?)?,
                flags: how.flags as i32,
                mode: how.mode as libc::mode_t,
            }
        }
        x if x == libc::SYS_creat => OpenNotification {
            path: resolve_child_path(pid, libc::AT_FDCWD, &read_child_path(pid, args[0])?)?,
            flags: libc::O_WRONLY | libc::O_CREAT | libc::O_TRUNC,
            mode: args[1] as libc::mode_t,
        },
        _ => return Ok(None),
    };
    Ok(Some(notification))
}

pub(super) fn filesystem_accesses_for_notification(
    notification: &libc::seccomp_notif,
) -> Result<Vec<FilesystemAccess>> {
    let pid = notification.pid as libc::pid_t;
    let syscall = notification.data.nr as i64;
    let args = notification.data.args;
    let accesses = match syscall {
        x if x == libc::SYS_open => vec![notification_path_access(
            pid,
            open_flags_kind(args[1] as i32),
            libc::AT_FDCWD,
            args[0],
        )?],
        x if x == libc::SYS_openat => vec![notification_path_access(
            pid,
            open_flags_kind(args[2] as i32),
            args[0] as i32,
            args[1],
        )?],
        x if x == libc::SYS_openat2 => {
            let path = read_child_path(pid, args[1])?;
            let how = read_child_value::<OpenHow>(pid, args[2])?;
            vec![FilesystemAccess {
                kind: open_flags_kind(how.flags as i32),
                path: resolve_child_path(pid, args[0] as i32, &path)?,
            }]
        }
        x if x == libc::SYS_access
            || x == libc::SYS_stat
            || x == libc::SYS_lstat
            || x == libc::SYS_readlink =>
        {
            vec![notification_path_access(
                pid,
                ApprovalKind::FsRead,
                libc::AT_FDCWD,
                args[0],
            )?]
        }
        x if x == libc::SYS_faccessat || x == libc::SYS_newfstatat || x == libc::SYS_readlinkat => {
            vec![notification_path_access(
                pid,
                ApprovalKind::FsRead,
                args[0] as i32,
                args[1],
            )?]
        }
        x if x == libc::SYS_statx => vec![notification_path_access(
            pid,
            ApprovalKind::FsRead,
            args[0] as i32,
            args[1],
        )?],
        x if x == libc::SYS_creat
            || x == libc::SYS_mknod
            || x == libc::SYS_unlink
            || x == libc::SYS_rmdir
            || x == libc::SYS_mkdir
            || x == libc::SYS_chmod
            || x == libc::SYS_chown
            || x == libc::SYS_lchown
            || x == libc::SYS_truncate =>
        {
            vec![notification_path_access(
                pid,
                ApprovalKind::FsWrite,
                libc::AT_FDCWD,
                args[0],
            )?]
        }
        x if x == libc::SYS_mknodat
            || x == libc::SYS_unlinkat
            || x == libc::SYS_mkdirat
            || x == libc::SYS_fchmodat
            || x == libc::SYS_fchownat =>
        {
            vec![notification_path_access(
                pid,
                ApprovalKind::FsWrite,
                args[0] as i32,
                args[1],
            )?]
        }
        x if x == libc::SYS_utimensat => {
            optional_notification_path_access(pid, ApprovalKind::FsWrite, args[0] as i32, args[1])?
                .into_iter()
                .collect()
        }
        x if x == libc::SYS_symlink => vec![notification_path_access(
            pid,
            ApprovalKind::FsWrite,
            libc::AT_FDCWD,
            args[1],
        )?],
        x if x == libc::SYS_symlinkat => vec![notification_path_access(
            pid,
            ApprovalKind::FsWrite,
            args[1] as i32,
            args[2],
        )?],
        x if x == libc::SYS_link => vec![
            notification_path_access(pid, ApprovalKind::FsRead, libc::AT_FDCWD, args[0])?,
            notification_path_access(pid, ApprovalKind::FsWrite, libc::AT_FDCWD, args[1])?,
        ],
        x if x == libc::SYS_linkat => vec![
            notification_path_access(pid, ApprovalKind::FsRead, args[0] as i32, args[1])?,
            notification_path_access(pid, ApprovalKind::FsWrite, args[2] as i32, args[3])?,
        ],
        x if x == libc::SYS_rename => {
            vec![
                notification_path_access(pid, ApprovalKind::FsWrite, libc::AT_FDCWD, args[0])?,
                notification_path_access(pid, ApprovalKind::FsWrite, libc::AT_FDCWD, args[1])?,
            ]
        }
        x if x == libc::SYS_renameat || x == libc::SYS_renameat2 => {
            vec![
                notification_path_access(pid, ApprovalKind::FsWrite, args[0] as i32, args[1])?,
                notification_path_access(pid, ApprovalKind::FsWrite, args[2] as i32, args[3])?,
            ]
        }
        x if x == libc::SYS_execve => vec![notification_path_access(
            pid,
            ApprovalKind::FsExec,
            libc::AT_FDCWD,
            args[0],
        )?],
        x if x == libc::SYS_execveat => vec![notification_path_access(
            pid,
            ApprovalKind::FsExec,
            args[0] as i32,
            args[1],
        )?],
        _ => Vec::new(),
    };
    Ok(accesses)
}

fn notification_path_access(
    pid: libc::pid_t,
    kind: ApprovalKind,
    dirfd: i32,
    path_address: u64,
) -> Result<FilesystemAccess> {
    let path = read_child_path(pid, path_address)?;
    Ok(FilesystemAccess {
        kind,
        path: resolve_child_path(pid, dirfd, &path)?,
    })
}

fn optional_notification_path_access(
    pid: libc::pid_t,
    kind: ApprovalKind,
    dirfd: i32,
    path_address: u64,
) -> Result<Option<FilesystemAccess>> {
    if path_address == 0 {
        return Ok(None);
    }
    notification_path_access(pid, kind, dirfd, path_address).map(Some)
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OpenHow {
    pub(super) flags: u64,
    pub(super) mode: u64,
    pub(super) resolve: u64,
}

fn open_flags_kind(flags: i32) -> ApprovalKind {
    let writes = flags & libc::O_ACCMODE != libc::O_RDONLY
        || flags & (libc::O_CREAT | libc::O_TRUNC | libc::O_APPEND) != 0;
    if writes {
        ApprovalKind::FsWrite
    } else {
        ApprovalKind::FsRead
    }
}

fn read_child_path(pid: libc::pid_t, address: u64) -> Result<String> {
    let mut bytes = Vec::new();
    for offset in (0..4096).step_by(256) {
        let chunk = read_child_bytes(pid, address + offset, 256)?;
        for byte in chunk {
            if byte == 0 {
                return String::from_utf8(bytes).context("child path was not UTF-8");
            }
            bytes.push(byte);
        }
    }
    bail!("child path exceeded maximum length");
}

fn read_child_value<T: Copy>(pid: libc::pid_t, address: u64) -> Result<T> {
    let bytes = read_child_bytes(pid, address, size_of::<T>())?;
    if bytes.len() != size_of::<T>() {
        bail!("short read from child memory");
    }
    let mut value = unsafe { std::mem::zeroed::<T>() };
    unsafe {
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), &mut value as *mut T as *mut u8, bytes.len());
    }
    Ok(value)
}

fn read_child_bytes(pid: libc::pid_t, address: u64, len: usize) -> Result<Vec<u8>> {
    if let Ok(bytes) = read_child_bytes_with_process_vm(pid, address, len) {
        return Ok(bytes);
    }
    if let Some(tgid) = thread_group_id(pid).filter(|tgid| *tgid != pid) {
        if let Ok(bytes) = read_child_bytes_with_process_vm(tgid, address, len) {
            return Ok(bytes);
        }
    }
    if let Ok(bytes) = read_child_bytes_from_proc_mem(pid, address, len) {
        return Ok(bytes);
    }
    read_child_bytes_with_ptrace(pid, address, len).context("failed to read child memory")
}

fn read_child_bytes_with_process_vm(pid: libc::pid_t, address: u64, len: usize) -> Result<Vec<u8>> {
    let mut bytes = vec![0; len];
    let local = libc::iovec {
        iov_base: bytes.as_mut_ptr() as *mut libc::c_void,
        iov_len: bytes.len(),
    };
    let remote = libc::iovec {
        iov_base: address as *mut libc::c_void,
        iov_len: bytes.len(),
    };
    let read = unsafe { libc::process_vm_readv(pid, &local, 1, &remote, 1, 0) };
    if read < 0 {
        return Err(io::Error::last_os_error())
            .with_context(|| format!("failed to process-vm-read child {pid}"));
    }
    bytes.truncate(read as usize);
    Ok(bytes)
}

fn read_child_bytes_from_proc_mem(pid: libc::pid_t, address: u64, len: usize) -> Result<Vec<u8>> {
    let paths = proc_mem_paths(pid);
    let mut last_error = None;
    use std::io::{Read, Seek, SeekFrom};
    for path in paths {
        let result = fs::OpenOptions::new()
            .read(true)
            .open(&path)
            .with_context(|| format!("failed to open {}", path.display()))
            .and_then(|mut mem| {
                mem.seek(SeekFrom::Start(address))
                    .with_context(|| format!("failed to seek child memory to {address:#x}"))?;
                let mut bytes = vec![0; len];
                mem.read_exact(&mut bytes)
                    .with_context(|| format!("failed to read {len} bytes from child memory"))?;
                Ok(bytes)
            });
        match result {
            Ok(bytes) => return Ok(bytes),
            Err(error) => last_error = Some(error),
        }
    }
    match last_error {
        Some(error) => Err(error),
        None => bail!("no child memory paths available for {pid}"),
    }
}

fn read_child_bytes_with_ptrace(pid: libc::pid_t, address: u64, len: usize) -> Result<Vec<u8>> {
    attach_child_for_ptrace(pid)?;
    let result = read_attached_child_bytes(pid, address, len);
    let detach_result = detach_child_from_ptrace(pid);
    match (result, detach_result) {
        (Ok(bytes), Ok(())) => Ok(bytes),
        (Err(error), Ok(())) => Err(error),
        (Ok(_), Err(error)) => Err(error).context("failed to detach from child after memory read"),
        (Err(error), Err(detach_error)) => {
            Err(error).with_context(|| format!("also failed to detach from child: {detach_error}"))
        }
    }
}

fn attach_child_for_ptrace(pid: libc::pid_t) -> Result<()> {
    if unsafe {
        libc::ptrace(
            libc::PTRACE_ATTACH,
            pid,
            std::ptr::null_mut::<libc::c_void>(),
            std::ptr::null_mut::<libc::c_void>(),
        )
    } != 0
    {
        return Err(io::Error::last_os_error()).context("failed to ptrace-attach child");
    }

    loop {
        let mut status = 0;
        let waited = unsafe { libc::waitpid(pid, &mut status, 0) };
        if waited == pid {
            if libc::WIFSTOPPED(status) {
                return Ok(());
            }
            if libc::WIFEXITED(status) || libc::WIFSIGNALED(status) {
                bail!("child exited before ptrace memory read");
            }
        }
        if waited < 0 && io::Error::last_os_error().kind() != io::ErrorKind::Interrupted {
            return Err(io::Error::last_os_error()).context("failed to wait for ptrace stop");
        }
    }
}

fn detach_child_from_ptrace(pid: libc::pid_t) -> io::Result<()> {
    if unsafe {
        libc::ptrace(
            libc::PTRACE_DETACH,
            pid,
            std::ptr::null_mut::<libc::c_void>(),
            std::ptr::null_mut::<libc::c_void>(),
        )
    } != 0
    {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

fn read_attached_child_bytes(pid: libc::pid_t, address: u64, len: usize) -> Result<Vec<u8>> {
    let word_size = size_of::<libc::c_long>();
    let mut bytes = Vec::with_capacity(len);
    while bytes.len() < len {
        let current_address = address + bytes.len() as u64;
        clear_errno();
        let word = unsafe {
            libc::ptrace(
                libc::PTRACE_PEEKDATA,
                pid,
                current_address as *mut libc::c_void,
                std::ptr::null_mut::<libc::c_void>(),
            )
        };
        if word == -1 && last_errno() != 0 {
            return Err(io::Error::last_os_error())
                .with_context(|| format!("failed to ptrace-read child at {current_address:#x}"));
        }
        let word_bytes = word.to_ne_bytes();
        let remaining = len - bytes.len();
        bytes.extend_from_slice(&word_bytes[..remaining.min(word_size)]);
    }
    Ok(bytes)
}

fn clear_errno() {
    unsafe {
        *libc::__errno_location() = 0;
    }
}

fn last_errno() -> i32 {
    unsafe { *libc::__errno_location() }
}

fn resolve_child_path(pid: libc::pid_t, dirfd: i32, path: &str) -> Result<String> {
    let path = Path::new(path);
    if path.is_absolute() {
        return Ok(normalize_path(path).display().to_string());
    }
    if path.as_os_str().is_empty() {
        let base = if dirfd == libc::AT_FDCWD {
            read_child_proc_link(pid, "cwd")?
        } else {
            read_child_proc_link(pid, &format!("fd/{dirfd}"))?
        };
        return Ok(normalize_path(&base).display().to_string());
    }
    let base = if dirfd == libc::AT_FDCWD {
        read_child_proc_link(pid, "cwd")?
    } else {
        read_child_proc_link(pid, &format!("fd/{dirfd}"))?
    };
    Ok(normalize_path(&base.join(path)).display().to_string())
}

fn read_child_proc_link(pid: libc::pid_t, entry: &str) -> Result<PathBuf> {
    let paths = proc_task_paths(pid, entry);
    let mut last_error = None;
    for path in paths {
        match fs::read_link(&path) {
            Ok(target) => return Ok(target),
            Err(error) => last_error = Some((path, error)),
        }
    }
    match last_error {
        Some((path, error)) => {
            Err(error).with_context(|| format!("failed to resolve {}", path.display()))
        }
        None => bail!("no proc entries available for child {pid}"),
    }
}

fn proc_task_paths(pid: libc::pid_t, entry: &str) -> Vec<PathBuf> {
    let mut paths = vec![PathBuf::from(format!("/proc/{pid}/{entry}"))];
    if let Some(tgid) = thread_group_id(pid) {
        paths.push(PathBuf::from(format!("/proc/{tgid}/task/{pid}/{entry}")));
        if tgid != pid {
            paths.push(PathBuf::from(format!("/proc/{tgid}/{entry}")));
        }
    }
    paths
}

fn proc_mem_paths(pid: libc::pid_t) -> Vec<PathBuf> {
    proc_task_paths(pid, "mem")
}

fn thread_group_id(pid: libc::pid_t) -> Option<libc::pid_t> {
    let status = fs::read_to_string(format!("/proc/{pid}/status")).ok()?;
    status.lines().find_map(|line| {
        line.strip_prefix("Tgid:")
            .and_then(|value| value.trim().parse::<libc::pid_t>().ok())
    })
}

fn normalize_path(path: &Path) -> PathBuf {
    let mut normalized = PathBuf::new();
    for component in path.components() {
        match component {
            std::path::Component::RootDir => normalized.push(component.as_os_str()),
            std::path::Component::CurDir => {}
            std::path::Component::ParentDir => {
                normalized.pop();
            }
            std::path::Component::Normal(value) => normalized.push(value),
            std::path::Component::Prefix(value) => normalized.push(value.as_os_str()),
        }
    }
    normalized
}

fn state_base_from_snapshot_path(path: &Path) -> Option<PathBuf> {
    path.parent()
        .and_then(Path::parent)
        .and_then(Path::parent)
        .and_then(Path::parent)
        .map(Path::to_path_buf)
}

pub(super) fn poll_fd(fd: RawFd, timeout_ms: i32) -> io::Result<bool> {
    let mut fds = [libc::pollfd {
        fd,
        events: libc::POLLIN,
        revents: 0,
    }];
    let result = unsafe { libc::poll(fds.as_mut_ptr(), fds.len() as libc::nfds_t, timeout_ms) };
    if result < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(result > 0 && fds[0].revents & libc::POLLIN != 0)
}

fn send_fd(socket_fd: RawFd, fd: RawFd) -> io::Result<()> {
    let mut byte = [0u8];
    let mut iov = libc::iovec {
        iov_base: byte.as_mut_ptr() as *mut libc::c_void,
        iov_len: byte.len(),
    };
    let control_len = unsafe { libc::CMSG_SPACE(size_of::<RawFd>() as u32) } as usize;
    let mut control = [0u8; 64];
    let mut message = unsafe { std::mem::zeroed::<libc::msghdr>() };
    message.msg_iov = &mut iov;
    message.msg_iovlen = 1;
    message.msg_control = control.as_mut_ptr() as *mut libc::c_void;
    message.msg_controllen = control_len;
    unsafe {
        let cmsg = libc::CMSG_FIRSTHDR(&message);
        if cmsg.is_null() {
            return Err(io::Error::other("failed to allocate fd control message"));
        }
        (*cmsg).cmsg_level = libc::SOL_SOCKET;
        (*cmsg).cmsg_type = libc::SCM_RIGHTS;
        (*cmsg).cmsg_len = libc::CMSG_LEN(size_of::<RawFd>() as u32) as usize;
        std::ptr::write(libc::CMSG_DATA(cmsg) as *mut RawFd, fd);
        message.msg_controllen = control_len;
        if libc::sendmsg(socket_fd, &message, 0) < 0 {
            return Err(io::Error::last_os_error());
        }
    }
    Ok(())
}

pub(super) fn recv_fd(socket_fd: RawFd) -> io::Result<OwnedFd> {
    let mut byte = [0u8];
    let mut iov = libc::iovec {
        iov_base: byte.as_mut_ptr() as *mut libc::c_void,
        iov_len: byte.len(),
    };
    let control_len = unsafe { libc::CMSG_SPACE(size_of::<RawFd>() as u32) } as usize;
    let mut control = vec![0u8; control_len];
    let mut message = unsafe { std::mem::zeroed::<libc::msghdr>() };
    message.msg_iov = &mut iov;
    message.msg_iovlen = 1;
    message.msg_control = control.as_mut_ptr() as *mut libc::c_void;
    message.msg_controllen = control.len();
    let received = unsafe { libc::recvmsg(socket_fd, &mut message, 0) };
    if received < 0 {
        return Err(io::Error::last_os_error());
    }
    unsafe {
        let cmsg = libc::CMSG_FIRSTHDR(&message);
        if cmsg.is_null()
            || (*cmsg).cmsg_level != libc::SOL_SOCKET
            || (*cmsg).cmsg_type != libc::SCM_RIGHTS
        {
            return Err(io::Error::other("missing fd control message"));
        }
        let fd = std::ptr::read(libc::CMSG_DATA(cmsg) as *const RawFd);
        Ok(OwnedFd::from_raw_fd(fd))
    }
}

#[cfg(test)]
mod addfd_tests {
    use super::*;
    use std::io::{Read, Write};

    fn read_fd(fd: OwnedFd) -> String {
        let mut file = std::fs::File::from(fd);
        let mut content = String::new();
        file.read_to_string(&mut content).unwrap();
        content
    }

    #[test]
    fn injects_regular_file_read_fd() {
        let temp = tempfile::tempdir().unwrap();
        let file = temp.path().join("data.txt");
        std::fs::write(&file, "hello").unwrap();
        let open = OpenNotification {
            path: file.display().to_string(),
            flags: libc::O_RDONLY,
            mode: 0,
        };
        let fd = open_authorized_read_fd(&open).expect("regular file read should inject an fd");
        assert_eq!(read_fd(fd), "hello");
    }

    #[test]
    fn falls_back_for_directory() {
        let temp = tempfile::tempdir().unwrap();
        let open = OpenNotification {
            path: temp.path().display().to_string(),
            flags: libc::O_RDONLY,
            mode: 0,
        };
        assert!(open_authorized_read_fd(&open).is_none());
    }

    #[test]
    fn follows_symlink_to_regular_file_and_pins_target() {
        let temp = tempfile::tempdir().unwrap();
        let target = temp.path().join("target.txt");
        std::fs::write(&target, "secret").unwrap();
        let link = temp.path().join("link.txt");
        std::os::unix::fs::symlink(&target, &link).unwrap();
        let open = OpenNotification {
            path: link.display().to_string(),
            flags: libc::O_RDONLY,
            mode: 0,
        };
        let fd = open_authorized_read_fd(&open).expect("symlink to regular file should inject");
        assert_eq!(read_fd(fd), "secret");
    }

    #[test]
    fn injects_existing_regular_file_write_fd() {
        let temp = tempfile::tempdir().unwrap();
        let file = temp.path().join("data.txt");
        std::fs::write(&file, "hello").unwrap();
        let open = OpenNotification {
            path: file.display().to_string(),
            flags: libc::O_WRONLY | libc::O_TRUNC,
            mode: 0,
        };

        let fd = open_authorized_write_fd(&open).expect("regular file write should inject an fd");
        let mut opened = std::fs::File::from(fd);
        opened.write_all(b"changed").unwrap();
        drop(opened);

        assert_eq!(open_flags_kind(libc::O_WRONLY), ApprovalKind::FsWrite);
        assert_eq!(std::fs::read_to_string(file).unwrap(), "changed");
    }

    #[test]
    fn does_not_inject_create_write_open() {
        let temp = tempfile::tempdir().unwrap();
        let file = temp.path().join("data.txt");
        let open = OpenNotification {
            path: file.display().to_string(),
            flags: libc::O_WRONLY | libc::O_CREAT,
            mode: 0o600,
        };

        assert!(open_authorized_write_fd(&open).is_none());
        assert_eq!(open_flags_kind(open.flags), ApprovalKind::FsWrite);
    }
}
