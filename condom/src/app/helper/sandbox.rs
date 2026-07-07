use super::*;

use std::os::unix::fs::{MetadataExt, OpenOptionsExt};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SandboxPreparation {
    pub policy_snapshot_id: String,
    pub capabilities: Vec<HelperCapability>,
    pub runner: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct HelperRunSandboxRequest {
    #[serde(rename = "protocolVersion")]
    pub protocol_version: u32,
    pub kind: HelperSandboxKind,
    #[serde(rename = "projectRoot")]
    pub project_root: String,
    #[serde(rename = "projectId")]
    pub project_id: String,
    #[serde(rename = "stateRoot", default)]
    pub state_root: Option<String>,
    #[serde(rename = "callerUid")]
    pub caller_uid: libc::uid_t,
    #[serde(rename = "callerGid")]
    pub caller_gid: libc::gid_t,
    #[serde(rename = "callerEnv", default)]
    pub caller_env: BTreeMap<String, String>,
    pub mode: ExecutionMode,
    pub command: Vec<String>,
    #[serde(rename = "policySnapshotId")]
    pub policy_snapshot_id: String,
    #[serde(rename = "extraEnv", default)]
    pub extra_env: BTreeMap<String, String>,
    #[serde(rename = "runtimePath", default)]
    pub runtime_path: Option<String>,
    #[serde(rename = "ephemeralOverlays", default)]
    pub ephemeral_overlays: Vec<capture::EphemeralOverlay>,
    #[serde(rename = "resultPath", default)]
    pub result_path: Option<String>,
}

impl HelperRunSandboxRequest {
    pub(super) fn caller_credentials(&self) -> PeerCredentials {
        PeerCredentials {
            uid: self.caller_uid,
            gid: self.caller_gid,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum HelperSandboxKind {
    Run,
    Review,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct HelperRunSandboxResult {
    #[serde(rename = "protocolVersion")]
    pub protocol_version: u32,
    #[serde(rename = "policySnapshotId")]
    pub policy_snapshot_id: String,
    #[serde(rename = "exitCode")]
    pub exit_code: i32,
    pub runner: String,
}

pub struct SocketHelperRequest {
    pub request: HelperRequest,
    pub stdio_fds: Vec<OwnedFd>,
    pub peer_credentials: Option<PeerCredentials>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct PeerCredentials {
    pub uid: libc::uid_t,
    pub gid: libc::gid_t,
}

pub fn duplicate_stdout() -> Result<File> {
    let duplicated = unsafe { libc::dup(libc::STDOUT_FILENO) };
    if duplicated < 0 {
        return Err(std::io::Error::last_os_error()).context("failed to duplicate stdout");
    }
    Ok(unsafe { File::from_raw_fd(duplicated) })
}

pub fn read_socket_request_from_stdio() -> Result<SocketHelperRequest> {
    let fd = std::io::stdin().as_raw_fd();
    match read_request_with_fds(fd) {
        Ok(request) => Ok(request),
        Err(error)
            if matches!(
                error
                    .downcast_ref::<std::io::Error>()
                    .and_then(|io| io.raw_os_error()),
                Some(libc::ENOTSOCK | libc::EINVAL)
            ) =>
        {
            Ok(SocketHelperRequest {
                request: read_request(std::io::stdin())?,
                stdio_fds: Vec::new(),
                peer_credentials: None,
            })
        }
        Err(error) => Err(error),
    }
}

pub fn handle_socket_request(request: SocketHelperRequest) -> HelperResponse {
    let SocketHelperRequest {
        request,
        stdio_fds,
        peer_credentials,
    } = request;
    let stdio_fd_count = stdio_fds.len();
    crate::debug_log!(
        "helper socket request kind={} stdio_fds={stdio_fd_count}",
        helper_request_kind(&request),
    );
    match request {
        HelperRequest::RunSandbox { request } => {
            match run_sandbox_socket_request(
                request,
                request_stdio_fds(stdio_fds, "run-sandbox socket request"),
                peer_credentials,
            ) {
                Ok(result) => HelperResponse::SandboxRunFinished {
                    protocol_version: result.protocol_version,
                    policy_snapshot_id: result.policy_snapshot_id,
                    exit_code: result.exit_code,
                    runner: result.runner,
                },
                Err(error) => invalid_request_response(format!("{error:#}")),
            }
        }
        request @ HelperRequest::AuthorizeFilesystem { .. } if stdio_fd_count > 0 => {
            match handle_filesystem_authorization_socket_request(
                request,
                stdio_fds,
                peer_credentials,
            ) {
                Ok(response) => response,
                Err(error) => invalid_request_response(format!("{error:#}")),
            }
        }
        request => handle_request(request),
    }
}

struct HelperStdioFds {
    pub(super) stdin: OwnedFd,
    pub(super) stdout: OwnedFd,
    pub(super) stderr: OwnedFd,
}

fn request_stdio_fds(mut fds: Vec<OwnedFd>, context: &str) -> Result<HelperStdioFds> {
    if fds.len() != 3 {
        bail!(
            "{context} requires stdin/stdout/stderr file descriptors; received {}",
            fds.len()
        );
    }
    let stderr = fds.pop().unwrap();
    let stdout = fds.pop().unwrap();
    let stdin = fds.pop().unwrap();
    Ok(HelperStdioFds {
        stdin,
        stdout,
        stderr,
    })
}

fn install_socket_request_stdio(fds: Vec<OwnedFd>, context: &str) -> Result<()> {
    let fds = request_stdio_fds(fds, context)?;
    dup_stdio_fds(&fds)
}

fn handle_filesystem_authorization_socket_request(
    request: HelperRequest,
    stdio_fds: Vec<OwnedFd>,
    peer_credentials: Option<PeerCredentials>,
) -> Result<HelperResponse> {
    install_socket_request_stdio(stdio_fds, "filesystem authorization socket request")?;
    if let HelperRequest::AuthorizeFilesystem { caller_env, .. } = &request {
        match peer_credentials {
            Some(credentials) => drop_to_peer_credentials(credentials)?,
            None if unsafe { libc::geteuid() } == 0 => {
                bail!(
                    "refusing privileged filesystem authorization without authenticated socket peer credentials"
                );
            }
            None => {}
        }
        restore_caller_user_environment(caller_env)?;
    }
    Ok(handle_request(request))
}

fn run_sandbox_socket_request(
    request: HelperRunSandboxRequest,
    stdio_fds: Result<HelperStdioFds>,
    peer_credentials: Option<PeerCredentials>,
) -> Result<HelperRunSandboxResult> {
    let stdio_fds = stdio_fds?;
    dup_stdio_fds(&stdio_fds)?;
    execute_sandbox_request(request, peer_credentials)
}

fn dup_stdio_fds(fds: &HelperStdioFds) -> Result<()> {
    dup2_fd(fds.stdin.as_raw_fd(), libc::STDIN_FILENO, "stdin")?;
    dup2_fd(fds.stdout.as_raw_fd(), libc::STDOUT_FILENO, "stdout")?;
    dup2_fd(fds.stderr.as_raw_fd(), libc::STDERR_FILENO, "stderr")?;
    Ok(())
}

fn dup2_fd(source: RawFd, target: RawFd, name: &str) -> Result<()> {
    if unsafe { libc::dup2(source, target) } < 0 {
        return Err(std::io::Error::last_os_error())
            .with_context(|| format!("failed to install {name} fd for helper sandbox"));
    }
    Ok(())
}

fn helper_request_kind(request: &HelperRequest) -> &'static str {
    match request {
        HelperRequest::Probe { .. } => "probe",
        HelperRequest::PrepareSandbox { .. } => "prepare-sandbox",
        HelperRequest::AuthorizeFilesystem { .. } => "authorize-filesystem",
        HelperRequest::Credential { .. } => "credential",
        HelperRequest::RunSandbox { .. } => "run-sandbox",
    }
}

fn read_request_with_fds(fd: RawFd) -> Result<SocketHelperRequest> {
    let mut buffer = vec![0_u8; 8192];
    let mut iov = libc::iovec {
        iov_base: buffer.as_mut_ptr().cast(),
        iov_len: buffer.len(),
    };
    let mut control = vec![0_u8; cmsg_space_for_fds(3)];
    let mut message: libc::msghdr = unsafe { std::mem::zeroed() };
    message.msg_iov = &mut iov;
    message.msg_iovlen = 1;
    message.msg_control = control.as_mut_ptr().cast();
    message.msg_controllen = control.len();

    let received = unsafe { libc::recvmsg(fd, &mut message, 0) };
    if received < 0 {
        return Err(std::io::Error::last_os_error())
            .context("failed to receive helper socket request");
    }
    let mut content = buffer[..received as usize].to_vec();
    let stdio_fds = received_fds(&message);
    std::io::stdin()
        .read_to_end(&mut content)
        .context("failed to read remaining helper socket request")?;
    let request =
        serde_json::from_slice(&content).context("failed to parse helper socket request")?;
    Ok(SocketHelperRequest {
        request,
        stdio_fds,
        peer_credentials: socket_peer_credentials(fd).ok().flatten(),
    })
}

pub(super) fn socket_peer_credentials(fd: RawFd) -> std::io::Result<Option<PeerCredentials>> {
    let mut credentials: libc::ucred = unsafe { std::mem::zeroed() };
    let mut length = std::mem::size_of::<libc::ucred>() as libc::socklen_t;
    let result = unsafe {
        libc::getsockopt(
            fd,
            libc::SOL_SOCKET,
            libc::SO_PEERCRED,
            (&mut credentials as *mut libc::ucred).cast(),
            &mut length,
        )
    };
    if result < 0 {
        let error = std::io::Error::last_os_error();
        if matches!(error.raw_os_error(), Some(libc::ENOTSOCK | libc::EINVAL)) {
            return Ok(None);
        }
        return Err(error);
    }
    Ok(Some(PeerCredentials {
        uid: credentials.uid,
        gid: credentials.gid,
    }))
}

fn received_fds(message: &libc::msghdr) -> Vec<OwnedFd> {
    let mut fds = Vec::new();
    let mut cmsg = unsafe { libc::CMSG_FIRSTHDR(message) };
    while !cmsg.is_null() {
        let header = unsafe { &*cmsg };
        if header.cmsg_level == libc::SOL_SOCKET && header.cmsg_type == libc::SCM_RIGHTS {
            let data_len = header.cmsg_len as usize - cmsg_len_for_fds(0);
            let fd_count = data_len / std::mem::size_of::<RawFd>();
            let data = unsafe { libc::CMSG_DATA(cmsg).cast::<RawFd>() };
            for index in 0..fd_count {
                let fd = unsafe { *data.add(index) };
                fds.push(unsafe { OwnedFd::from_raw_fd(fd) });
            }
        }
        cmsg = unsafe { libc::CMSG_NXTHDR(message, cmsg) };
    }
    fds
}

pub(super) fn cmsg_space_for_fds(count: usize) -> usize {
    unsafe { libc::CMSG_SPACE((count * std::mem::size_of::<RawFd>()) as u32) as usize }
}

pub(super) fn cmsg_len_for_fds(count: usize) -> usize {
    unsafe { libc::CMSG_LEN((count * std::mem::size_of::<RawFd>()) as u32) as usize }
}

pub fn prepare_configured_sandbox(
    project: &ProjectContext,
    _state: &StatePaths,
    snapshot: &policy::PolicySnapshot,
) -> Result<Option<SandboxPreparation>> {
    let Some(endpoint) = configured_authorization_endpoint() else {
        return Ok(None);
    };
    prepare_sandbox(&endpoint, project, snapshot).map(Some)
}

pub fn run_configured_socket_sandbox(
    project: &ProjectContext,
    state: &StatePaths,
    mode: ExecutionMode,
    command: &[String],
    extra_env: &BTreeMap<String, String>,
    snapshot: &policy::PolicySnapshot,
) -> Result<Option<i32>> {
    let Some(path) = configured_execution_socket_path()? else {
        return Ok(None);
    };
    let extra_env = sandbox_request_extra_environment(extra_env, &path);
    let request = HelperRunSandboxRequest {
        protocol_version: HELPER_PROTOCOL_VERSION,
        kind: HelperSandboxKind::Run,
        project_root: project.root.display().to_string(),
        project_id: project.id.clone(),
        state_root: Some(
            state_base_from_snapshot_path(&snapshot.path)
                .context("failed to derive state root from policy snapshot path")?
                .display()
                .to_string(),
        ),
        caller_uid: unsafe { libc::getuid() },
        caller_gid: unsafe { libc::getgid() },
        caller_env: crate::app::env::current_user_environment(),
        mode,
        command: command.to_vec(),
        policy_snapshot_id: snapshot.id.to_string(),
        extra_env,
        runtime_path: runtime_path_for_helper_request(mode, project, state),
        ephemeral_overlays: Vec::new(),
        result_path: None,
    };
    request_socket_sandbox(&path, request, snapshot).map(Some)
}

pub fn review_configured_socket_sandbox(
    project: &ProjectContext,
    state: &StatePaths,
    mode: ExecutionMode,
    command: &[String],
    ephemeral_overlays: &[capture::EphemeralOverlay],
    extra_env: &BTreeMap<String, String>,
    snapshot: &policy::PolicySnapshot,
) -> Result<Option<i32>> {
    let Some(path) = configured_execution_socket_path()? else {
        return Ok(None);
    };
    if !ephemeral_overlays.is_empty()
        && !helper_socket_has_capability(&path, HelperCapability::EphemeralOverlays)?
    {
        return Ok(None);
    }
    let extra_env = sandbox_request_extra_environment(extra_env, &path);
    let request = HelperRunSandboxRequest {
        protocol_version: HELPER_PROTOCOL_VERSION,
        kind: HelperSandboxKind::Review,
        project_root: project.root.display().to_string(),
        project_id: project.id.clone(),
        state_root: Some(
            state_base_from_snapshot_path(&snapshot.path)
                .context("failed to derive state root from policy snapshot path")?
                .display()
                .to_string(),
        ),
        caller_uid: unsafe { libc::getuid() },
        caller_gid: unsafe { libc::getgid() },
        caller_env: crate::app::env::current_user_environment(),
        mode,
        command: command.to_vec(),
        policy_snapshot_id: snapshot.id.to_string(),
        extra_env,
        runtime_path: runtime_path_for_helper_request(mode, project, state),
        ephemeral_overlays: ephemeral_overlays.to_vec(),
        result_path: None,
    };
    request_socket_sandbox(&path, request, snapshot).map(Some)
}

pub fn run_configured_binary_sandbox(
    project: &ProjectContext,
    state: &StatePaths,
    mode: ExecutionMode,
    command: &[String],
    extra_env: &BTreeMap<String, String>,
    snapshot: &policy::PolicySnapshot,
) -> Result<Option<i32>> {
    if helper_reentry_disabled() {
        return Ok(None);
    }
    let Some(path) = std::env::var_os(HELPER_ENV).map(PathBuf::from) else {
        return Ok(None);
    };
    state.ensure_state_dir()?;
    let artifacts = HelperBinaryArtifacts::new(state, mode, "run");
    let state_root = state_base_from_snapshot_path(&snapshot.path)
        .context("failed to derive state root from policy snapshot path")?;
    artifacts.remove_existing();
    let request = HelperRunSandboxRequest {
        protocol_version: HELPER_PROTOCOL_VERSION,
        kind: HelperSandboxKind::Run,
        project_root: project.root.display().to_string(),
        project_id: project.id.clone(),
        state_root: Some(state_root.display().to_string()),
        caller_uid: unsafe { libc::getuid() },
        caller_gid: unsafe { libc::getgid() },
        caller_env: crate::app::env::current_user_environment(),
        mode,
        command: command.to_vec(),
        policy_snapshot_id: snapshot.id.to_string(),
        extra_env: extra_env.clone(),
        runtime_path: runtime_path_for_helper_request(mode, project, state),
        ephemeral_overlays: Vec::new(),
        result_path: Some(artifacts.result_path().display().to_string()),
    };
    write_helper_request_file(artifacts.request_path(), &request, "run")?;
    let status = Command::new(&path)
        .arg("run-sandbox")
        .arg("--request")
        .arg(artifacts.request_path())
        .status()
        .with_context(|| format!("failed to start helper `{}`", path.display()))?;
    if !status.success() {
        bail!(
            "helper `{}` failed to supervise sandbox with status {}",
            path.display(),
            status
        );
    }
    let result = read_run_sandbox_result(artifacts.result_path())?;
    if result.policy_snapshot_id != snapshot.id.to_string() {
        bail!(
            "helper run result policy snapshot mismatch: expected `{}`, got `{}`",
            snapshot.id,
            result.policy_snapshot_id
        );
    }
    Ok(Some(result.exit_code))
}

pub fn review_configured_binary_sandbox(
    project: &ProjectContext,
    state: &StatePaths,
    mode: ExecutionMode,
    command: &[String],
    ephemeral_overlays: &[capture::EphemeralOverlay],
    extra_env: &BTreeMap<String, String>,
    snapshot: &policy::PolicySnapshot,
) -> Result<Option<i32>> {
    if helper_reentry_disabled() {
        return Ok(None);
    }
    let Some(path) = std::env::var_os(HELPER_ENV).map(PathBuf::from) else {
        return Ok(None);
    };
    if !ephemeral_overlays.is_empty()
        && !helper_binary_has_capability(&path, HelperCapability::EphemeralOverlays)?
    {
        return Ok(None);
    }
    state.ensure_state_dir()?;
    let artifacts = HelperBinaryArtifacts::new(state, mode, "review");
    let state_root = state_base_from_snapshot_path(&snapshot.path)
        .context("failed to derive state root from policy snapshot path")?;
    artifacts.remove_existing();
    let request = HelperRunSandboxRequest {
        protocol_version: HELPER_PROTOCOL_VERSION,
        kind: HelperSandboxKind::Review,
        project_root: project.root.display().to_string(),
        project_id: project.id.clone(),
        state_root: Some(state_root.display().to_string()),
        caller_uid: unsafe { libc::getuid() },
        caller_gid: unsafe { libc::getgid() },
        caller_env: crate::app::env::current_user_environment(),
        mode,
        command: command.to_vec(),
        policy_snapshot_id: snapshot.id.to_string(),
        extra_env: extra_env.clone(),
        runtime_path: runtime_path_for_helper_request(mode, project, state),
        ephemeral_overlays: ephemeral_overlays.to_vec(),
        result_path: Some(artifacts.result_path().display().to_string()),
    };
    write_helper_request_file(artifacts.request_path(), &request, "review")?;
    let status = Command::new(&path)
        .arg("run-sandbox")
        .arg("--request")
        .arg(artifacts.request_path())
        .status()
        .with_context(|| format!("failed to start helper `{}`", path.display()))?;
    if !status.success() {
        bail!(
            "helper `{}` failed to supervise review with status {}",
            path.display(),
            status
        );
    }
    let result = read_run_sandbox_result(artifacts.result_path())?;
    if result.policy_snapshot_id != snapshot.id.to_string() {
        bail!(
            "helper review result policy snapshot mismatch: expected `{}`, got `{}`",
            snapshot.id,
            result.policy_snapshot_id
        );
    }
    Ok(Some(result.exit_code))
}

#[derive(Debug)]
struct HelperBinaryArtifacts {
    request_path: PathBuf,
    result_path: PathBuf,
}

impl HelperBinaryArtifacts {
    fn new(state: &StatePaths, mode: ExecutionMode, operation: &str) -> Self {
        let pid = std::process::id();
        Self {
            request_path: state.xdg_state_dir.join(format!(
                "{}-{pid}-helper-{operation}-request.json",
                mode.as_str()
            )),
            result_path: state.xdg_state_dir.join(format!(
                "{}-{pid}-helper-{operation}-result.json",
                mode.as_str()
            )),
        }
    }

    fn request_path(&self) -> &Path {
        &self.request_path
    }

    fn result_path(&self) -> &Path {
        &self.result_path
    }

    fn remove_existing(&self) {
        remove_helper_artifact(&self.request_path, "stale helper request");
        remove_helper_artifact(&self.result_path, "stale helper result");
    }
}

impl Drop for HelperBinaryArtifacts {
    fn drop(&mut self) {
        remove_helper_artifact(&self.request_path, "helper request");
        remove_helper_artifact(&self.result_path, "helper result");
    }
}

fn remove_helper_artifact(path: &Path, label: &str) {
    match fs::remove_file(path) {
        Ok(()) => {}
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
        Err(error) => {
            crate::debug_log!("failed to remove {label} {}: {error}", path.display());
        }
    }
}

fn write_helper_request_file(
    path: &Path,
    request: &HelperRunSandboxRequest,
    operation: &str,
) -> Result<()> {
    let content = serde_json::to_string_pretty(request)?;
    let mut file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(path)
        .with_context(|| {
            format!(
                "failed to write helper {operation} request {}",
                path.display()
            )
        })?;
    file.write_all(content.as_bytes()).with_context(|| {
        format!(
            "failed to write helper {operation} request {}",
            path.display()
        )
    })
}

pub fn prepare_sandbox(
    endpoint: &HelperEndpoint,
    project: &ProjectContext,
    snapshot: &policy::PolicySnapshot,
) -> Result<SandboxPreparation> {
    let state_root = state_base_from_snapshot_path(&snapshot.path)
        .context("failed to derive state root from policy snapshot path")?;
    let response = request_helper(
        endpoint,
        &HelperRequest::PrepareSandbox {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: project.root.display().to_string(),
            project_id: project.id.clone(),
            state_root: Some(state_root.display().to_string()),
            policy_snapshot_id: snapshot.id.to_string(),
        },
    )?;
    match response {
        HelperResponse::SandboxPrepared {
            policy_snapshot_id,
            capabilities,
            runner,
            ..
        } => Ok(SandboxPreparation {
            policy_snapshot_id,
            capabilities,
            runner,
        }),
        HelperResponse::MissingCapabilities {
            missing_capabilities,
            message,
        } => bail!(
            "{message}: {}",
            missing_capabilities
                .iter()
                .map(ToString::to_string)
                .collect::<Vec<_>>()
                .join(", ")
        ),
        HelperResponse::UnsupportedProtocol { expected, actual } => {
            bail!("helper protocol mismatch: expected {expected}, got {actual}")
        }
        HelperResponse::InvalidRequest { message }
        | HelperResponse::NotInstalled { message }
        | HelperResponse::CredentialUnavailable { reason: message } => {
            bail!("helper refused sandbox preparation request: {message}")
        }
        HelperResponse::Ready { .. } => {
            bail!("helper returned probe response to sandbox preparation request")
        }
        HelperResponse::SandboxRunFinished { .. } => {
            bail!("helper returned sandbox execution response to sandbox preparation request")
        }
        HelperResponse::FilesystemAuthorization { .. } => {
            bail!(
                "helper returned filesystem authorization response to sandbox preparation request"
            )
        }
        HelperResponse::Credential { .. } => {
            bail!("helper returned credential response to sandbox preparation request")
        }
    }
}

pub fn run_sandbox_request_file(path: &Path) -> Result<HelperRunSandboxResult> {
    let content = fs::read_to_string(path)
        .with_context(|| format!("failed to read helper run request {}", path.display()))?;
    let request = serde_json::from_str(&content).context("failed to parse helper run request")?;
    run_sandbox_request(request)
}

pub fn run_sandbox_request(request: HelperRunSandboxRequest) -> Result<HelperRunSandboxResult> {
    let result_path = request
        .result_path
        .clone()
        .context("helper run request missing resultPath")?;
    let result = execute_sandbox_request(request, None)?;
    write_run_sandbox_result(Path::new(&result_path), &result)?;
    Ok(result)
}

fn execute_sandbox_request(
    request: HelperRunSandboxRequest,
    peer_credentials: Option<PeerCredentials>,
) -> Result<HelperRunSandboxResult> {
    if request.protocol_version != HELPER_PROTOCOL_VERSION {
        bail!(
            "helper protocol mismatch: expected {}, got {}",
            HELPER_PROTOCOL_VERSION,
            request.protocol_version
        );
    }
    let requested_root = PathBuf::from(&request.project_root);
    if !requested_root.is_dir() {
        bail!("project root `{}` is not a directory", request.project_root);
    }
    let project = requested_project(requested_root, request.project_id.clone())
        .with_context(|| format!("failed to resolve project root `{}`", request.project_root))?;
    let state = request
        .state_root
        .as_ref()
        .map(|root| StatePaths::from_base(&project, &PathBuf::from(root)))
        .unwrap_or_else(|| StatePaths::from_environment(&project));
    let snapshot = load_policy_snapshot(&project, &state, &request.policy_snapshot_id)
        .map_err(anyhow::Error::msg)?;
    let capabilities = helper_capabilities();
    let missing_capabilities = missing_required_capabilities_for_snapshot(&snapshot, &capabilities);
    if !missing_capabilities.is_empty() {
        bail!(
            "root supervisor sandbox preparation is missing required capabilities: {}",
            missing_capabilities
                .iter()
                .map(ToString::to_string)
                .collect::<Vec<_>>()
                .join(", ")
        );
    }
    let credentials = match peer_credentials {
        Some(credentials) => credentials,
        None if unsafe { libc::geteuid() } == 0 => {
            bail!("refusing privileged sandbox run without authenticated socket peer credentials")
        }
        None => request.caller_credentials(),
    };
    repair_runtime_ownership(&state, credentials)?;
    drop_to_peer_credentials(credentials)?;
    restore_caller_user_environment(&request.caller_env)?;
    let global_config = default_global_config_path(
        std::env::var_os("XDG_CONFIG_HOME").map(PathBuf::from),
        std::env::var_os("HOME").map(PathBuf::from),
    );
    let config = CondomConfig::load(&project.root, global_config.as_deref())
        .context("failed to load project config")?;
    let event_log = EventLog::new(state.events_file.clone());
    let runner_path = sibling_condom_runner_path()?;
    let sandbox_extra_env = sandbox_extra_environment(&request.extra_env);
    let exit_code = match request.kind {
        HelperSandboxKind::Run => fence::run_prepared_with_fence_env(
            &project,
            &state,
            &config,
            request.mode,
            &request.command,
            &event_log,
            FenceRunOptions {
                extra_env: &sandbox_extra_env,
                policy_snapshot: &snapshot,
                runner_path: Some(&runner_path),
                runtime_path: request.runtime_path.as_deref(),
            },
        )?,
        HelperSandboxKind::Review => {
            let session = review::create_session();
            let runtime_dir = capture::bind_capture_runtime_project_dir(&session.session_dir);
            let review_state = state.with_runtime_dir(runtime_dir);
            review::run_review_session_with_runner_in_session(
                session,
                &project,
                &review_state,
                &config,
                request.mode,
                &request.command,
                &request.ephemeral_overlays,
                &sandbox_extra_env,
                &event_log,
                &snapshot,
                Some(&runner_path),
                request.runtime_path.as_deref(),
            )?
        }
    };
    Ok(HelperRunSandboxResult {
        protocol_version: HELPER_PROTOCOL_VERSION,
        policy_snapshot_id: snapshot.id.to_string(),
        exit_code,
        runner: "fence-landlock-seccomp".into(),
    })
}

fn sandbox_extra_environment(extra_env: &BTreeMap<String, String>) -> BTreeMap<String, String> {
    let mut environment: BTreeMap<String, String> = extra_env
        .iter()
        .filter(|(key, _)| !crate::app::env::is_reserved_sandbox_env_key(key))
        .map(|(key, value)| (key.clone(), value.clone()))
        .collect();
    environment.insert(DISABLE_HELPER_REENTRY_ENV.into(), "1".into());
    environment
}

fn sandbox_request_extra_environment(
    extra_env: &BTreeMap<String, String>,
    helper_socket: &Path,
) -> BTreeMap<String, String> {
    let mut environment = extra_env.clone();
    environment.insert(
        AUTH_HELPER_SOCKET_ENV.into(),
        helper_socket.display().to_string(),
    );
    environment
}

fn repair_runtime_ownership(state: &StatePaths, credentials: PeerCredentials) -> Result<()> {
    if unsafe { libc::geteuid() } != 0 || credentials.uid == 0 {
        return Ok(());
    }
    for path in [
        state.runtime_dir.join("home"),
        state.runtime_dir.join("tmp"),
        state.runtime_dir.join("xdg"),
        state.xdg_state_dir.clone(),
    ] {
        chown_existing_tree(&path, credentials).with_context(|| {
            format!("failed to repair runtime ownership for {}", path.display())
        })?;
    }
    Ok(())
}

fn chown_existing_tree(path: &Path, credentials: PeerCredentials) -> Result<()> {
    let metadata = match fs::symlink_metadata(path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Err(error) => {
            return Err(error).with_context(|| format!("failed to inspect {}", path.display()))
        }
    };
    let owner = metadata.uid();
    if owner != 0 && owner != credentials.uid {
        bail!(
            "refusing to change ownership of {} currently owned by uid {owner}",
            path.display()
        );
    }
    chown_path(path, credentials)?;
    if !metadata.is_dir() || metadata.file_type().is_symlink() {
        return Ok(());
    }
    for entry in fs::read_dir(path).with_context(|| format!("failed to read {}", path.display()))? {
        let entry = entry?;
        chown_existing_tree(&entry.path(), credentials)?;
    }
    Ok(())
}

fn chown_path(path: &Path, credentials: PeerCredentials) -> Result<()> {
    let path = CString::new(path.as_os_str().as_bytes())
        .with_context(|| format!("path contains NUL: {}", path.display()))?;
    if unsafe { libc::lchown(path.as_ptr(), credentials.uid, credentials.gid) } != 0 {
        return Err(std::io::Error::last_os_error()).context("failed to change ownership");
    }
    Ok(())
}

fn drop_to_peer_credentials(credentials: PeerCredentials) -> Result<()> {
    if unsafe { libc::geteuid() } != 0 || credentials.uid == 0 {
        return Ok(());
    }
    initialize_peer_groups(credentials)?;
    if unsafe { libc::setgid(credentials.gid) } != 0 {
        return Err(std::io::Error::last_os_error()).with_context(|| {
            format!(
                "failed to drop helper group privileges to {}",
                credentials.gid
            )
        });
    }
    if unsafe { libc::setuid(credentials.uid) } != 0 {
        return Err(std::io::Error::last_os_error()).with_context(|| {
            format!(
                "failed to drop helper user privileges to {}",
                credentials.uid
            )
        });
    }
    crate::kernel::capabilities::restore_dumpable_after_privilege_drop()
        .context("failed to restore helper process dumpability after privilege drop")?;
    Ok(())
}

fn restore_caller_user_environment(caller_env: &BTreeMap<String, String>) -> Result<()> {
    for key in caller_env.keys() {
        if !crate::app::env::USER_ENV_KEYS.contains(&key.as_str()) {
            bail!("invalid caller environment key `{key}`");
        }
    }
    for key in crate::app::env::USER_ENV_KEYS {
        if let Some(value) = caller_env.get(*key) {
            std::env::set_var(key, value);
        } else {
            std::env::remove_var(key);
        }
    }
    Ok(())
}

fn initialize_peer_groups(credentials: PeerCredentials) -> Result<()> {
    let passwd = unsafe { libc::getpwuid(credentials.uid) };
    if passwd.is_null() {
        return Ok(());
    }
    let username = unsafe { (*passwd).pw_name };
    if username.is_null() {
        return Ok(());
    }
    if unsafe { libc::initgroups(username, credentials.gid) } != 0 {
        return Err(std::io::Error::last_os_error()).with_context(|| {
            format!(
                "failed to initialize helper supplementary groups for uid {}",
                credentials.uid
            )
        });
    }
    Ok(())
}

fn read_run_sandbox_result(path: &Path) -> Result<HelperRunSandboxResult> {
    let content = fs::read_to_string(path)
        .with_context(|| format!("failed to read helper run result {}", path.display()))?;
    serde_json::from_str(&content).context("failed to parse helper run result")
}

fn write_run_sandbox_result(path: &Path, result: &HelperRunSandboxResult) -> Result<()> {
    fs::write(path, serde_json::to_string_pretty(result)?)
        .with_context(|| format!("failed to write helper run result {}", path.display()))
}

fn sibling_condom_runner_path() -> Result<PathBuf> {
    let helper_path = std::env::current_exe().context("failed to resolve helper binary path")?;
    let runner_path = helper_path.with_file_name("condom");
    if runner_path.is_file() {
        return Ok(runner_path);
    }
    bail!(
        "helper cannot locate sibling condom runner `{}`",
        runner_path.display()
    )
}

fn state_base_from_snapshot_path(path: &Path) -> Option<PathBuf> {
    path.parent()
        .and_then(Path::parent)
        .and_then(Path::parent)
        .and_then(Path::parent)
        .map(Path::to_path_buf)
}

pub(super) fn configured_execution_socket_path() -> Result<Option<PathBuf>> {
    if helper_reentry_disabled() {
        return Ok(None);
    }
    if std::env::var_os(HELPER_SOCKET_ENV).is_some() {
        return Ok(Some(configured_helper_socket_path()));
    }
    if std::env::var_os(HELPER_ENV).is_some() {
        return Ok(None);
    }
    let default_socket = PathBuf::from(DEFAULT_HELPER_SOCKET);
    if !default_socket.exists() {
        return Ok(None);
    }
    if helper_socket_is_ready(&default_socket)? {
        return Ok(Some(default_socket));
    }
    Ok(None)
}

fn request_socket_sandbox(
    path: &Path,
    request: HelperRunSandboxRequest,
    snapshot: &policy::PolicySnapshot,
) -> Result<i32> {
    let response = request_helper_socket_with_fds(
        path,
        &HelperRequest::RunSandbox { request },
        &[libc::STDIN_FILENO, libc::STDOUT_FILENO, libc::STDERR_FILENO],
    )?;
    match response {
        HelperResponse::SandboxRunFinished {
            policy_snapshot_id,
            exit_code,
            ..
        } if policy_snapshot_id == snapshot.id.to_string() => Ok(exit_code),
        HelperResponse::SandboxRunFinished {
            policy_snapshot_id, ..
        } => bail!(
            "helper run result policy snapshot mismatch: expected `{}`, got `{}`",
            snapshot.id,
            policy_snapshot_id
        ),
        HelperResponse::MissingCapabilities {
            missing_capabilities,
            message,
        } => bail!(
            "{message}: {}",
            missing_capabilities
                .iter()
                .map(ToString::to_string)
                .collect::<Vec<_>>()
                .join(", ")
        ),
        HelperResponse::UnsupportedProtocol { expected, actual } => {
            bail!("helper protocol mismatch: expected {expected}, got {actual}")
        }
        HelperResponse::InvalidRequest { message }
        | HelperResponse::NotInstalled { message }
        | HelperResponse::CredentialUnavailable { reason: message } => {
            bail!("helper refused sandbox execution request: {message}")
        }
        HelperResponse::Ready { .. } => {
            bail!("helper returned probe response to sandbox execution request")
        }
        HelperResponse::SandboxPrepared { .. } => {
            bail!("helper returned preparation response to sandbox execution request")
        }
        HelperResponse::FilesystemAuthorization { .. } => {
            bail!("helper returned filesystem authorization response to sandbox execution request")
        }
        HelperResponse::Credential { .. } => {
            bail!("helper returned credential response to sandbox execution request")
        }
    }
}

fn runtime_path_for_helper_request(
    mode: ExecutionMode,
    project: &ProjectContext,
    state: &StatePaths,
) -> Option<String> {
    let source = crate::app::env::current_environment();
    let environment = crate::model::config::EnvironmentConfig::default();
    let env = crate::app::env::sanitized_environment(&source, mode, project, state, &environment);
    env.get("PATH").cloned()
}

fn helper_socket_has_capability(path: &Path, capability: HelperCapability) -> Result<bool> {
    helper_probe_has_capability(probe_helper_socket(path), capability)
}

fn helper_socket_is_ready(path: &Path) -> Result<bool> {
    match probe_helper_socket(path) {
        HelperProbe::Ready { .. } => Ok(true),
        HelperProbe::Missing { .. } => Ok(false),
        HelperProbe::Incompatible {
            expected, actual, ..
        } => bail!("helper protocol mismatch: expected {expected}, got {actual}"),
        HelperProbe::Failed { message, .. } => bail!("{message}"),
    }
}

fn helper_binary_has_capability(path: &Path, capability: HelperCapability) -> Result<bool> {
    helper_probe_has_capability(probe_helper(path), capability)
}

pub(super) fn helper_probe_has_capability(
    probe: HelperProbe,
    capability: HelperCapability,
) -> Result<bool> {
    match probe {
        HelperProbe::Ready { capabilities, .. } => Ok(capabilities.contains(&capability)),
        HelperProbe::Missing { .. } => Ok(false),
        HelperProbe::Incompatible {
            expected, actual, ..
        } => bail!("helper protocol mismatch: expected {expected}, got {actual}"),
        HelperProbe::Failed { message, .. } => bail!("{message}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;
    use std::sync::Mutex;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn restore_caller_user_environment_replaces_root_values_and_removes_absent_keys() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_home = std::env::var_os("HOME");
        let previous_user = std::env::var_os("USER");
        let previous_xdg_config_home = std::env::var_os("XDG_CONFIG_HOME");
        let previous_xdg_runtime_dir = std::env::var_os("XDG_RUNTIME_DIR");
        let previous_dbus = std::env::var_os("DBUS_SESSION_BUS_ADDRESS");
        let previous_display = std::env::var_os("DISPLAY");
        let previous_wayland_display = std::env::var_os("WAYLAND_DISPLAY");
        let previous_xauthority = std::env::var_os("XAUTHORITY");
        std::env::set_var("HOME", "/root");
        std::env::set_var("USER", "root");
        std::env::set_var("XDG_CONFIG_HOME", "/root/.config");
        std::env::set_var("XDG_RUNTIME_DIR", "/run/user/0");
        std::env::set_var("DBUS_SESSION_BUS_ADDRESS", "unix:path=/run/user/0/bus");
        std::env::set_var("DISPLAY", ":1");
        std::env::set_var("WAYLAND_DISPLAY", "wayland-0");
        std::env::set_var("XAUTHORITY", "/root/.Xauthority");

        restore_caller_user_environment(&BTreeMap::from([
            ("HOME".into(), "/home/caller".into()),
            ("USER".into(), "caller".into()),
            ("DISPLAY".into(), ":0".into()),
            ("XAUTHORITY".into(), "/home/caller/.Xauthority".into()),
            ("XDG_RUNTIME_DIR".into(), "/run/user/1000".into()),
            (
                "DBUS_SESSION_BUS_ADDRESS".into(),
                "unix:path=/run/user/1000/bus".into(),
            ),
        ]))
        .unwrap();

        assert_eq!(std::env::var("HOME").as_deref(), Ok("/home/caller"));
        assert_eq!(std::env::var("USER").as_deref(), Ok("caller"));
        assert_eq!(
            std::env::var("XDG_RUNTIME_DIR").as_deref(),
            Ok("/run/user/1000")
        );
        assert_eq!(
            std::env::var("DBUS_SESSION_BUS_ADDRESS").as_deref(),
            Ok("unix:path=/run/user/1000/bus")
        );
        assert_eq!(std::env::var("DISPLAY").as_deref(), Ok(":0"));
        assert_eq!(
            std::env::var("XAUTHORITY").as_deref(),
            Ok("/home/caller/.Xauthority")
        );
        assert!(std::env::var_os("XDG_CONFIG_HOME").is_none());
        assert!(std::env::var_os("WAYLAND_DISPLAY").is_none());

        restore_env("HOME", previous_home);
        restore_env("USER", previous_user);
        restore_env("XDG_CONFIG_HOME", previous_xdg_config_home);
        restore_env("XDG_RUNTIME_DIR", previous_xdg_runtime_dir);
        restore_env("DBUS_SESSION_BUS_ADDRESS", previous_dbus);
        restore_env("DISPLAY", previous_display);
        restore_env("WAYLAND_DISPLAY", previous_wayland_display);
        restore_env("XAUTHORITY", previous_xauthority);
    }

    #[test]
    fn restore_caller_user_environment_rejects_unowned_keys() {
        let error =
            restore_caller_user_environment(&BTreeMap::from([("LD_PRELOAD".into(), "x".into())]))
                .expect_err("unowned caller env key should be rejected");

        assert!(format!("{error:#}").contains("invalid caller environment key"));
    }

    #[test]
    fn helper_binary_artifacts_remove_request_and_result_files_on_drop() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state_base = temp.path().join("state");
        let state = StatePaths::from_base(&project, &state_base);
        fs::create_dir_all(&state.xdg_state_dir).unwrap();
        let artifacts = HelperBinaryArtifacts::new(&state, ExecutionMode::Run, "run");
        let request_path = artifacts.request_path().to_path_buf();
        let result_path = artifacts.result_path().to_path_buf();
        fs::write(&request_path, "{}").unwrap();
        fs::write(&result_path, "{}").unwrap();

        drop(artifacts);

        assert!(!request_path.exists());
        assert!(!result_path.exists());
    }

    #[test]
    fn helper_request_file_is_private_while_present() {
        let temp = tempfile::tempdir().unwrap();
        let request_path = temp.path().join("request.json");
        let request = HelperRunSandboxRequest {
            protocol_version: HELPER_PROTOCOL_VERSION,
            kind: HelperSandboxKind::Run,
            project_root: "/project".into(),
            project_id: "project-id".into(),
            state_root: Some("/state".into()),
            caller_uid: 1000,
            caller_gid: 1000,
            caller_env: BTreeMap::from([("HOME".into(), "/home/caller".into())]),
            mode: ExecutionMode::Run,
            command: vec!["true".into()],
            policy_snapshot_id: "snapshot-id".into(),
            extra_env: BTreeMap::new(),
            runtime_path: None,
            ephemeral_overlays: Vec::new(),
            result_path: Some(temp.path().join("result.json").display().to_string()),
        };

        write_helper_request_file(&request_path, &request, "run").unwrap();

        let mode = fs::metadata(&request_path).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o600);
    }

    #[test]
    fn sandbox_extra_environment_disables_nested_helper_execution() {
        let environment = sandbox_extra_environment(&BTreeMap::from([
            (
                AUTH_HELPER_SOCKET_ENV.into(),
                "/run/condom/helper.sock".into(),
            ),
            (DISABLE_HELPER_REENTRY_ENV.into(), "0".into()),
            ("CONDOM_DEBUG".into(), "1".into()),
        ]));

        assert_eq!(
            environment.get(DISABLE_HELPER_REENTRY_ENV),
            Some(&"1".into())
        );
        assert_eq!(
            environment.get(AUTH_HELPER_SOCKET_ENV),
            Some(&"/run/condom/helper.sock".into())
        );
        assert_eq!(environment.get("CONDOM_DEBUG"), Some(&"1".into()));
    }

    #[test]
    fn sandbox_request_extra_environment_sets_authorization_helper_socket() {
        let environment = sandbox_request_extra_environment(
            &BTreeMap::from([(AUTH_HELPER_SOCKET_ENV.into(), "/tmp/ignored.sock".into())]),
            Path::new("/run/condom/helper.sock"),
        );

        assert_eq!(
            environment.get(AUTH_HELPER_SOCKET_ENV),
            Some(&"/run/condom/helper.sock".into())
        );
    }

    fn restore_env(key: &str, value: Option<std::ffi::OsString>) {
        if let Some(value) = value {
            std::env::set_var(key, value);
        } else {
            std::env::remove_var(key);
        }
    }
}
