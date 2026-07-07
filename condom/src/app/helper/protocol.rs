use super::*;

pub const HELPER_PROTOCOL_VERSION: u32 = 6;

pub const HELPER_ENV: &str = "CONDOM_HELPER";

pub const HELPER_SOCKET_ENV: &str = "CONDOM_HELPER_SOCKET";

pub const DISABLE_HELPER_REENTRY_ENV: &str = "CONDOM_INTERNAL_DISABLE_HELPER_REENTRY";

pub const AUTH_HELPER_SOCKET_ENV: &str = "CONDOM_INTERNAL_AUTH_HELPER_SOCKET";

pub const DEFAULT_HELPER_SOCKET: &str = "/run/condom/helper.sock";

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum HelperCapability {
    MountIsolation,
    ProcessRestrictions,
    SyscallRestrictions,
    NetworkRouting,
    EphemeralOverlays,
}

impl fmt::Display for HelperCapability {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let value = match self {
            Self::MountIsolation => "mount-isolation",
            Self::ProcessRestrictions => "process-restrictions",
            Self::SyscallRestrictions => "syscall-restrictions",
            Self::NetworkRouting => "network-routing",
            Self::EphemeralOverlays => "ephemeral-overlays",
        };
        formatter.write_str(value)
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
pub enum HelperRequest {
    Probe {
        #[serde(rename = "protocolVersion")]
        protocol_version: u32,
    },
    PrepareSandbox {
        #[serde(rename = "protocolVersion")]
        protocol_version: u32,
        #[serde(rename = "projectRoot")]
        project_root: String,
        #[serde(rename = "projectId")]
        project_id: String,
        #[serde(rename = "stateRoot", default)]
        state_root: Option<String>,
        #[serde(rename = "policySnapshotId")]
        policy_snapshot_id: String,
    },
    AuthorizeFilesystem {
        #[serde(rename = "protocolVersion")]
        protocol_version: u32,
        #[serde(rename = "projectRoot")]
        project_root: String,
        #[serde(rename = "projectId")]
        project_id: String,
        #[serde(rename = "stateRoot", default)]
        state_root: Option<String>,
        mode: ExecutionMode,
        command: Vec<String>,
        kind: ApprovalKind,
        path: String,
        #[serde(rename = "policySnapshotId", default)]
        policy_snapshot_id: Option<String>,
        #[serde(rename = "promptEnvironment")]
        prompt_environment: BTreeMap<String, String>,
        #[serde(rename = "callerEnv", default)]
        caller_env: BTreeMap<String, String>,
    },
    Credential {
        #[serde(rename = "protocolVersion")]
        protocol_version: u32,
        #[serde(rename = "projectRoot")]
        project_root: String,
        scheme: String,
        host: String,
        port: u16,
        method: String,
        path: String,
    },
    RunSandbox {
        #[serde(flatten)]
        request: HelperRunSandboxRequest,
    },
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
pub enum HelperResponse {
    Ready {
        #[serde(rename = "protocolVersion")]
        protocol_version: u32,
        #[serde(rename = "helperVersion")]
        helper_version: String,
        capabilities: Vec<HelperCapability>,
    },
    SandboxPrepared {
        #[serde(rename = "protocolVersion")]
        protocol_version: u32,
        #[serde(rename = "policySnapshotId")]
        policy_snapshot_id: String,
        capabilities: Vec<HelperCapability>,
        runner: String,
    },
    MissingCapabilities {
        #[serde(rename = "missingCapabilities")]
        missing_capabilities: Vec<HelperCapability>,
        message: String,
    },
    UnsupportedProtocol {
        expected: u32,
        actual: u32,
    },
    NotInstalled {
        message: String,
    },
    InvalidRequest {
        message: String,
    },
    FilesystemAuthorization {
        decision: ApprovalDecision,
        reason: String,
        #[serde(default, skip_serializing_if = "is_false")]
        cacheable: bool,
        #[serde(rename = "suggestedAllow")]
        suggested_allow: Option<String>,
        #[serde(
            default,
            rename = "cacheEntries",
            skip_serializing_if = "Vec::is_empty"
        )]
        cache_entries: Vec<FilesystemAuthorizationCacheEntry>,
    },
    Credential {
        #[serde(rename = "headerName")]
        header_name: String,
        #[serde(rename = "headerValue")]
        header_value: String,
    },
    CredentialUnavailable {
        reason: String,
    },
    SandboxRunFinished {
        #[serde(rename = "protocolVersion")]
        protocol_version: u32,
        #[serde(rename = "policySnapshotId")]
        policy_snapshot_id: String,
        #[serde(rename = "exitCode")]
        exit_code: i32,
        runner: String,
    },
}

fn is_false(value: &bool) -> bool {
    !*value
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum HelperEndpoint {
    Socket(PathBuf),
    Binary(PathBuf),
}

pub fn validate_protocol(actual: u32) -> HelperResponse {
    if actual == HELPER_PROTOCOL_VERSION {
        HelperResponse::Ready {
            protocol_version: HELPER_PROTOCOL_VERSION,
            helper_version: crate::VERSION.to_string(),
            capabilities: helper_capabilities(),
        }
    } else {
        HelperResponse::UnsupportedProtocol {
            expected: HELPER_PROTOCOL_VERSION,
            actual,
        }
    }
}

pub(crate) fn request_helper(
    endpoint: &HelperEndpoint,
    request: &HelperRequest,
) -> Result<HelperResponse> {
    match endpoint {
        HelperEndpoint::Socket(path) => request_helper_socket(path, request),
        HelperEndpoint::Binary(path) => request_helper_binary(path, request),
    }
}

fn request_helper_socket(path: &Path, request: &HelperRequest) -> Result<HelperResponse> {
    let mut stream = UnixStream::connect(path)
        .with_context(|| format!("failed to connect to helper socket `{}`", path.display()))?;
    serde_json::to_writer(&mut stream, request)
        .context("failed to write helper filesystem authorization request")?;
    stream
        .shutdown(Shutdown::Write)
        .context("failed to finish helper filesystem authorization request")?;
    let mut output = Vec::new();
    stream
        .read_to_end(&mut output)
        .context("failed to read helper filesystem authorization response")?;
    serde_json::from_slice(&output)
        .context("failed to parse helper filesystem authorization response")
}

pub(super) fn request_helper_socket_with_fds(
    path: &Path,
    request: &HelperRequest,
    fds: &[RawFd],
) -> Result<HelperResponse> {
    let stream = UnixStream::connect(path)
        .with_context(|| format!("failed to connect to helper socket `{}`", path.display()))?;
    let payload = serde_json::to_vec(request).context("failed to encode helper socket request")?;
    send_json_with_fds(&stream, &payload, fds).context("failed to send helper socket request")?;
    stream
        .shutdown(Shutdown::Write)
        .context("failed to finish helper socket request")?;
    let mut output = Vec::new();
    (&stream)
        .read_to_end(&mut output)
        .context("failed to read helper socket response")?;
    serde_json::from_slice(&output).context("failed to parse helper socket response")
}

fn send_json_with_fds(stream: &UnixStream, payload: &[u8], fds: &[RawFd]) -> Result<()> {
    let mut iov = libc::iovec {
        iov_base: payload.as_ptr().cast::<libc::c_void>().cast_mut(),
        iov_len: payload.len(),
    };
    let mut control = vec![0_u8; cmsg_space_for_fds(fds.len())];
    let mut message: libc::msghdr = unsafe { std::mem::zeroed() };
    message.msg_iov = &mut iov;
    message.msg_iovlen = 1;
    if !fds.is_empty() {
        message.msg_control = control.as_mut_ptr().cast();
        message.msg_controllen = control.len();
        let cmsg = unsafe { libc::CMSG_FIRSTHDR(&message) };
        if cmsg.is_null() {
            bail!("failed to allocate helper socket control message");
        }
        unsafe {
            (*cmsg).cmsg_level = libc::SOL_SOCKET;
            (*cmsg).cmsg_type = libc::SCM_RIGHTS;
            (*cmsg).cmsg_len = cmsg_len_for_fds(fds.len());
            std::ptr::copy_nonoverlapping(
                fds.as_ptr().cast::<u8>(),
                libc::CMSG_DATA(cmsg).cast::<u8>(),
                std::mem::size_of_val(fds),
            );
        }
    }
    let sent = unsafe { libc::sendmsg(stream.as_raw_fd(), &message, 0) };
    if sent < 0 {
        return Err(std::io::Error::last_os_error()).context("sendmsg failed");
    }
    if (sent as usize) < payload.len() {
        let mut tail = stream
            .try_clone()
            .context("failed to clone helper socket")?;
        tail.write_all(&payload[sent as usize..])
            .context("failed to send remaining helper socket request")?;
    }
    Ok(())
}

fn request_helper_binary(path: &Path, request: &HelperRequest) -> Result<HelperResponse> {
    let mut child = Command::new(path)
        .arg("request")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .with_context(|| format!("failed to start helper `{}`", path.display()))?;
    {
        let stdin = child
            .stdin
            .as_mut()
            .context("failed to open helper request stdin")?;
        serde_json::to_writer(stdin, request)
            .context("failed to write helper filesystem authorization request")?;
    }
    let output = child
        .wait_with_output()
        .context("failed to read helper filesystem authorization response")?;
    if !output.status.success() {
        bail!(
            "helper `{}` exited with status {}; stderr: {}",
            path.display(),
            output.status,
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }
    serde_json::from_slice(&output.stdout)
        .context("failed to parse helper filesystem authorization response")
}
