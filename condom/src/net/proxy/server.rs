use super::*;

pub const PROXY_CONTRACT_VERSION: u32 = 1;

const ACCEPT_SLEEP: Duration = Duration::from_millis(25);

pub(super) const IO_TIMEOUT: Duration = Duration::from_secs(30);

const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

pub(super) const MAX_PROXY_CLIENT_WORKERS: usize = 64;

pub(super) const MAX_PROXY_REQUEST_BODY_BYTES: usize = 16 * 1024 * 1024;

const MAX_PROXY_REQUEST_LINE_BYTES: usize = 8 * 1024;
const MAX_PROXY_REQUEST_HEADER_LINE_BYTES: usize = 8 * 1024;
const MAX_PROXY_REQUEST_HEADER_BYTES: usize = 64 * 1024;
pub(super) const MAX_PROXY_REQUEST_HEADERS: usize = 100;
const MAX_PROXY_RESPONSE_HEADER_BYTES: usize = 64 * 1024;

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ProxyAdapter {
    Npm,
    PyPi,
    Cargo,
    Go,
    GenericHttp,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CredentialLease {
    pub adapter: ProxyAdapter,
    pub upstream: String,
    pub header_name: String,
    pub expires_at: Option<DateTime<Utc>>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct NpmRegistryRoute {
    pub scope: Option<String>,
    pub registry: String,
    pub has_credential: bool,
}

pub struct ProxyGuard {
    pub(super) addr: SocketAddr,
    pub(super) transparent_enabled: bool,
    pub(super) transparent_tcp_ports: Vec<u16>,
    pub(super) transparent_allowed_hosts: Vec<String>,
    pub(super) running: Arc<AtomicBool>,
    pub(super) handle: Option<JoinHandle<()>>,
}

impl ProxyGuard {
    pub fn addr(&self) -> SocketAddr {
        self.addr
    }

    pub fn port(&self) -> u16 {
        self.addr.port()
    }

    pub fn allowed_network_ports(&self) -> Vec<u16> {
        let mut ports = vec![self.port()];
        if self.transparent_enabled {
            ports.extend(self.transparent_tcp_ports.clone());
        }
        ports.sort_unstable();
        ports.dedup();
        ports
    }

    pub fn transparent_proxy_snapshot(&self) -> TransparentProxySnapshot {
        TransparentProxySnapshot {
            enabled: self.transparent_enabled,
            tcp_ports: if self.transparent_enabled {
                self.transparent_tcp_ports.clone()
            } else {
                Vec::new()
            },
            allowed_hosts: if self.transparent_enabled {
                self.transparent_allowed_hosts.clone()
            } else {
                Vec::new()
            },
        }
    }
}

impl Drop for ProxyGuard {
    fn drop(&mut self) {
        self.running.store(false, Ordering::SeqCst);
        let _ = TcpStream::connect_timeout(&self.addr, Duration::from_millis(100));
        if let Some(handle) = self.handle.take() {
            let _ = handle.join();
        }
    }
}

pub fn start_proxy(
    config: &CondomConfig,
    project: &ProjectContext,
    state: &StatePaths,
    mode: ExecutionMode,
    command: &[String],
    event_log: &EventLog,
) -> Result<ProxyGuard> {
    let listen_config = proxy_listen_config_from_env()?;
    let proxy_listener = bind_proxy_listener(&listen_config)?;
    let listener = proxy_listener.listener;
    listener
        .set_nonblocking(true)
        .context("failed to configure local condom proxy")?;
    let addr = listener
        .local_addr()
        .context("failed to read local condom proxy address")?;
    if config.events.require_logging {
        event_log.append(&Event::proxy_decision(
            project,
            mode,
            command,
            &addr.to_string(),
            Decision::Proxied,
            proxy_listener.start_reason,
        ))?;
    }

    let running = Arc::new(AtomicBool::new(true));
    let policy = ProxyPolicy::from_config(config, project, state);
    prune_proxy_cache(&policy.cache_dir, policy.cache_ttl, Utc::now());
    let thread_running = Arc::clone(&running);
    let worker_context = ProxyWorkerContext {
        policy,
        project: project.clone(),
        mode,
        command: command.to_vec(),
        event_log: event_log.clone(),
    };
    let handle = thread::spawn(move || {
        run_proxy_loop(listener, thread_running, worker_context);
    });

    Ok(ProxyGuard {
        addr,
        transparent_enabled: proxy_listener.transparent_enabled,
        transparent_tcp_ports: listen_config.transparent_tcp_ports,
        transparent_allowed_hosts: transparent_allowed_hosts(config),
        running,
        handle: Some(handle),
    })
}

pub(super) fn parse_env_port(value: Option<&std::ffi::OsStr>) -> Result<Option<u16>> {
    let Some(value) = value.and_then(|value| value.to_str()) else {
        return Ok(None);
    };
    let port = value
        .parse::<u16>()
        .with_context(|| format!("invalid {} value `{value}`", tproxy::PORT_ENV))?;
    Ok(Some(port))
}

pub(super) struct BoundProxyListener {
    pub(super) listener: TcpListener,
    pub(super) transparent_enabled: bool,
    pub(super) start_reason: &'static str,
}

fn bind_proxy_listener(config: &ProxyListenConfig) -> Result<BoundProxyListener> {
    bind_proxy_listener_with(config, bind_transparent_listener)
}

pub(super) fn bind_proxy_listener_with(
    config: &ProxyListenConfig,
    bind_transparent: impl FnOnce(SocketAddr) -> io::Result<TcpListener>,
) -> Result<BoundProxyListener> {
    match bind_transparent(config.addr) {
        Ok(listener) => Ok(BoundProxyListener {
            listener,
            transparent_enabled: true,
            start_reason: config.start_reason(),
        }),
        Err(error) if error.raw_os_error() == Some(libc::EADDRINUSE) => Err(error).with_context(
            || {
                format!(
                    "transparent proxy port {} is already in use; refusing to run without transparent network enforcement",
                    config.addr
                )
            },
        ),
        Err(error) => Err(error).with_context(|| {
            format!(
                "failed to bind transparent condom proxy on {}; ensure the NixOS module installed the cap_net_admin wrapper",
                config.addr
            )
        }),
    }
}

pub(super) fn close_fd(fd: RawFd) {
    unsafe {
        libc::close(fd);
    }
}

pub fn child_environment(
    project: &ProjectContext,
    state: &StatePaths,
    addr: SocketAddr,
    proxy: &ProxyConfig,
) -> Result<BTreeMap<String, String>> {
    let proxy_url = format!("http://{addr}");
    let mut env = BTreeMap::new();
    let configured_adapters = &proxy.adapters;
    if adapter_enabled(
        configured_adapters,
        &["generic-http", "generic", "http", "https"],
    ) {
        insert_proxy_vars(
            &mut env,
            &proxy_url,
            &[
                "HTTP_PROXY",
                "HTTPS_PROXY",
                "ALL_PROXY",
                "http_proxy",
                "https_proxy",
                "all_proxy",
                "CONDOM_HTTP_PROXY",
                "CONDOM_HTTPS_PROXY",
                "CONDOM_ALL_PROXY",
            ],
        );
    }
    if adapter_enabled(configured_adapters, &["npm", "npm-compatible"]) {
        let npmrc = materialize_npm_adapter_config(project, state, &proxy_url, proxy)?;
        let cache_dir = state.runtime_dir.join("xdg/cache/npm");
        fs::create_dir_all(&cache_dir)
            .with_context(|| format!("failed to create {}", cache_dir.display()))?;
        insert_proxy_vars(
            &mut env,
            &proxy_url,
            &[
                "NPM_CONFIG_PROXY",
                "NPM_CONFIG_HTTPS_PROXY",
                "npm_config_proxy",
                "npm_config_https_proxy",
            ],
        );
        insert_npm_config_vars(&mut env, "USERCONFIG", &npmrc.display().to_string());
        insert_npm_config_vars(&mut env, "GLOBALCONFIG", &npmrc.display().to_string());
        insert_npm_config_vars(&mut env, "CACHE", &cache_dir.display().to_string());
        if let Some(registry) = &proxy.npm_registry {
            insert_npm_config_vars(&mut env, "REGISTRY", registry);
        }
        if proxy.npm_ignore_scripts {
            insert_npm_config_vars(&mut env, "IGNORE_SCRIPTS", "true");
        }
        insert_npm_config_vars(&mut env, "ALWAYS_AUTH", "false");
        insert_npm_config_vars(&mut env, "NOPROXY", "");
    }
    if adapter_enabled(configured_adapters, &["pypi", "pip", "python"]) {
        let pip_conf = materialize_pip_adapter_config(state, &proxy_url, proxy)?;
        insert_proxy_vars(&mut env, &proxy_url, &["PIP_PROXY"]);
        env.insert("PIP_CONFIG_FILE".into(), pip_conf.display().to_string());
        if proxy.pip_no_input {
            env.insert("PIP_NO_INPUT".into(), "1".into());
        }
        if proxy.pip_disable_version_check {
            env.insert("PIP_DISABLE_PIP_VERSION_CHECK".into(), "1".into());
        }
        if let Some(index_url) = &proxy.pip_index_url {
            env.insert("PIP_INDEX_URL".into(), index_url.clone());
        }
    }
    if adapter_enabled(configured_adapters, &["cargo", "crates"]) {
        let cargo_home = materialize_cargo_adapter_config(state, &proxy_url, proxy)?;
        insert_proxy_vars(&mut env, &proxy_url, &["CARGO_HTTP_PROXY"]);
        env.insert("CARGO_HOME".into(), cargo_home.display().to_string());
        env.insert("CARGO_NET_OFFLINE".into(), "false".into());
    }
    if adapter_enabled(configured_adapters, &["go", "golang"]) {
        let go_config = materialize_go_adapter_config(state, proxy)?;
        env.insert("GOENV".into(), go_config.env_file.display().to_string());
        env.insert(
            "GOMODCACHE".into(),
            go_config.module_cache.display().to_string(),
        );
        env.insert(
            "GOCACHE".into(),
            go_config.build_cache.display().to_string(),
        );
        if let Some(go_auth) = &proxy.go_auth {
            env.insert("GOAUTH".into(), go_auth.clone());
        }
        if let Some(go_proxy) = &proxy.go_proxy {
            env.insert("GOPROXY".into(), go_proxy.clone());
        }
        if let Some(go_sumdb) = &proxy.go_sumdb {
            env.insert("GOSUMDB".into(), go_sumdb.clone());
        }
        if let Some(go_vcs) = &proxy.go_vcs {
            env.insert("GOVCS".into(), go_vcs.clone());
        }
    }
    env.insert("NO_PROXY".into(), String::new());
    env.insert("no_proxy".into(), String::new());
    Ok(env)
}

fn insert_proxy_vars(env: &mut BTreeMap<String, String>, proxy_url: &str, keys: &[&str]) {
    for key in keys {
        env.insert((*key).into(), proxy_url.into());
    }
}

fn insert_npm_config_vars(env: &mut BTreeMap<String, String>, key: &str, value: &str) {
    env.insert(format!("NPM_CONFIG_{key}"), value.into());
    env.insert(
        format!("npm_config_{}", key.to_ascii_lowercase()),
        value.into(),
    );
}

fn adapter_enabled(configured_adapters: &[String], aliases: &[&str]) -> bool {
    configured_adapters.iter().any(|adapter| {
        let adapter = adapter.trim().to_ascii_lowercase();
        aliases.iter().any(|alias| adapter == *alias)
    })
}

pub(super) fn materialize_npm_adapter_config(
    project: &ProjectContext,
    state: &StatePaths,
    proxy_url: &str,
    proxy: &ProxyConfig,
) -> Result<PathBuf> {
    let project_npmrc = project.root.join(".npmrc");
    let source = match fs::read_to_string(&project_npmrc) {
        Ok(content) => content,
        Err(error) if error.kind() == io::ErrorKind::NotFound => String::new(),
        Err(error) => {
            return Err(error)
                .with_context(|| format!("failed to read {}", project_npmrc.display()));
        }
    };
    let npm_dir = state.runtime_dir.join("xdg/config/npm");
    fs::create_dir_all(&npm_dir)
        .with_context(|| format!("failed to create {}", npm_dir.display()))?;
    let npmrc = npm_dir.join("npmrc");
    fs::write(
        &npmrc,
        sanitize_npmrc(
            &source,
            proxy_url,
            proxy.npm_registry.as_deref(),
            proxy.npm_ignore_scripts,
        ),
    )
    .with_context(|| format!("failed to write {}", npmrc.display()))?;
    Ok(npmrc)
}

pub(super) fn materialize_pip_adapter_config(
    state: &StatePaths,
    proxy_url: &str,
    proxy: &ProxyConfig,
) -> Result<PathBuf> {
    let pip_dir = state.runtime_dir.join("xdg/config/pip");
    fs::create_dir_all(&pip_dir)
        .with_context(|| format!("failed to create {}", pip_dir.display()))?;
    let pip_conf = pip_dir.join("pip.conf");
    fs::write(&pip_conf, sanitized_pip_conf(proxy_url, proxy))
        .with_context(|| format!("failed to write {}", pip_conf.display()))?;
    Ok(pip_conf)
}

fn sanitized_pip_conf(proxy_url: &str, proxy: &ProxyConfig) -> String {
    let mut rendered = format!("[global]\nproxy = {proxy_url}\n");
    if let Some(index_url) = &proxy.pip_index_url {
        rendered.push_str(&format!("index-url = {index_url}\n"));
    }
    if proxy.pip_no_input {
        rendered.push_str("no-input = true\n");
    }
    if proxy.pip_disable_version_check {
        rendered.push_str("disable-pip-version-check = true\n");
    }
    rendered
}

pub(super) fn materialize_cargo_adapter_config(
    state: &StatePaths,
    proxy_url: &str,
    proxy: &ProxyConfig,
) -> Result<PathBuf> {
    let cargo_home = state.runtime_dir.join("xdg/cache/cargo");
    fs::create_dir_all(&cargo_home)
        .with_context(|| format!("failed to create {}", cargo_home.display()))?;
    let config = cargo_home.join("config.toml");
    fs::write(&config, sanitized_cargo_config(proxy_url, proxy))
        .with_context(|| format!("failed to write {}", config.display()))?;
    Ok(cargo_home)
}

fn sanitized_cargo_config(proxy_url: &str, proxy: &ProxyConfig) -> String {
    let mut rendered = format!("[http]\nproxy = \"{proxy_url}\"\n");
    if let Some(git_fetch_with_cli) = proxy.cargo_git_fetch_with_cli {
        rendered.push_str(&format!(
            "\n[net]\ngit-fetch-with-cli = {git_fetch_with_cli}\n"
        ));
    }
    rendered
}

pub(super) struct GoAdapterConfig {
    pub(super) env_file: PathBuf,
    pub(super) module_cache: PathBuf,
    pub(super) build_cache: PathBuf,
}

pub(super) fn materialize_go_adapter_config(
    state: &StatePaths,
    proxy: &ProxyConfig,
) -> Result<GoAdapterConfig> {
    let go_config_dir = state.runtime_dir.join("xdg/config/go");
    let go_cache_dir = state.runtime_dir.join("xdg/cache/go");
    let module_cache = go_cache_dir.join("mod");
    let build_cache = go_cache_dir.join("build");
    fs::create_dir_all(&go_config_dir)
        .with_context(|| format!("failed to create {}", go_config_dir.display()))?;
    fs::create_dir_all(&module_cache)
        .with_context(|| format!("failed to create {}", module_cache.display()))?;
    fs::create_dir_all(&build_cache)
        .with_context(|| format!("failed to create {}", build_cache.display()))?;
    let env_file = go_config_dir.join("env");
    fs::write(
        &env_file,
        sanitized_go_env(&module_cache, &build_cache, proxy),
    )
    .with_context(|| format!("failed to write {}", env_file.display()))?;
    Ok(GoAdapterConfig {
        env_file,
        module_cache,
        build_cache,
    })
}

fn sanitized_go_env(module_cache: &Path, build_cache: &Path, proxy: &ProxyConfig) -> String {
    let mut rendered = format!(
        "GOCACHE={}\nGOMODCACHE={}\n",
        build_cache.display(),
        module_cache.display()
    );
    if let Some(go_auth) = &proxy.go_auth {
        rendered.push_str(&format!("GOAUTH={go_auth}\n"));
    }
    if let Some(go_proxy) = &proxy.go_proxy {
        rendered.push_str(&format!("GOPROXY={go_proxy}\n"));
    }
    if let Some(go_sumdb) = &proxy.go_sumdb {
        rendered.push_str(&format!("GOSUMDB={go_sumdb}\n"));
    }
    if let Some(go_vcs) = &proxy.go_vcs {
        rendered.push_str(&format!("GOVCS={go_vcs}\n"));
    }
    rendered
}

#[derive(Clone, Debug)]
pub(super) struct ProxyPolicy {
    pub(super) allowed_hosts: Vec<String>,
    pub(super) allow_loopback: bool,
    pub(super) deny_metadata: bool,
    pub(super) deny_private: bool,
    pub(super) prompt_mode: PromptMode,
    pub(super) require_logging: bool,
    pub(super) approval_store: ApprovalStores,
    pub(super) instance_prompt_decisions: Arc<Mutex<BTreeMap<String, ApprovalDecision>>>,
    pub(super) credential_provider: ConfiguredCredentialProvider,
    pub(super) cache_dir: PathBuf,
    pub(super) cache_ttl: Duration,
}

impl ProxyPolicy {
    pub(super) fn from_config(
        config: &CondomConfig,
        project: &ProjectContext,
        state: &StatePaths,
    ) -> Self {
        Self {
            allowed_hosts: config.proxy.allowed_hosts.clone(),
            allow_loopback: config.network.allow_loopback,
            deny_metadata: config.network.deny_metadata,
            deny_private: config.network.deny_private,
            prompt_mode: config.defaults.prompt_mode,
            require_logging: config.events.require_logging,
            approval_store: ApprovalStores::from_state(state),
            instance_prompt_decisions: Arc::new(Mutex::new(BTreeMap::new())),
            credential_provider: ConfiguredCredentialProvider::from_current_environment(
                config.proxy.credential_source,
                config.proxy.credential_file.as_deref().map(Path::new),
                config.proxy.credential_command.as_deref(),
                config.proxy.credential_pass_prefix.as_deref(),
                config.proxy.credential_secret_service.as_deref(),
                &project.root,
            ),
            cache_dir: state.xdg_state_dir.join("proxy-cache"),
            cache_ttl: Duration::from_secs(config.proxy.cache_ttl_seconds),
        }
    }

    pub(super) fn authorize_destination(
        &self,
        destination: &Destination,
        context: ProxyDecisionContext<'_>,
    ) -> Result<(), String> {
        match self.classify_host(&destination.host) {
            HostDecision::Allowed => Ok(()),
            HostDecision::Denied(reason) => Err(reason),
            HostDecision::Promptable { host, reason } => {
                self.resolve_promptable_host(&host, destination.port, &reason, context)
            }
        }
    }

    pub(super) fn classify_host(&self, host: &str) -> HostDecision {
        let host = normalize_host(host);
        if self.deny_metadata && is_metadata_host(&host) {
            return HostDecision::Denied("metadata service destinations are denied".into());
        }
        if host == "localhost" {
            return if self.allow_loopback {
                HostDecision::Allowed
            } else {
                HostDecision::Denied("loopback destinations are denied by config".into())
            };
        }
        if let Ok(ip) = host.parse::<IpAddr>() {
            if let Err(reason) = self.validate_ip(ip) {
                return HostDecision::Denied(reason);
            }
            if (ip.is_loopback() && self.allow_loopback) || self.host_allowed(&host) {
                return HostDecision::Allowed;
            }
            return HostDecision::Promptable {
                host: host.clone(),
                reason: format!("host `{host}` is not in proxy allowedHosts"),
            };
        }
        if self.host_allowed(&host) {
            HostDecision::Allowed
        } else {
            HostDecision::Promptable {
                host: host.clone(),
                reason: format!("host `{host}` is not in proxy allowedHosts"),
            }
        }
    }

    pub(super) fn resolve_promptable_host(
        &self,
        host: &str,
        port: u16,
        reason: &str,
        context: ProxyDecisionContext<'_>,
    ) -> Result<(), String> {
        if let Some(result) = self.instance_promptable_host_authorization(host, context) {
            return result;
        }
        if let Some(result) = self.stored_promptable_host_authorization(host, context)? {
            return result;
        }

        if self.prompt_mode == PromptMode::Deny {
            return Err(format!("{reason}; prompt mode is deny"));
        }

        let _prompt_queue = prompt::lock_approval_prompt_queue();
        if let Some(result) = self.instance_promptable_host_authorization(host, context) {
            return result;
        }
        if let Some(result) = self.stored_promptable_host_authorization(host, context)? {
            return result;
        }

        let prompt = ProxyPrompt {
            host: host.to_string(),
            port,
            project_root: context.project.root.display().to_string(),
            command: context.command.to_vec(),
        };
        match prompt::prompt_proxy_destination(&prompt) {
            Ok(Some(decision)) => self.apply_prompt_decision(decision, host, context),
            Ok(None) => Err(format!("{reason}; no approval UI available for prompt")),
            Err(error) => Err(format!("failed to prompt for proxy destination: {error:#}")),
        }
    }

    pub(super) fn instance_promptable_host_authorization(
        &self,
        host: &str,
        context: ProxyDecisionContext<'_>,
    ) -> Option<Result<(), String>> {
        let decision = self
            .instance_prompt_decisions
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .get(host)
            .copied()?;
        Some(match decision {
            ApprovalDecision::Allow => append_approval_event(
                self.event_record_context(context),
                host,
                Decision::Allowed,
                "allowed by instance prompt",
            ),
            ApprovalDecision::Deny => {
                match append_approval_event(
                    self.event_record_context(context),
                    host,
                    Decision::Denied,
                    "denied by instance prompt",
                ) {
                    Ok(()) => Err(format!("host `{host}` is denied by instance prompt")),
                    Err(error) => Err(error),
                }
            }
        })
    }

    pub(super) fn stored_promptable_host_authorization(
        &self,
        host: &str,
        context: ProxyDecisionContext<'_>,
    ) -> Result<Option<Result<(), String>>, String> {
        let app = command_app(context.command);
        crate::debug_log!(
            "proxy approval stored lookup host={} app={} project_id={} project_root={}",
            host,
            app.as_deref().unwrap_or("<none>"),
            context.project.id,
            context.project.root.display(),
        );
        match self.approval_store.resolve_for_app(
            context.project,
            app.as_deref(),
            ApprovalKind::NetDomain,
            host,
        ) {
            Ok(Some(ApprovalDecision::Allow)) => {
                crate::debug_log!("proxy approval stored result=allow host={host}");
                append_approval_event(
                    self.event_record_context(context),
                    host,
                    Decision::Allowed,
                    "allowed by stored approval",
                )?;
                Ok(Some(Ok(())))
            }
            Ok(Some(ApprovalDecision::Deny)) => {
                crate::debug_log!("proxy approval stored result=deny host={host}");
                append_approval_event(
                    self.event_record_context(context),
                    host,
                    Decision::Denied,
                    "denied by stored approval",
                )?;
                Ok(Some(Err(format!(
                    "host `{host}` is denied by stored approval"
                ))))
            }
            Ok(None) => {
                crate::debug_log!("proxy approval stored result=none host={host}");
                Ok(None)
            }
            Err(error) => {
                crate::debug_log!("proxy approval stored result=error host={host} error={error:#}");
                Err(format!("failed to read proxy approvals: {error:#}"))
            }
        }
    }

    pub(super) fn apply_prompt_decision(
        &self,
        decision: PromptDecision,
        host: &str,
        context: ProxyDecisionContext<'_>,
    ) -> Result<(), String> {
        match decision {
            PromptDecision::AllowOnce => {
                append_prompt_event(
                    self.event_record_context(context),
                    host,
                    Decision::Accepted,
                    "allowed once by prompt",
                )?;
                Ok(())
            }
            PromptDecision::AllowInstance => self.apply_instance_prompt_decision(
                ApprovalDecision::Allow,
                host,
                context,
                Decision::Accepted,
                "allowed for instance by prompt",
            ),
            PromptDecision::DenyInstance => self.apply_instance_prompt_decision(
                ApprovalDecision::Deny,
                host,
                context,
                Decision::Rejected,
                "denied for instance by prompt",
            ),
            PromptDecision::AllowAppProject => self.apply_persistent_prompt_decision(
                ApprovalDecision::Allow,
                ApprovalScope::AppProject,
                host,
                context,
                Decision::Accepted,
                "allowed for app/project by prompt",
            ),
            PromptDecision::DenyAppProject => self.apply_persistent_prompt_decision(
                ApprovalDecision::Deny,
                ApprovalScope::AppProject,
                host,
                context,
                Decision::Rejected,
                "denied for app/project by prompt",
            ),
            PromptDecision::AllowProject => self.apply_persistent_prompt_decision(
                ApprovalDecision::Allow,
                ApprovalScope::Project,
                host,
                context,
                Decision::Accepted,
                "allowed for project by prompt",
            ),
            PromptDecision::DenyProject => self.apply_persistent_prompt_decision(
                ApprovalDecision::Deny,
                ApprovalScope::Project,
                host,
                context,
                Decision::Rejected,
                "denied for project by prompt",
            ),
            PromptDecision::DenyOnce => {
                append_prompt_event(
                    self.event_record_context(context),
                    host,
                    Decision::Rejected,
                    "denied once by prompt",
                )?;
                Err(format!("host `{host}` denied by prompt"))
            }
        }
    }

    pub(super) fn apply_instance_prompt_decision(
        &self,
        approval_decision: ApprovalDecision,
        host: &str,
        context: ProxyDecisionContext<'_>,
        event_decision: Decision,
        event_reason: &str,
    ) -> Result<(), String> {
        self.instance_prompt_decisions
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .insert(host.into(), approval_decision);
        append_prompt_event(
            self.event_record_context(context),
            host,
            event_decision,
            event_reason,
        )?;
        match approval_decision {
            ApprovalDecision::Allow => Ok(()),
            ApprovalDecision::Deny => Err(format!("host `{host}` denied by prompt")),
        }
    }

    pub(super) fn apply_persistent_prompt_decision(
        &self,
        approval_decision: ApprovalDecision,
        scope: ApprovalScope,
        host: &str,
        context: ProxyDecisionContext<'_>,
        event_decision: Decision,
        event_reason: &str,
    ) -> Result<(), String> {
        let stored_reason = match approval_decision {
            ApprovalDecision::Allow => "proxy prompt approval",
            ApprovalDecision::Deny => "proxy prompt denial",
        };
        crate::debug_log!(
            "proxy approval persistent store decision={approval_decision:?} scope={scope:?} host={} app={} project_id={} project_root={}",
            host,
            command_app(context.command).as_deref().unwrap_or("<none>"),
            context.project.id,
            context.project.root.display(),
        );
        let approval = Approval::new_for_app(
            context.project,
            NewApproval {
                decision: approval_decision,
                scope,
                kind: ApprovalKind::NetDomain,
                subject: host.to_string(),
                ttl: None,
                once: false,
                reason: Some(stored_reason.into()),
            },
            (scope == ApprovalScope::AppProject)
                .then(|| command_app(context.command))
                .flatten(),
        )
        .map_err(|error| format!("failed to create proxy approval: {error:#}"))?;
        self.approval_store
            .add(approval)
            .map_err(|error| format!("failed to store proxy approval: {error:#}"))?;
        append_prompt_event(
            self.event_record_context(context),
            host,
            event_decision,
            event_reason,
        )?;
        match approval_decision {
            ApprovalDecision::Allow => Ok(()),
            ApprovalDecision::Deny => Err(format!("host `{host}` denied by prompt")),
        }
    }

    pub(super) fn validate_ip(&self, ip: IpAddr) -> Result<(), String> {
        if ip.is_loopback() && self.allow_loopback {
            return Ok(());
        }
        if self.deny_metadata && is_metadata_ip(ip) {
            return Err("metadata service destinations are denied".into());
        }
        if self.deny_private && is_internal_ip(ip) {
            return Err("private network destinations are denied".into());
        }
        Ok(())
    }

    pub(super) fn host_allowed(&self, host: &str) -> bool {
        self.allowed_hosts
            .iter()
            .any(|pattern| host_matches(pattern, host))
    }
}

#[derive(Clone, Copy)]
pub(super) struct ProxyDecisionContext<'a> {
    pub(super) project: &'a ProjectContext,
    pub(super) mode: ExecutionMode,
    pub(super) command: &'a [String],
    pub(super) event_log: &'a EventLog,
}

#[derive(Clone, Copy)]
pub(super) struct EventRecordContext<'a> {
    event_log: &'a EventLog,
    require_logging: bool,
    project: &'a ProjectContext,
    mode: ExecutionMode,
    command: &'a [String],
}

impl ProxyPolicy {
    pub(super) fn event_record_context<'a>(
        &self,
        context: ProxyDecisionContext<'a>,
    ) -> EventRecordContext<'a> {
        EventRecordContext {
            event_log: context.event_log,
            require_logging: self.require_logging,
            project: context.project,
            mode: context.mode,
            command: context.command,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) enum HostDecision {
    Allowed,
    Denied(String),
    Promptable { host: String, reason: String },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) struct ProxyRequest {
    pub(super) method: String,
    pub(super) target: String,
    pub(super) version: String,
    pub(super) headers: Vec<(String, String)>,
    pub(super) body: Vec<u8>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) struct Destination {
    pub(super) scheme: String,
    pub(super) host: String,
    pub(super) port: u16,
    // includes the query string; required verbatim for proxy cache-key uniqueness
    pub(super) path: String,
}

impl Destination {
    pub(super) fn subject(&self) -> String {
        format!("{}:{}", self.host, self.port)
    }

    pub(super) fn authority(&self) -> String {
        if (self.scheme == "http" && self.port == 80)
            || (self.scheme == "https" && self.port == 443)
        {
            self.host.clone()
        } else {
            format!("{}:{}", self.host, self.port)
        }
    }
}

#[derive(Clone)]
pub(super) struct ProxyWorkerContext {
    pub(super) policy: ProxyPolicy,
    pub(super) project: ProjectContext,
    pub(super) mode: ExecutionMode,
    pub(super) command: Vec<String>,
    pub(super) event_log: EventLog,
}

impl ProxyWorkerContext {
    pub(super) fn event_record_context(&self) -> EventRecordContext<'_> {
        EventRecordContext {
            event_log: &self.event_log,
            require_logging: self.policy.require_logging,
            project: &self.project,
            mode: self.mode,
            command: &self.command,
        }
    }
}

fn run_proxy_loop(listener: TcpListener, running: Arc<AtomicBool>, context: ProxyWorkerContext) {
    let active_workers = Arc::new(AtomicUsize::new(0));
    while running.load(Ordering::SeqCst) {
        match listener.accept() {
            Ok((stream, _peer)) => {
                handle_accepted_proxy_client(stream, &active_workers, context.clone())
            }
            Err(error) if error.kind() == io::ErrorKind::WouldBlock => {
                thread::sleep(ACCEPT_SLEEP);
            }
            Err(_error) => {
                if running.load(Ordering::SeqCst) {
                    thread::sleep(ACCEPT_SLEEP);
                }
            }
        }
    }
}

pub(super) fn handle_accepted_proxy_client(
    mut stream: TcpStream,
    active_workers: &Arc<AtomicUsize>,
    context: ProxyWorkerContext,
) {
    let Some(worker) = try_acquire_proxy_worker(active_workers) else {
        let _ = write_proxy_error(&mut stream, 503, "proxy worker limit reached");
        return;
    };
    thread::spawn(move || {
        let _worker = worker;
        handle_transparent_client(stream, context);
    });
}

pub(super) struct ActiveProxyWorker {
    pub(super) active_workers: Arc<AtomicUsize>,
}

impl Drop for ActiveProxyWorker {
    fn drop(&mut self) {
        self.active_workers.fetch_sub(1, Ordering::SeqCst);
    }
}

pub(super) fn try_acquire_proxy_worker(
    active_workers: &Arc<AtomicUsize>,
) -> Option<ActiveProxyWorker> {
    let mut active = active_workers.load(Ordering::SeqCst);
    loop {
        if active >= MAX_PROXY_CLIENT_WORKERS {
            return None;
        }
        match active_workers.compare_exchange_weak(
            active,
            active + 1,
            Ordering::SeqCst,
            Ordering::SeqCst,
        ) {
            Ok(_) => {
                return Some(ActiveProxyWorker {
                    active_workers: Arc::clone(active_workers),
                });
            }
            Err(current) => active = current,
        }
    }
}

pub(super) fn looks_like_http_request(buffer: &[u8]) -> bool {
    const METHODS: &[&[u8]] = &[
        b"GET ",
        b"POST ",
        b"HEAD ",
        b"PUT ",
        b"DELETE ",
        b"PATCH ",
        b"OPTIONS ",
        b"CONNECT ",
        b"TRACE ",
    ];
    METHODS.iter().any(|method| buffer.starts_with(method))
}

pub(super) fn read_proxy_request<R: BufRead>(reader: &mut R) -> io::Result<Option<ProxyRequest>> {
    let Some(first_line) =
        read_limited_line(reader, MAX_PROXY_REQUEST_LINE_BYTES, "proxy request line")?
    else {
        return Ok(None);
    };
    let first_line = first_line.trim_end_matches(['\r', '\n']);
    let mut parts = first_line.split_whitespace();
    let method = parts
        .next()
        .ok_or_else(|| invalid_data("missing request method"))?
        .to_string();
    let target = parts
        .next()
        .ok_or_else(|| invalid_data("missing request target"))?
        .to_string();
    let version = parts
        .next()
        .ok_or_else(|| invalid_data("missing request version"))?
        .to_string();

    let mut headers = Vec::new();
    let mut header_bytes = 0usize;
    let mut content_length = 0usize;
    while let Some(line) = read_limited_line(
        reader,
        MAX_PROXY_REQUEST_HEADER_LINE_BYTES,
        "proxy request header line",
    )? {
        header_bytes = header_bytes.saturating_add(line.len());
        if header_bytes > MAX_PROXY_REQUEST_HEADER_BYTES {
            return Err(invalid_data("proxy request headers exceed size limit"));
        }
        let line = line.trim_end_matches(['\r', '\n']);
        if line.is_empty() {
            break;
        }
        if headers.len() >= MAX_PROXY_REQUEST_HEADERS {
            return Err(invalid_data("proxy request has too many headers"));
        }
        let (name, value) = line
            .split_once(':')
            .ok_or_else(|| invalid_data("malformed header"))?;
        if name.eq_ignore_ascii_case("content-length") {
            content_length = value
                .trim()
                .parse()
                .map_err(|_| invalid_data("invalid Content-Length header"))?;
            if content_length > MAX_PROXY_REQUEST_BODY_BYTES {
                return Err(invalid_data("proxy request body exceeds size limit"));
            }
        }
        headers.push((name.trim().to_string(), value.trim().to_string()));
    }

    let mut body = vec![0; content_length];
    if content_length > 0 {
        reader.read_exact(&mut body)?;
    }
    Ok(Some(ProxyRequest {
        method,
        target,
        version,
        headers,
        body,
    }))
}

fn read_limited_line<R: BufRead>(
    reader: &mut R,
    max_bytes: usize,
    description: &str,
) -> io::Result<Option<String>> {
    let mut bytes = Vec::new();
    loop {
        let available = reader.fill_buf()?;
        if available.is_empty() {
            if bytes.is_empty() {
                return Ok(None);
            }
            break;
        }
        let take = available
            .iter()
            .position(|byte| *byte == b'\n')
            .map(|position| position + 1)
            .unwrap_or(available.len());
        if bytes.len().saturating_add(take) > max_bytes {
            return Err(invalid_data(&format!("{description} exceeds size limit")));
        }
        bytes.extend_from_slice(&available[..take]);
        reader.consume(take);
        if bytes.last() == Some(&b'\n') {
            break;
        }
    }
    String::from_utf8(bytes)
        .map(Some)
        .map_err(|_| invalid_data("proxy request was not utf-8"))
}

pub(super) fn destination_from_request(request: &ProxyRequest) -> Result<Destination, String> {
    if request.method.eq_ignore_ascii_case("CONNECT") {
        let (host, port) = parse_authority(&request.target, 443)?;
        return Ok(Destination {
            scheme: "https".into(),
            host,
            port,
            path: String::new(),
        });
    }
    if let Some(destination) = parse_absolute_target(&request.target)? {
        return Ok(destination);
    }
    let host = header_value(&request.headers, "host")
        .ok_or_else(|| "origin-form proxy request is missing Host header".to_string())?;
    let (host, port) = parse_authority(host, 80)?;
    Ok(Destination {
        scheme: "http".into(),
        host,
        port,
        path: if request.target.starts_with('/') {
            request.target.clone()
        } else {
            format!("/{}", request.target)
        },
    })
}

fn parse_absolute_target(target: &str) -> Result<Option<Destination>, String> {
    let lower = target.to_ascii_lowercase();
    let (scheme, rest, default_port) = if lower.starts_with("http://") {
        ("http", &target[7..], 80)
    } else if lower.starts_with("https://") {
        ("https", &target[8..], 443)
    } else {
        return Ok(None);
    };
    let split_at = rest
        .find(|ch| ['/', '?'].contains(&ch))
        .unwrap_or(rest.len());
    let (authority, path) = rest.split_at(split_at);
    let (host, port) = parse_authority(authority, default_port)?;
    Ok(Some(Destination {
        scheme: scheme.into(),
        host,
        port,
        path: if path.is_empty() {
            "/".into()
        } else {
            path.into()
        },
    }))
}

fn parse_authority(authority: &str, default_port: u16) -> Result<(String, u16), String> {
    let authority = authority.trim();
    let authority = authority
        .rsplit_once('@')
        .map(|(_, host)| host)
        .unwrap_or(authority);
    if authority.is_empty() {
        return Err("empty proxy destination host".into());
    }
    if let Some(rest) = authority.strip_prefix('[') {
        let Some((host, suffix)) = rest.split_once(']') else {
            return Err("malformed IPv6 destination host".into());
        };
        let port = if let Some(port) = suffix.strip_prefix(':') {
            parse_port(port)?
        } else {
            default_port
        };
        return Ok((normalize_host(host), port));
    }
    if let Some((host, port)) = authority.rsplit_once(':') {
        if port.chars().all(|ch| ch.is_ascii_digit()) {
            return Ok((normalize_host(host), parse_port(port)?));
        }
    }
    Ok((normalize_host(authority), default_port))
}

fn parse_port(port: &str) -> Result<u16, String> {
    port.parse::<u16>()
        .map_err(|_| format!("invalid destination port `{port}`"))
}

pub(super) fn forward_http_request(
    client_writer: &mut TcpStream,
    request: &ProxyRequest,
    destination: &Destination,
    policy: &ProxyPolicy,
) -> io::Result<()> {
    let credential_request = credential_request(request, destination);
    let credential = policy
        .credential_provider
        .credential_for(&credential_request)
        .map_err(|error| {
            io::Error::new(
                io::ErrorKind::PermissionDenied,
                format!("credential lookup failed: {error}"),
            )
        })?;
    let cacheable =
        proxy_cacheable_request(request) && credential.is_none() && policy.cache_ttl.as_secs() > 0;
    let mut cached_entry = None;
    if cacheable {
        if let Some(entry) = read_cached_proxy_entry(&policy.cache_dir, destination) {
            if !proxy_cache_stale(&entry.metadata, policy.cache_ttl, Utc::now()) {
                client_writer.write_all(&entry.response)?;
                return Ok(());
            }
            cached_entry = Some(entry);
        }
    }

    let mut upstream = connect_destination(policy, destination)?;
    write!(
        upstream,
        "{} {} {}\r\n",
        request.method, destination.path, request.version
    )?;
    let mut saw_host = false;
    let mut wrote_if_none_match = false;
    let mut wrote_if_modified_since = false;
    for (name, value) in &request.headers {
        let lower = name.to_ascii_lowercase();
        if matches!(
            lower.as_str(),
            "proxy-connection"
                | "proxy-authorization"
                | "authorization"
                | "connection"
                | "if-none-match"
                | "if-modified-since"
        ) {
            continue;
        }
        if lower == "host" {
            saw_host = true;
        }
        write!(upstream, "{name}: {value}\r\n")?;
    }
    if !saw_host {
        write!(upstream, "Host: {}\r\n", destination.authority())?;
    }
    if let Some(credential) = credential {
        write!(
            upstream,
            "{}: {}\r\n",
            credential.header_name, credential.header_value
        )?;
    }
    if let Some(entry) = &cached_entry {
        if let Some(etag) = &entry.metadata.etag {
            write!(upstream, "If-None-Match: {etag}\r\n")?;
            wrote_if_none_match = true;
        }
        if let Some(last_modified) = &entry.metadata.last_modified {
            write!(upstream, "If-Modified-Since: {last_modified}\r\n")?;
            wrote_if_modified_since = true;
        }
    }
    if !wrote_if_none_match && !wrote_if_modified_since {
        if cached_entry.is_some() {
            remove_cached_proxy_entry(&policy.cache_dir, destination);
        }
        cached_entry = None;
    }
    write!(upstream, "Connection: close\r\n\r\n")?;
    upstream.write_all(&request.body)?;
    upstream.flush()?;
    let response_head = read_upstream_response_head(&mut upstream)?;
    if cacheable && proxy_response_status_is(&response_head, 304) {
        if let Some(entry) = cached_entry {
            refresh_cached_proxy_metadata(
                &policy.cache_dir,
                destination,
                &entry.metadata,
                &response_head,
                Utc::now(),
            );
            client_writer.write_all(&entry.response)?;
            return Ok(());
        }
    }
    let capture_for_cache = cacheable && proxy_cacheable_response(&response_head);
    client_writer.write_all(&response_head)?;
    let response = stream_upstream_response_body(
        &mut upstream,
        client_writer,
        response_head,
        capture_for_cache,
    )?;
    if let Some(response) = response.filter(|response| proxy_cacheable_response(response)) {
        write_cached_proxy_response(&policy.cache_dir, destination, &response, Utc::now());
    }
    Ok(())
}

#[cfg(test)]
pub(super) fn read_upstream_response_with_limit<R: Read>(
    upstream: &mut R,
    max_bytes: usize,
) -> io::Result<Vec<u8>> {
    let mut response = Vec::new();
    let mut buffer = [0u8; 8192];
    loop {
        let read = upstream.read(&mut buffer)?;
        if read == 0 {
            return Ok(response);
        }
        if response.len().saturating_add(read) > max_bytes {
            return Err(invalid_data("proxy upstream response exceeds size limit"));
        }
        response.extend_from_slice(&buffer[..read]);
    }
}

fn read_upstream_response_head<R: Read>(upstream: &mut R) -> io::Result<Vec<u8>> {
    let mut head = Vec::new();
    let mut byte = [0u8; 1];
    loop {
        let read = upstream.read(&mut byte)?;
        if read == 0 {
            return Err(invalid_data("proxy upstream response ended before headers"));
        }
        head.push(byte[0]);
        if head.len() > MAX_PROXY_RESPONSE_HEADER_BYTES {
            return Err(invalid_data(
                "proxy upstream response headers exceed size limit",
            ));
        }
        if head.ends_with(b"\r\n\r\n") {
            return Ok(head);
        }
    }
}

fn stream_upstream_response_body<R: Read, W: Write>(
    upstream: &mut R,
    client_writer: &mut W,
    response_head: Vec<u8>,
    capture_for_cache: bool,
) -> io::Result<Option<Vec<u8>>> {
    let mut cached_response = capture_for_cache.then_some(response_head);
    let mut buffer = [0u8; 8192];
    loop {
        let read = upstream.read(&mut buffer)?;
        if read == 0 {
            return Ok(cached_response);
        }
        client_writer.write_all(&buffer[..read])?;
        if let Some(response) = cached_response.as_mut() {
            if response.len().saturating_add(read) > MAX_PROXY_CACHED_RESPONSE_BYTES {
                cached_response = None;
            } else {
                response.extend_from_slice(&buffer[..read]);
            }
        }
    }
}

pub(super) fn tunnel_connect(
    mut client_reader: BufReader<TcpStream>,
    mut client_writer: TcpStream,
    destination: &Destination,
    policy: &ProxyPolicy,
) -> io::Result<()> {
    let upstream = connect_destination(policy, destination)?;
    client_writer.write_all(b"HTTP/1.1 200 Connection Established\r\n\r\n")?;
    client_writer.flush()?;

    let mut upstream_writer = upstream.try_clone()?;
    let mut upstream_reader = upstream.try_clone()?;
    let buffered = client_reader.buffer().len();
    if buffered > 0 {
        upstream_writer.write_all(client_reader.buffer())?;
        client_reader.consume(buffered);
    }
    let mut client_reader_for_upstream = client_reader.into_inner();
    let client_to_upstream = thread::spawn(move || {
        let _ = io::copy(&mut client_reader_for_upstream, &mut upstream_writer);
        let _ = upstream_writer.shutdown(Shutdown::Write);
    });
    let _ = io::copy(&mut upstream_reader, &mut client_writer);
    let _ = client_writer.shutdown(Shutdown::Write);
    let _ = upstream.shutdown(Shutdown::Read);
    let _ = client_to_upstream.join();
    Ok(())
}

fn connect_destination(policy: &ProxyPolicy, destination: &Destination) -> io::Result<TcpStream> {
    let addrs = (destination.host.as_str(), destination.port)
        .to_socket_addrs()
        .map_err(|error| invalid_data(&format!("failed to resolve destination: {error}")))?;
    let mut last_error = None;
    for addr in addrs {
        if let Err(reason) = policy.validate_ip(addr.ip()) {
            last_error = Some(io::Error::new(io::ErrorKind::PermissionDenied, reason));
            continue;
        }
        match TcpStream::connect_timeout(&addr, CONNECT_TIMEOUT) {
            Ok(stream) => return Ok(stream),
            Err(error) => last_error = Some(error),
        }
    }
    Err(last_error.unwrap_or_else(|| invalid_data("destination resolved to no addresses")))
}

pub(super) fn connect_socket_addr(policy: &ProxyPolicy, addr: SocketAddr) -> io::Result<TcpStream> {
    if let Err(reason) = policy.validate_ip(addr.ip()) {
        return Err(io::Error::new(io::ErrorKind::PermissionDenied, reason));
    }
    TcpStream::connect_timeout(&addr, CONNECT_TIMEOUT)
}

pub(super) fn read_u16(buffer: &[u8], offset: usize) -> Option<u16> {
    Some(u16::from_be_bytes([
        *buffer.get(offset)?,
        *buffer.get(offset + 1)?,
    ]))
}

pub(super) fn read_u24(buffer: &[u8], offset: usize) -> Option<u32> {
    Some(
        ((*buffer.get(offset)? as u32) << 16)
            | ((*buffer.get(offset + 1)? as u32) << 8)
            | (*buffer.get(offset + 2)? as u32),
    )
}

pub(super) fn write_proxy_error(writer: &mut TcpStream, code: u16, reason: &str) -> io::Result<()> {
    let text = match code {
        400 => "Bad Request",
        403 => "Forbidden",
        502 => "Bad Gateway",
        _ => "Proxy Error",
    };
    let body = format!("{reason}\n");
    write!(
        writer,
        "HTTP/1.1 {code} {text}\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    )
}

pub(super) fn append_proxy_event(
    context: EventRecordContext<'_>,
    subject: &str,
    decision: Decision,
    reason: &str,
) -> Result<(), String> {
    append_event(
        context.event_log,
        context.require_logging,
        Event::proxy_decision(
            context.project,
            context.mode,
            context.command,
            subject,
            decision,
            reason,
        ),
    )
}

fn append_prompt_event(
    context: EventRecordContext<'_>,
    subject: &str,
    decision: Decision,
    reason: &str,
) -> Result<(), String> {
    append_event(
        context.event_log,
        context.require_logging,
        Event::prompt_decision(
            context.project,
            context.mode,
            context.command,
            subject,
            decision,
            reason,
        ),
    )
}

fn append_approval_event(
    context: EventRecordContext<'_>,
    subject: &str,
    decision: Decision,
    reason: &str,
) -> Result<(), String> {
    append_event(
        context.event_log,
        context.require_logging,
        Event::approval_decision(
            context.project,
            context.mode,
            context.command,
            subject,
            decision,
            reason,
        ),
    )
}

fn append_event(event_log: &EventLog, require_logging: bool, event: Event) -> Result<(), String> {
    if require_logging {
        event_log
            .append(&event)
            .map_err(|error| format!("failed to write required event log: {error:#}"))
    } else {
        event_log.append_best_effort(&event);
        Ok(())
    }
}

fn credential_request(request: &ProxyRequest, destination: &Destination) -> CredentialRequest {
    CredentialRequest {
        scheme: destination.scheme.clone(),
        host: destination.host.clone(),
        port: destination.port,
        method: request.method.clone(),
        path: destination.path.clone(),
    }
}

pub(super) fn header_value<'a>(headers: &'a [(String, String)], name: &str) -> Option<&'a str> {
    headers
        .iter()
        .find(|(header, _value)| header.eq_ignore_ascii_case(name))
        .map(|(_header, value)| value.as_str())
}

pub(super) fn normalize_host(host: &str) -> String {
    host.trim()
        .trim_start_matches('[')
        .trim_end_matches(']')
        .trim_end_matches('.')
        .to_ascii_lowercase()
}

pub(super) fn host_matches(pattern: &str, host: &str) -> bool {
    let pattern = normalize_host(pattern);
    let host = normalize_host(host);
    if let Some(suffix) = pattern.strip_prefix("*.") {
        host.ends_with(&format!(".{suffix}")) && host != suffix
    } else {
        host == pattern
    }
}

fn is_metadata_host(host: &str) -> bool {
    host == "169.254.169.254" || host == "metadata.internal.test"
}

fn is_metadata_ip(ip: IpAddr) -> bool {
    matches!(ip, IpAddr::V4(ip) if ip == Ipv4Addr::new(169, 254, 169, 254))
}

fn is_internal_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(ip) => is_internal_v4(ip),
        IpAddr::V6(ip) => is_internal_v6(ip),
    }
}

fn is_internal_v4(ip: Ipv4Addr) -> bool {
    let [a, b, ..] = ip.octets();
    ip.is_loopback()
        || ip.is_link_local()
        || a == 10
        || (a == 172 && (16..=31).contains(&b))
        || (a == 192 && b == 168)
        || a == 0
}

fn is_internal_v6(ip: Ipv6Addr) -> bool {
    let first = ip.segments()[0];
    ip.is_loopback() || (first & 0xfe00) == 0xfc00 || (first & 0xffc0) == 0xfe80
}

pub(super) fn invalid_data(message: &str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message.to_string())
}

pub fn parse_npmrc(content: &str) -> Vec<NpmRegistryRoute> {
    parse_npmrc_with_default(content, None)
}

fn parse_npmrc_with_default(
    content: &str,
    configured_registry: Option<&str>,
) -> Vec<NpmRegistryRoute> {
    let mut routes = Vec::new();
    let mut default_registry = configured_registry.map(str::to_string);
    let mut scoped = Vec::new();
    let mut credential_fragments = Vec::new();
    for line in content.lines().map(str::trim) {
        if line.is_empty() || line.starts_with('#') || line.starts_with(';') {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        let key = key.trim();
        let value = value.trim().to_string();
        if key == "registry" {
            default_registry = Some(value);
        } else if key.starts_with('@') && key.ends_with(":registry") {
            scoped.push((Some(key.trim_end_matches(":registry").to_string()), value));
        } else if key.contains(":_authToken")
            || key.contains(":_auth")
            || key.contains(":_password")
        {
            credential_fragments.push(
                key.split(':')
                    .next()
                    .unwrap_or_default()
                    .trim_start_matches("//")
                    .to_string(),
            );
        }
    }
    if let Some(registry) = default_registry {
        routes.push(NpmRegistryRoute {
            scope: None,
            registry,
            has_credential: false,
        });
    }
    for (scope, registry) in scoped {
        routes.push(NpmRegistryRoute {
            scope,
            registry,
            has_credential: false,
        });
    }
    for route in &mut routes {
        route.has_credential = credential_fragments
            .iter()
            .any(|fragment| route.registry.contains(fragment.trim_end_matches('/')));
    }
    routes
}

pub fn sanitize_npmrc(
    content: &str,
    proxy_url: &str,
    npm_registry: Option<&str>,
    npm_ignore_scripts: bool,
) -> String {
    let mut rendered = String::new();
    for route in parse_npmrc_with_default(content, npm_registry) {
        if let Some(scope) = route.scope {
            rendered.push_str(&format!("{scope}:registry={}\n", route.registry));
        } else {
            rendered.push_str(&format!("registry={}\n", route.registry));
        }
    }
    rendered.push_str(&format!("proxy={proxy_url}\n"));
    rendered.push_str(&format!("https-proxy={proxy_url}\n"));
    rendered.push_str("noproxy=\n");
    rendered.push_str("always-auth=false\n");
    if npm_ignore_scripts {
        rendered.push_str("ignore-scripts=true\n");
    }
    rendered
}
