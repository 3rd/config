use super::*;

const BWRAP_MOUNT_FLAGS: &[&str] = &["--bind", "--ro-bind", "--tmpfs", "--proc", "--dev"];

const BWRAP_PROCESS_FLAGS: &[&str] = &["--unshare-pid", "--die-with-parent"];

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum HelperProbe {
    Ready {
        path: PathBuf,
        helper_version: String,
        capabilities: Vec<HelperCapability>,
    },
    Missing {
        path: PathBuf,
        message: String,
    },
    Incompatible {
        path: PathBuf,
        expected: u32,
        actual: u32,
    },
    Failed {
        path: PathBuf,
        message: String,
    },
}

pub fn required_capabilities() -> Vec<HelperCapability> {
    vec![
        HelperCapability::MountIsolation,
        HelperCapability::ProcessRestrictions,
        HelperCapability::SyscallRestrictions,
    ]
}

pub fn helper_capabilities() -> Vec<HelperCapability> {
    let mut capabilities = bubblewrap_capabilities();
    capabilities.push(HelperCapability::EphemeralOverlays);
    if seccomp::socket_filter_supported() {
        capabilities.push(HelperCapability::SyscallRestrictions);
    }
    if tproxy_routing_capability_available() {
        capabilities.push(HelperCapability::NetworkRouting);
    }
    capabilities.sort();
    capabilities.dedup();
    capabilities
}

fn tproxy_routing_capability_available() -> bool {
    if !tproxy::routing_configured(std::env::var_os(tproxy::ROUTING_ENV).as_deref()) {
        return false;
    }
    let mark = parse_env_u32(tproxy::MARK_ENV).unwrap_or(tproxy::DEFAULT_MARK);
    let table = parse_env_u32(tproxy::TABLE_ENV).unwrap_or(tproxy::DEFAULT_TABLE);
    let table_name = std::env::var(tproxy::TABLE_NAME_ENV)
        .unwrap_or_else(|_| tproxy::DEFAULT_TABLE_NAME.to_string());
    let interface =
        std::env::var(tproxy::INTERFACE_ENV).unwrap_or_else(|_| tproxy::DEFAULT_INTERFACE.into());
    let port = parse_env_u16(tproxy::PORT_ENV).unwrap_or(tproxy::DEFAULT_PORT);
    let tcp_ports = parse_env_port_list(tproxy::TCP_PORTS_ENV)
        .unwrap_or_else(|| tproxy::DEFAULT_TCP_PORTS.to_vec());
    let Some(rules) = command_output("ip", &["-4", "rule", "show"]) else {
        return false;
    };
    let Some(routes) = command_output("ip", &["-4", "route", "show", "table", &table.to_string()])
    else {
        return false;
    };
    let Some(nft) = command_output("nft", &["list", "table", "ip", &table_name]) else {
        return false;
    };
    tproxy_routing_outputs_match(
        &rules,
        &routes,
        &nft,
        TproxyRoutingExpectation {
            mark,
            table,
            proxy_port: port,
            tcp_ports: &tcp_ports,
            interface: &interface,
        },
    )
}

fn command_output(command: &str, args: &[&str]) -> Option<String> {
    let output = Command::new(command).args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    Some(format!(
        "{}\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    ))
}

fn parse_env_u16(name: &str) -> Option<u16> {
    std::env::var(name).ok()?.parse().ok()
}

fn parse_env_u32(name: &str) -> Option<u32> {
    std::env::var(name).ok()?.parse().ok()
}

fn parse_env_port_list(name: &str) -> Option<Vec<u16>> {
    let ports = std::env::var(name)
        .ok()?
        .split(',')
        .map(str::trim)
        .filter(|port| !port.is_empty())
        .map(str::parse)
        .collect::<Result<Vec<u16>, _>>()
        .ok()?;
    if ports.is_empty() {
        return None;
    }
    Some(ports)
}

#[derive(Clone, Copy)]
pub(super) struct TproxyRoutingExpectation<'a> {
    pub(super) mark: u32,
    pub(super) table: u32,
    pub(super) proxy_port: u16,
    pub(super) tcp_ports: &'a [u16],
    pub(super) interface: &'a str,
}

pub(super) fn tproxy_routing_outputs_match(
    rules: &str,
    routes: &str,
    nft: &str,
    expectation: TproxyRoutingExpectation<'_>,
) -> bool {
    routing_rule_matches(rules, expectation.mark, expectation.table)
        && local_route_matches(routes)
        && nft_tproxy_rule_matches(
            nft,
            expectation.proxy_port,
            expectation.tcp_ports,
            expectation.interface,
        )
}

fn routing_rule_matches(rules: &str, mark: u32, table: u32) -> bool {
    let mark_decimal = mark.to_string();
    let mark_hex = format!("0x{mark:x}");
    let table = table.to_string();
    rules.lines().any(|line| {
        line.contains("fwmark")
            && (line.contains(&mark_hex) || line.contains(&mark_decimal))
            && (line.contains(&format!("lookup {table}"))
                || line.contains(&format!("table {table}")))
    })
}

fn local_route_matches(routes: &str) -> bool {
    routes.lines().any(|line| {
        line.contains("local")
            && line.contains("dev lo")
            && (line.contains("0.0.0.0/0") || line.contains("default"))
    })
}

fn nft_tproxy_rule_matches(nft: &str, proxy_port: u16, tcp_ports: &[u16], interface: &str) -> bool {
    let proxy = format!("tproxy to :{proxy_port}");
    let interface = format!("iifname \"{interface}\"");
    nft.contains(&interface)
        && nft.contains(&proxy)
        && tcp_ports.iter().all(|port| nft.contains(&port.to_string()))
}

fn bubblewrap_capabilities() -> Vec<HelperCapability> {
    Command::new("bwrap")
        .arg("--help")
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| {
            let help = format!(
                "{}\n{}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
            capabilities_from_bubblewrap_help(&help)
        })
        .unwrap_or_default()
}

pub(super) fn capabilities_from_bubblewrap_help(help: &str) -> Vec<HelperCapability> {
    let mut capabilities = Vec::new();
    if BWRAP_MOUNT_FLAGS.iter().all(|flag| help.contains(flag)) {
        capabilities.push(HelperCapability::MountIsolation);
    }
    if BWRAP_PROCESS_FLAGS.iter().all(|flag| help.contains(flag)) {
        capabilities.push(HelperCapability::ProcessRestrictions);
    }
    capabilities
}

pub fn missing_required_capabilities(available: &[HelperCapability]) -> Vec<HelperCapability> {
    required_capabilities()
        .into_iter()
        .filter(|capability| !available.contains(capability))
        .collect()
}

pub fn required_capabilities_for_snapshot(
    snapshot: &policy::PolicySnapshot,
) -> Vec<HelperCapability> {
    let mut capabilities = vec![
        HelperCapability::MountIsolation,
        HelperCapability::ProcessRestrictions,
        HelperCapability::SyscallRestrictions,
    ];
    if snapshot.transparent_proxy.enabled {
        capabilities.push(HelperCapability::NetworkRouting);
    }
    capabilities
}

pub fn missing_required_capabilities_for_snapshot(
    snapshot: &policy::PolicySnapshot,
    available: &[HelperCapability],
) -> Vec<HelperCapability> {
    required_capabilities_for_snapshot(snapshot)
        .into_iter()
        .filter(|capability| !available.contains(capability))
        .collect()
}

pub fn configured_authorization_endpoint() -> Option<HelperEndpoint> {
    if helper_reentry_disabled() {
        return None;
    }
    configured_authorization_endpoint_from_environment()
}

pub fn configured_supervisor_authorization_endpoint() -> Option<HelperEndpoint> {
    std::env::var_os(AUTH_HELPER_SOCKET_ENV)
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .map(HelperEndpoint::Socket)
}

fn configured_authorization_endpoint_from_environment() -> Option<HelperEndpoint> {
    if std::env::var_os(HELPER_SOCKET_ENV).is_some() {
        return Some(HelperEndpoint::Socket(configured_helper_socket_path()));
    }
    if let Some(path) = std::env::var_os(HELPER_ENV) {
        return Some(HelperEndpoint::Binary(PathBuf::from(path)));
    }
    let default_socket = PathBuf::from(DEFAULT_HELPER_SOCKET);
    if default_socket.exists() {
        return Some(HelperEndpoint::Socket(default_socket));
    }
    None
}

pub fn configured_helper_path() -> PathBuf {
    std::env::var_os(HELPER_ENV)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("condom-helper"))
}

pub fn configured_helper_socket_path() -> PathBuf {
    std::env::var_os(HELPER_SOCKET_ENV)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(DEFAULT_HELPER_SOCKET))
}

pub fn probe_configured_helper() -> HelperProbe {
    if helper_reentry_disabled() {
        return HelperProbe::Missing {
            path: configured_helper_path(),
            message: format!("{DISABLE_HELPER_REENTRY_ENV} is set"),
        };
    }
    if std::env::var_os(HELPER_SOCKET_ENV).is_some() {
        return probe_helper_socket(&configured_helper_socket_path());
    }
    if std::env::var_os(HELPER_ENV).is_some() {
        return probe_helper(&configured_helper_path());
    }
    let default_socket = PathBuf::from(DEFAULT_HELPER_SOCKET);
    if default_socket.exists() {
        return probe_helper_socket(&default_socket);
    }
    probe_helper(&configured_helper_path())
}

pub(super) fn helper_reentry_disabled() -> bool {
    std::env::var_os(DISABLE_HELPER_REENTRY_ENV).is_some()
}

pub fn probe_helper(path: &Path) -> HelperProbe {
    let request = HelperRequest::Probe {
        protocol_version: HELPER_PROTOCOL_VERSION,
    };
    let mut child = match Command::new(path)
        .arg("request")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(child) => child,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            return HelperProbe::Missing {
                path: path.to_path_buf(),
                message: format!("helper binary `{}` was not found", path.display()),
            };
        }
        Err(error) => {
            return HelperProbe::Failed {
                path: path.to_path_buf(),
                message: format!("failed to start helper `{}`: {error}", path.display()),
            };
        }
    };

    if let Some(stdin) = child.stdin.as_mut() {
        if let Err(error) = serde_json::to_writer(stdin, &request) {
            return HelperProbe::Failed {
                path: path.to_path_buf(),
                message: format!("failed to write helper request: {error}"),
            };
        }
    }

    let output = match child.wait_with_output() {
        Ok(output) => output,
        Err(error) => {
            return HelperProbe::Failed {
                path: path.to_path_buf(),
                message: format!("failed to read helper response: {error}"),
            };
        }
    };
    if !output.status.success() {
        return HelperProbe::Failed {
            path: path.to_path_buf(),
            message: format!(
                "helper exited with status {}; stderr: {}",
                output.status.code().unwrap_or(1),
                String::from_utf8_lossy(&output.stderr).trim()
            ),
        };
    }

    parse_probe_response(path, &output.stdout)
}

pub fn probe_helper_socket(path: &Path) -> HelperProbe {
    let request = HelperRequest::Probe {
        protocol_version: HELPER_PROTOCOL_VERSION,
    };
    let mut stream = match UnixStream::connect(path) {
        Ok(stream) => stream,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            return HelperProbe::Missing {
                path: path.to_path_buf(),
                message: format!("helper socket `{}` was not found", path.display()),
            };
        }
        Err(error) => {
            return HelperProbe::Failed {
                path: path.to_path_buf(),
                message: format!(
                    "failed to connect to helper socket `{}`: {error}",
                    path.display()
                ),
            };
        }
    };
    if let Err(error) = serde_json::to_writer(&mut stream, &request) {
        return HelperProbe::Failed {
            path: path.to_path_buf(),
            message: format!("failed to write helper socket request: {error}"),
        };
    }
    if let Err(error) = stream.shutdown(Shutdown::Write) {
        return HelperProbe::Failed {
            path: path.to_path_buf(),
            message: format!("failed to finish helper socket request: {error}"),
        };
    }
    let mut output = Vec::new();
    if let Err(error) = stream.read_to_end(&mut output) {
        return HelperProbe::Failed {
            path: path.to_path_buf(),
            message: format!("failed to read helper socket response: {error}"),
        };
    }
    parse_probe_response(path, &output)
}

fn parse_probe_response(path: &Path, output: &[u8]) -> HelperProbe {
    match serde_json::from_slice::<HelperResponse>(output) {
        Ok(HelperResponse::Ready {
            helper_version,
            capabilities,
            ..
        }) => HelperProbe::Ready {
            path: path.to_path_buf(),
            helper_version,
            capabilities,
        },
        Ok(HelperResponse::UnsupportedProtocol { expected, actual }) => HelperProbe::Incompatible {
            path: path.to_path_buf(),
            expected,
            actual,
        },
        Ok(HelperResponse::MissingCapabilities { message, .. }) => HelperProbe::Failed {
            path: path.to_path_buf(),
            message,
        },
        Ok(HelperResponse::SandboxPrepared { .. }) => HelperProbe::Failed {
            path: path.to_path_buf(),
            message: "helper returned sandbox prepared to probe request".into(),
        },
        Ok(HelperResponse::SandboxRunFinished { .. }) => HelperProbe::Failed {
            path: path.to_path_buf(),
            message: "helper returned sandbox execution to probe request".into(),
        },
        Ok(HelperResponse::NotInstalled { message }) => HelperProbe::Failed {
            path: path.to_path_buf(),
            message,
        },
        Ok(HelperResponse::InvalidRequest { message }) => HelperProbe::Failed {
            path: path.to_path_buf(),
            message,
        },
        Ok(HelperResponse::FilesystemAuthorization { .. }) => HelperProbe::Failed {
            path: path.to_path_buf(),
            message: "helper returned filesystem authorization to probe request".into(),
        },
        Ok(HelperResponse::Credential { .. } | HelperResponse::CredentialUnavailable { .. }) => {
            HelperProbe::Failed {
                path: path.to_path_buf(),
                message: "helper returned credential response to probe request".into(),
            }
        }
        Err(error) => HelperProbe::Failed {
            path: path.to_path_buf(),
            message: format!("failed to parse helper response: {error}"),
        },
    }
}
