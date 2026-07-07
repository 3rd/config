use super::*;

use crate::auth::prompt;

pub fn handle_request(request: HelperRequest) -> HelperResponse {
    match request {
        HelperRequest::Probe { protocol_version } => validate_protocol(protocol_version),
        HelperRequest::PrepareSandbox {
            protocol_version,
            project_root,
            project_id,
            state_root,
            policy_snapshot_id,
        } => {
            if protocol_version != HELPER_PROTOCOL_VERSION {
                validate_protocol(protocol_version)
            } else {
                prepare_sandbox_request(project_root, project_id, state_root, policy_snapshot_id)
            }
        }
        HelperRequest::AuthorizeFilesystem {
            protocol_version,
            project_root,
            project_id,
            state_root,
            mode,
            command,
            kind,
            path,
            policy_snapshot_id,
            prompt_environment,
            caller_env,
        } => {
            if protocol_version != HELPER_PROTOCOL_VERSION {
                validate_protocol(protocol_version)
            } else {
                authorize_filesystem_request(FilesystemAuthorizationRequest {
                    project_root,
                    project_id,
                    state_root,
                    mode,
                    command,
                    kind,
                    path,
                    policy_snapshot_id,
                    prompt_environment,
                    caller_env,
                })
            }
        }
        HelperRequest::Credential {
            protocol_version,
            project_root,
            scheme,
            host,
            port,
            method,
            path,
        } => {
            if protocol_version != HELPER_PROTOCOL_VERSION {
                validate_protocol(protocol_version)
            } else {
                credential_request(project_root, scheme, host, port, method, path)
            }
        }
        HelperRequest::RunSandbox { .. } => invalid_request_response(
            "run-sandbox requests require socket stdio fd passing or the run-sandbox subcommand"
                .into(),
        ),
    }
}

fn prepare_sandbox_request(
    project_root: String,
    project_id: String,
    state_root: Option<String>,
    policy_snapshot_id: String,
) -> HelperResponse {
    let requested_root = PathBuf::from(&project_root);
    if !requested_root.is_dir() {
        return invalid_request_response(format!(
            "project root `{project_root}` is not a directory"
        ));
    }
    let project = match requested_project(requested_root, project_id) {
        Ok(project) => project,
        Err(error) => {
            return invalid_request_response(format!(
                "failed to resolve project root `{project_root}`: {error:#}"
            ));
        }
    };
    let state = state_root
        .map(|root| StatePaths::from_base(&project, &PathBuf::from(root)))
        .unwrap_or_else(|| StatePaths::from_environment(&project));
    let snapshot = match load_policy_snapshot(&project, &state, &policy_snapshot_id) {
        Ok(snapshot) => snapshot,
        Err(message) => return invalid_request_response(message),
    };

    let capabilities = helper_capabilities();
    let missing_capabilities = missing_required_capabilities_for_snapshot(&snapshot, &capabilities);
    if missing_capabilities.is_empty() {
        return HelperResponse::SandboxPrepared {
            protocol_version: HELPER_PROTOCOL_VERSION,
            policy_snapshot_id: snapshot.id.to_string(),
            capabilities,
            runner: "fence-landlock-seccomp".into(),
        };
    }

    HelperResponse::MissingCapabilities {
        missing_capabilities,
        message: "root supervisor sandbox preparation is missing required capabilities".into(),
    }
}

pub(super) fn invalid_request_response(message: String) -> HelperResponse {
    HelperResponse::InvalidRequest { message }
}

pub(super) fn requested_project(root: PathBuf, project_id: String) -> Result<ProjectContext> {
    validate_project_identifier(&project_id)?;
    let mut project = ProjectContext::from_root(root)?;
    project.id = project_id;
    Ok(project)
}

// project_id is attacker-influenceable and is joined into privileged state
// paths (e.g. `<state_root>/condom/<project_id>`); reject path traversal.
fn validate_project_identifier(project_id: &str) -> Result<()> {
    if project_id.is_empty()
        || project_id.contains('/')
        || project_id.contains('\0')
        || project_id.contains("..")
    {
        bail!("invalid project id `{project_id}`");
    }
    Ok(())
}

struct FilesystemAuthorizationRequest {
    pub(super) project_root: String,
    pub(super) project_id: String,
    pub(super) state_root: Option<String>,
    pub(super) mode: ExecutionMode,
    pub(super) command: Vec<String>,
    pub(super) kind: ApprovalKind,
    pub(super) path: String,
    pub(super) policy_snapshot_id: Option<String>,
    pub(super) prompt_environment: BTreeMap<String, String>,
    pub(super) caller_env: BTreeMap<String, String>,
}

fn authorize_filesystem_request(request: FilesystemAuthorizationRequest) -> HelperResponse {
    let FilesystemAuthorizationRequest {
        project_root,
        project_id,
        state_root,
        mode,
        command,
        kind,
        path,
        policy_snapshot_id,
        prompt_environment,
        caller_env: _caller_env,
    } = request;
    let prompt_environment = prompt_environment_with_current_defaults(prompt_environment);
    let project = match requested_project(PathBuf::from(&project_root), project_id) {
        Ok(project) => project,
        Err(error) => {
            return filesystem_authorization_response(
                FilesystemAuthorization::from_transport_parts(
                    ApprovalDecision::Deny,
                    format!("failed to resolve project root `{project_root}`: {error:#}"),
                    suggested_allow(kind, &path),
                    Vec::new(),
                    false,
                ),
            );
        }
    };
    let state = state_root
        .map(|root| StatePaths::from_base(&project, &PathBuf::from(root)))
        .unwrap_or_else(|| StatePaths::from_environment(&project));
    let global_config = default_global_config_path(
        std::env::var_os("XDG_CONFIG_HOME").map(PathBuf::from),
        std::env::var_os("HOME").map(PathBuf::from),
    );
    let config = match CondomConfig::load(&project.root, global_config.as_deref()) {
        Ok(config) => config,
        Err(error) => {
            return filesystem_authorization_response(
                FilesystemAuthorization::from_transport_parts(
                    ApprovalDecision::Deny,
                    format!("failed to load project config: {error:#}"),
                    suggested_allow(kind, &path),
                    Vec::new(),
                    false,
                ),
            );
        }
    };
    let event_log = EventLog::new(state.events_file.clone());
    let policy_snapshot = match policy_snapshot_id {
        Some(id) => match load_policy_snapshot(&project, &state, &id) {
            Ok(snapshot) => Some(snapshot),
            Err(message) => return invalid_request_response(message),
        },
        None => None,
    };
    match authorize_filesystem_access(FilesystemAuthorizationContext {
        config: &config,
        project: &project,
        state: &state,
        mode,
        command: &command,
        kind,
        subject: &path,
        policy_snapshot: policy_snapshot.as_ref(),
        prompt_environment: Some(&prompt_environment),
        event_log: &event_log,
    }) {
        Ok(authorization) => filesystem_authorization_response(authorization),
        Err(error) => {
            filesystem_authorization_response(FilesystemAuthorization::from_transport_parts(
                ApprovalDecision::Deny,
                format!("failed to authorize filesystem access: {error:#}"),
                suggested_allow(kind, &path),
                Vec::new(),
                false,
            ))
        }
    }
}

fn prompt_environment_with_current_defaults(
    mut prompt_environment: BTreeMap<String, String>,
) -> BTreeMap<String, String> {
    if prompt_environment.is_empty() {
        return prompt_environment;
    }
    for (key, value) in prompt::approval_prompt_environment() {
        prompt_environment.entry(key).or_insert(value);
    }
    prompt_environment
}

fn credential_request(
    project_root: String,
    scheme: String,
    host: String,
    port: u16,
    method: String,
    path: String,
) -> HelperResponse {
    let project = match ProjectContext::from_root(PathBuf::from(&project_root)) {
        Ok(project) => project,
        Err(error) => {
            return HelperResponse::CredentialUnavailable {
                reason: format!("failed to resolve project root `{project_root}`: {error:#}"),
            };
        }
    };
    let global_config = default_global_config_path(
        std::env::var_os("XDG_CONFIG_HOME").map(PathBuf::from),
        std::env::var_os("HOME").map(PathBuf::from),
    );
    let config = match CondomConfig::load(&project.root, global_config.as_deref()) {
        Ok(config) => config,
        Err(error) => {
            return HelperResponse::CredentialUnavailable {
                reason: format!("failed to load project config: {error:#}"),
            };
        }
    };
    let credential_source = match config.proxy.credential_source {
        CredentialSource::Helper if config.proxy.credential_file.is_some() => {
            CredentialSource::HostFile
        }
        CredentialSource::Helper => CredentialSource::HostFilesEnv,
        other => other,
    };
    let provider = ConfiguredCredentialProvider::from_current_environment(
        credential_source,
        config.proxy.credential_file.as_deref().map(Path::new),
        config.proxy.credential_command.as_deref(),
        config.proxy.credential_pass_prefix.as_deref(),
        config.proxy.credential_secret_service.as_deref(),
        &project.root,
    );
    match provider.credential_for(&CredentialRequest {
        scheme,
        host,
        port,
        method,
        path,
    }) {
        Ok(Some(credential)) => HelperResponse::Credential {
            header_name: credential.header_name,
            header_value: credential.header_value,
        },
        Ok(None) => HelperResponse::CredentialUnavailable {
            reason: "no helper credential matched request host".into(),
        },
        Err(error) => HelperResponse::CredentialUnavailable {
            reason: format!("credential lookup failed: {error}"),
        },
    }
}

pub(super) fn load_policy_snapshot(
    project: &ProjectContext,
    state: &StatePaths,
    policy_snapshot_id: &str,
) -> std::result::Result<policy::PolicySnapshot, String> {
    let snapshot_id = uuid::Uuid::parse_str(policy_snapshot_id)
        .map_err(|error| format!("invalid policy snapshot id `{policy_snapshot_id}`: {error}"))?;
    let snapshot_path = policy::snapshot_path(state, snapshot_id);
    let snapshot = policy::read_snapshot(&snapshot_path).map_err(|error| {
        format!("failed to load policy snapshot `{policy_snapshot_id}`: {error:#}")
    })?;
    if snapshot.id != snapshot_id {
        return Err(format!(
            "policy snapshot id mismatch: request named `{policy_snapshot_id}` but snapshot contains `{}`",
            snapshot.id
        ));
    }
    if snapshot.project_id != project.id
        || snapshot.project_root != project.root.display().to_string()
    {
        return Err("policy snapshot does not belong to requested project root".into());
    }
    Ok(snapshot)
}

fn filesystem_authorization_response(authorization: FilesystemAuthorization) -> HelperResponse {
    let cacheable = authorization.is_cacheable();
    HelperResponse::FilesystemAuthorization {
        decision: authorization.decision,
        reason: authorization.reason,
        cacheable,
        suggested_allow: authorization.suggested_allow,
        cache_entries: authorization.cache_entries,
    }
}

pub(super) fn suggested_allow(kind: ApprovalKind, path: &str) -> Option<String> {
    if kind.filesystem_action().is_some() {
        Some(format!("condom allow add {} {path}", kind.cli_name()))
    } else {
        None
    }
}

pub fn read_request(mut reader: impl Read) -> Result<HelperRequest> {
    let mut content = String::new();
    reader
        .read_to_string(&mut content)
        .context("failed to read helper request")?;
    serde_json::from_str(&content).context("failed to parse helper request")
}

pub fn write_response(mut writer: impl Write, response: &HelperResponse) -> Result<()> {
    writeln!(writer, "{}", serde_json::to_string_pretty(response)?)
        .context("failed to write helper response")
}

pub fn is_broken_pipe_error(error: &anyhow::Error) -> bool {
    error.chain().any(|cause| {
        cause
            .downcast_ref::<std::io::Error>()
            .is_some_and(|error| error.kind() == std::io::ErrorKind::BrokenPipe)
    })
}

pub fn request_filesystem_authorization(
    endpoint: &HelperEndpoint,
    request: &HelperRequest,
) -> Result<FilesystemAuthorization> {
    let response = match endpoint {
        HelperEndpoint::Socket(path) => {
            let request = request_with_prompt_tty_fd(request);
            crate::debug_log!(
                "helper filesystem authorization endpoint=socket path={} stdin_tty={} prompt_tty_fd={} prompt_tty_path={}",
                path.display(),
                unsafe { libc::isatty(libc::STDIN_FILENO) } == 1,
                request_prompt_environment_has(&request, prompt::PROMPT_TTY_FD_ENV),
                request_prompt_environment_has(&request, prompt::PROMPT_TTY_PATH_ENV),
            );
            request_helper_socket_with_fds(
                path,
                &request,
                &[libc::STDIN_FILENO, libc::STDOUT_FILENO, libc::STDERR_FILENO],
            )?
        }
        HelperEndpoint::Binary(_) => {
            crate::debug_log!("helper filesystem authorization endpoint=binary");
            request_helper(endpoint, request)?
        }
    };
    log_filesystem_authorization_response(&response);
    match response {
        HelperResponse::FilesystemAuthorization {
            decision,
            reason,
            cacheable,
            suggested_allow,
            cache_entries,
        } => Ok(FilesystemAuthorization::from_transport_parts(
            decision,
            reason,
            suggested_allow,
            cache_entries,
            cacheable,
        )),
        HelperResponse::UnsupportedProtocol { expected, actual } => {
            bail!("helper protocol mismatch: expected {expected}, got {actual}")
        }
        HelperResponse::InvalidRequest { message }
        | HelperResponse::NotInstalled { message }
        | HelperResponse::MissingCapabilities { message, .. } => {
            bail!("helper refused filesystem authorization request: {message}")
        }
        HelperResponse::Ready { .. } => {
            bail!("helper returned probe response to filesystem authorization request")
        }
        HelperResponse::SandboxPrepared { .. } => {
            bail!(
                "helper returned sandbox preparation response to filesystem authorization request"
            )
        }
        HelperResponse::SandboxRunFinished { .. } => {
            bail!("helper returned sandbox execution response to filesystem authorization request")
        }
        HelperResponse::Credential { .. } | HelperResponse::CredentialUnavailable { .. } => {
            bail!("helper returned credential response to filesystem authorization request")
        }
    }
}

fn request_with_prompt_tty_fd(request: &HelperRequest) -> HelperRequest {
    request_with_prompt_tty_fd_for_stdin(request, unsafe { libc::isatty(libc::STDIN_FILENO) } == 1)
}

fn request_with_prompt_tty_fd_for_stdin(
    request: &HelperRequest,
    stdin_is_tty: bool,
) -> HelperRequest {
    if !stdin_is_tty {
        crate::debug_log!("not adding prompt tty fd because stdin is not a tty");
        return request.clone();
    }
    let HelperRequest::AuthorizeFilesystem {
        protocol_version,
        project_root,
        project_id,
        state_root,
        mode,
        command,
        kind,
        path,
        policy_snapshot_id,
        prompt_environment,
        caller_env,
    } = request
    else {
        return request.clone();
    };
    let mut prompt_environment = prompt_environment.clone();
    let had_prompt_tty_fd = prompt_environment
        .get(prompt::PROMPT_TTY_FD_ENV)
        .is_some_and(|value| !value.is_empty());
    prompt_environment
        .entry(prompt::PROMPT_TTY_FD_ENV.into())
        .or_insert_with(|| libc::STDIN_FILENO.to_string());
    crate::debug_log!(
        "helper filesystem authorization prompt tty fd forwarded={}",
        !had_prompt_tty_fd,
    );
    HelperRequest::AuthorizeFilesystem {
        protocol_version: *protocol_version,
        project_root: project_root.clone(),
        project_id: project_id.clone(),
        state_root: state_root.clone(),
        mode: *mode,
        command: command.clone(),
        kind: *kind,
        path: path.clone(),
        policy_snapshot_id: policy_snapshot_id.clone(),
        prompt_environment,
        caller_env: caller_env.clone(),
    }
}

fn request_prompt_environment_has(request: &HelperRequest, key: &str) -> bool {
    let HelperRequest::AuthorizeFilesystem {
        prompt_environment, ..
    } = request
    else {
        return false;
    };
    prompt_environment
        .get(key)
        .is_some_and(|value| !value.is_empty())
}

fn log_filesystem_authorization_response(response: &HelperResponse) {
    match response {
        HelperResponse::FilesystemAuthorization {
            decision,
            cacheable,
            ..
        } => {
            crate::debug_log!(
                "helper filesystem authorization response=decision decision={decision:?} cacheable={cacheable}",
            );
        }
        response => {
            crate::debug_log!(
                "helper filesystem authorization response={}",
                helper_response_kind(response),
            );
        }
    }
}

fn helper_response_kind(response: &HelperResponse) -> &'static str {
    match response {
        HelperResponse::Ready { .. } => "ready",
        HelperResponse::SandboxPrepared { .. } => "sandbox-prepared",
        HelperResponse::MissingCapabilities { .. } => "missing-capabilities",
        HelperResponse::UnsupportedProtocol { .. } => "unsupported-protocol",
        HelperResponse::NotInstalled { .. } => "not-installed",
        HelperResponse::InvalidRequest { .. } => "invalid-request",
        HelperResponse::FilesystemAuthorization { .. } => "filesystem-authorization",
        HelperResponse::Credential { .. } => "credential",
        HelperResponse::CredentialUnavailable { .. } => "credential-unavailable",
        HelperResponse::SandboxRunFinished { .. } => "sandbox-run-finished",
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    fn restore_env(key: &str, value: Option<std::ffi::OsString>) {
        if let Some(value) = value {
            std::env::set_var(key, value);
        } else {
            std::env::remove_var(key);
        }
    }

    #[test]
    fn request_with_prompt_tty_fd_injects_stdin_fd_when_tty() {
        let request = HelperRequest::AuthorizeFilesystem {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: "/tmp/project".into(),
            project_id: "project-id".into(),
            state_root: Some("/tmp/state".into()),
            mode: ExecutionMode::Run,
            command: vec!["tool".into()],
            kind: ApprovalKind::FsRead,
            path: "/home/user/.agent/config.toml".into(),
            policy_snapshot_id: None,
            prompt_environment: BTreeMap::new(),
            caller_env: BTreeMap::from([
                ("HOME".into(), "/home/user".into()),
                ("XDG_RUNTIME_DIR".into(), "/run/user/1000".into()),
            ]),
        };

        let request = request_with_prompt_tty_fd_for_stdin(&request, true);
        let HelperRequest::AuthorizeFilesystem {
            prompt_environment, ..
        } = request
        else {
            panic!("expected filesystem authorization request");
        };

        assert_eq!(
            prompt_environment.get(prompt::PROMPT_TTY_FD_ENV),
            Some(&libc::STDIN_FILENO.to_string())
        );
    }

    #[test]
    fn request_with_prompt_tty_fd_preserves_caller_environment() {
        let caller_env = BTreeMap::from([
            ("HOME".into(), "/home/user".into()),
            (
                "DBUS_SESSION_BUS_ADDRESS".into(),
                "unix:path=/run/user/1000/bus".into(),
            ),
            ("XDG_RUNTIME_DIR".into(), "/run/user/1000".into()),
        ]);
        let request = HelperRequest::AuthorizeFilesystem {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: "/tmp/project".into(),
            project_id: "project-id".into(),
            state_root: Some("/tmp/state".into()),
            mode: ExecutionMode::Run,
            command: vec!["tool".into()],
            kind: ApprovalKind::FsRead,
            path: "/home/user/.agent/config.toml".into(),
            policy_snapshot_id: None,
            prompt_environment: BTreeMap::new(),
            caller_env: caller_env.clone(),
        };

        let request = request_with_prompt_tty_fd_for_stdin(&request, true);
        let HelperRequest::AuthorizeFilesystem {
            caller_env: preserved,
            ..
        } = request
        else {
            panic!("expected filesystem authorization request");
        };

        assert_eq!(preserved, caller_env);
    }

    #[test]
    fn prompt_environment_fills_missing_desktop_values_from_current_env() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_display = std::env::var_os("DISPLAY");
        let previous_xauthority = std::env::var_os("XAUTHORITY");
        let previous_runtime_dir = std::env::var_os("XDG_RUNTIME_DIR");
        std::env::set_var("DISPLAY", ":0");
        std::env::set_var("XAUTHORITY", "/home/user/.Xauthority");
        std::env::set_var("XDG_RUNTIME_DIR", "/run/user/1000");

        let environment = prompt_environment_with_current_defaults(BTreeMap::from([(
            prompt::PROMPT_TTY_PATH_ENV.into(),
            "/dev/pts/7".into(),
        )]));

        assert_eq!(
            environment
                .get(prompt::PROMPT_TTY_PATH_ENV)
                .map(String::as_str),
            Some("/dev/pts/7")
        );
        assert_eq!(
            environment
                .get(prompt::APPROVAL_DISPLAY_ENV)
                .map(String::as_str),
            Some(":0")
        );
        assert_eq!(
            environment
                .get(prompt::APPROVAL_XAUTHORITY_ENV)
                .map(String::as_str),
            Some("/home/user/.Xauthority")
        );
        assert_eq!(
            environment
                .get(prompt::APPROVAL_XDG_RUNTIME_DIR_ENV)
                .map(String::as_str),
            Some("/run/user/1000")
        );

        restore_env("DISPLAY", previous_display);
        restore_env("XAUTHORITY", previous_xauthority);
        restore_env("XDG_RUNTIME_DIR", previous_runtime_dir);
    }

    #[test]
    fn prompt_environment_keeps_empty_request_environment_empty() {
        let environment = prompt_environment_with_current_defaults(BTreeMap::new());

        assert!(environment.is_empty());
    }

    #[test]
    fn validate_project_identifier_rejects_path_traversal() {
        assert!(validate_project_identifier("4fe5f8c015dba2573657dcd1").is_ok());
        assert!(validate_project_identifier("").is_err());
        assert!(validate_project_identifier("a/b").is_err());
        assert!(validate_project_identifier("../../etc").is_err());
        assert!(validate_project_identifier("x..y").is_err());
    }
}
