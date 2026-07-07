use super::*;

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) struct ProxyListenConfig {
    pub(super) addr: SocketAddr,
    pub(super) transparent_tcp_ports: Vec<u16>,
}

impl ProxyListenConfig {
    pub(super) fn start_reason(&self) -> &'static str {
        "transparent proxy listening"
    }
}

pub(super) fn proxy_listen_config_from_env() -> Result<ProxyListenConfig> {
    let transparent = tproxy::routing_configured(std::env::var_os(tproxy::ROUTING_ENV).as_deref());
    if !transparent {
        anyhow::bail!("network enforcement unavailable: transparent proxy routing is not active");
    }
    let port = parse_env_port(std::env::var_os(tproxy::PORT_ENV).as_deref())?
        .unwrap_or(tproxy::DEFAULT_PORT);
    let transparent_tcp_ports =
        parse_tproxy_tcp_ports(std::env::var_os(tproxy::TCP_PORTS_ENV).as_deref())?;
    Ok(ProxyListenConfig {
        addr: SocketAddr::from((Ipv4Addr::LOCALHOST, port)),
        transparent_tcp_ports,
    })
}

pub(super) fn parse_tproxy_tcp_ports(value: Option<&std::ffi::OsStr>) -> Result<Vec<u16>> {
    let Some(value) = value.and_then(|value| value.to_str()) else {
        return Ok(tproxy::DEFAULT_TCP_PORTS.to_vec());
    };
    let mut ports = Vec::new();
    for raw in value.split(',') {
        let raw = raw.trim();
        if raw.is_empty() {
            continue;
        }
        let port = raw
            .parse::<u16>()
            .with_context(|| format!("invalid {} value `{value}`", tproxy::TCP_PORTS_ENV))?;
        ports.push(port);
    }
    if ports.is_empty() {
        anyhow::bail!(
            "{} must contain at least one TCP port",
            tproxy::TCP_PORTS_ENV
        );
    }
    ports.sort_unstable();
    ports.dedup();
    Ok(ports)
}

pub(super) fn transparent_allowed_hosts(config: &CondomConfig) -> Vec<String> {
    let mut hosts = config.proxy.allowed_hosts.clone();
    hosts.sort();
    hosts.dedup();
    hosts
}

#[cfg(target_os = "linux")]
pub(super) fn bind_transparent_listener(addr: SocketAddr) -> io::Result<TcpListener> {
    let SocketAddr::V4(addr) = addr else {
        return Err(invalid_data(
            "transparent proxy listener only supports IPv4",
        ));
    };
    let fd = unsafe {
        libc::socket(
            libc::AF_INET,
            libc::SOCK_STREAM | libc::SOCK_CLOEXEC,
            libc::IPPROTO_TCP,
        )
    };
    if fd < 0 {
        return Err(io::Error::last_os_error());
    }
    if let Err(error) = configure_transparent_listener_fd(fd) {
        close_fd(fd);
        return Err(error);
    }
    let sockaddr = libc::sockaddr_in {
        sin_family: libc::AF_INET as libc::sa_family_t,
        sin_port: addr.port().to_be(),
        sin_addr: libc::in_addr {
            s_addr: u32::from_ne_bytes(addr.ip().octets()),
        },
        sin_zero: [0; 8],
    };
    let bind_result = unsafe {
        libc::bind(
            fd,
            &sockaddr as *const libc::sockaddr_in as *const libc::sockaddr,
            std::mem::size_of::<libc::sockaddr_in>() as libc::socklen_t,
        )
    };
    if bind_result < 0 {
        let error = io::Error::last_os_error();
        close_fd(fd);
        return Err(error);
    }
    let listen_result = unsafe { libc::listen(fd, 128) };
    if listen_result < 0 {
        let error = io::Error::last_os_error();
        close_fd(fd);
        return Err(error);
    }
    Ok(unsafe { TcpListener::from_raw_fd(fd) })
}

#[cfg(not(target_os = "linux"))]
pub(super) fn bind_transparent_listener(_addr: SocketAddr) -> io::Result<TcpListener> {
    Err(io::Error::new(
        io::ErrorKind::Unsupported,
        "transparent proxy listener requires Linux IP_TRANSPARENT",
    ))
}

#[cfg(target_os = "linux")]
fn configure_transparent_listener_fd(fd: RawFd) -> io::Result<()> {
    set_socket_int(fd, libc::SOL_SOCKET, libc::SO_REUSEADDR, 1)?;
    set_socket_int(fd, libc::SOL_IP, libc::IP_TRANSPARENT, 1)
}

#[cfg(target_os = "linux")]
fn set_socket_int(fd: RawFd, level: i32, name: i32, value: i32) -> io::Result<()> {
    let result = unsafe {
        libc::setsockopt(
            fd,
            level,
            name,
            &value as *const i32 as *const libc::c_void,
            std::mem::size_of::<i32>() as libc::socklen_t,
        )
    };
    if result < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

pub(super) fn handle_transparent_client(client: TcpStream, context: ProxyWorkerContext) {
    let original_destination = match transparent_original_destination(&client) {
        Ok(destination) => destination,
        Err(_error) => return,
    };
    let _ = client.set_read_timeout(Some(IO_TIMEOUT));
    let _ = client.set_write_timeout(Some(IO_TIMEOUT));
    let client_writer = match client.try_clone() {
        Ok(stream) => stream,
        Err(_error) => return,
    };
    let mut reader = BufReader::new(client);
    let initial = match reader.fill_buf() {
        Ok(buffer) if !buffer.is_empty() => buffer.to_vec(),
        Ok(_buffer) => return,
        Err(_error) => return,
    };

    if looks_like_http_request(&initial) {
        handle_transparent_http_client(reader, client_writer, original_destination, context);
    } else {
        handle_transparent_tcp_client(
            reader,
            client_writer,
            original_destination,
            context,
            &initial,
        );
    }
}

fn handle_transparent_http_client(
    mut reader: BufReader<TcpStream>,
    mut client_writer: TcpStream,
    original_destination: SocketAddr,
    context: ProxyWorkerContext,
) {
    let request = match read_proxy_request(&mut reader) {
        Ok(Some(request)) => request,
        Ok(None) => return,
        Err(error) => {
            let _ = write_proxy_error(&mut client_writer, 400, &error.to_string());
            return;
        }
    };
    let destination = match destination_from_transparent_request(&request, original_destination) {
        Ok(destination) => destination,
        Err(reason) => {
            let _ = write_proxy_error(&mut client_writer, 400, &reason);
            return;
        }
    };
    let subject = destination.subject();
    let decision_context = ProxyDecisionContext {
        project: &context.project,
        mode: context.mode,
        command: &context.command,
        event_log: &context.event_log,
    };
    let event_context = context.event_record_context();
    if let Err(reason) = context
        .policy
        .authorize_destination(&destination, decision_context)
    {
        let log_result = append_proxy_event(event_context, &subject, Decision::Denied, &reason);
        if let Err(error) = log_result {
            let _ = write_proxy_error(&mut client_writer, 502, &error);
            return;
        }
        let _ = write_proxy_error(&mut client_writer, 403, &reason);
        return;
    }
    if let Err(error) = append_proxy_event(
        event_context,
        &subject,
        Decision::Proxied,
        "proxied request",
    ) {
        let _ = write_proxy_error(&mut client_writer, 502, &error);
        return;
    }

    if request.method.eq_ignore_ascii_case("CONNECT") {
        let result = tunnel_connect(reader, client_writer, &destination, &context.policy);
        if let Err(error) = result {
            let _ = append_proxy_event(
                event_context,
                &subject,
                Decision::Denied,
                &error.to_string(),
            );
        }
        return;
    }

    let result = forward_http_request(&mut client_writer, &request, &destination, &context.policy);
    if let Err(error) = result {
        let _ = append_proxy_event(
            event_context,
            &subject,
            Decision::Denied,
            &error.to_string(),
        );
        let _ = write_proxy_error(&mut client_writer, 502, &error.to_string());
    }
}

fn handle_transparent_tcp_client(
    reader: BufReader<TcpStream>,
    client_writer: TcpStream,
    original_destination: SocketAddr,
    context: ProxyWorkerContext,
    initial: &[u8],
) {
    let destination = transparent_tcp_destination(original_destination, initial);
    let subject = destination.subject();
    let decision_context = ProxyDecisionContext {
        project: &context.project,
        mode: context.mode,
        command: &context.command,
        event_log: &context.event_log,
    };
    let event_context = context.event_record_context();
    if let Err(reason) = context
        .policy
        .authorize_destination(&destination, decision_context)
    {
        let _ = append_proxy_event(event_context, &subject, Decision::Denied, &reason);
        return;
    }
    if append_proxy_event(
        event_context,
        &subject,
        Decision::Proxied,
        "proxied request",
    )
    .is_err()
    {
        return;
    }
    let result =
        tunnel_transparent_tcp(reader, client_writer, original_destination, &context.policy);
    if let Err(error) = result {
        let _ = append_proxy_event(
            event_context,
            &subject,
            Decision::Denied,
            &error.to_string(),
        );
    }
}

fn transparent_original_destination(client: &TcpStream) -> io::Result<SocketAddr> {
    client.local_addr()
}

pub(super) fn destination_from_transparent_request(
    request: &ProxyRequest,
    original_destination: SocketAddr,
) -> Result<Destination, String> {
    match destination_from_request(request) {
        Ok(destination) => Ok(destination),
        Err(reason) if reason.contains("Host header") => Ok(Destination {
            scheme: transparent_scheme(original_destination.port()).into(),
            host: original_destination.ip().to_string(),
            port: original_destination.port(),
            path: if request.target.starts_with('/') {
                request.target.clone()
            } else {
                format!("/{}", request.target)
            },
        }),
        Err(reason) => Err(reason),
    }
}

pub(super) fn transparent_tcp_destination(
    original_destination: SocketAddr,
    initial: &[u8],
) -> Destination {
    let host = tls_sni_host(initial).unwrap_or_else(|| original_destination.ip().to_string());
    Destination {
        scheme: transparent_scheme(original_destination.port()).into(),
        host,
        port: original_destination.port(),
        path: String::new(),
    }
}

fn transparent_scheme(port: u16) -> &'static str {
    if port == 443 {
        "https"
    } else {
        "http"
    }
}

fn tunnel_transparent_tcp(
    mut client_reader: BufReader<TcpStream>,
    mut client_writer: TcpStream,
    original_destination: SocketAddr,
    policy: &ProxyPolicy,
) -> io::Result<()> {
    let upstream = connect_socket_addr(policy, original_destination)?;
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

fn tls_sni_host(buffer: &[u8]) -> Option<String> {
    if buffer.len() < 5 || buffer[0] != 0x16 {
        return None;
    }
    let record_len = read_u16(buffer, 3)? as usize;
    if buffer.len() < 5 + record_len || buffer.get(5).copied()? != 0x01 {
        return None;
    }
    let handshake_len = read_u24(buffer, 6)? as usize;
    if 9 + handshake_len > buffer.len() {
        return None;
    }
    let mut offset = 9usize;
    offset = offset.checked_add(2 + 32)?;
    let session_id_len = *buffer.get(offset)? as usize;
    offset = offset.checked_add(1 + session_id_len)?;
    let cipher_suites_len = read_u16(buffer, offset)? as usize;
    offset = offset.checked_add(2 + cipher_suites_len)?;
    let compression_len = *buffer.get(offset)? as usize;
    offset = offset.checked_add(1 + compression_len)?;
    let extensions_len = read_u16(buffer, offset)? as usize;
    offset += 2;
    let extensions_end = offset.checked_add(extensions_len)?;
    if extensions_end > buffer.len() {
        return None;
    }
    while offset + 4 <= extensions_end {
        let extension_type = read_u16(buffer, offset)?;
        let extension_len = read_u16(buffer, offset + 2)? as usize;
        offset += 4;
        let extension_end = offset.checked_add(extension_len)?;
        if extension_end > extensions_end {
            return None;
        }
        if extension_type == 0 {
            return tls_sni_from_extension(&buffer[offset..extension_end]);
        }
        offset = extension_end;
    }
    None
}

fn tls_sni_from_extension(extension: &[u8]) -> Option<String> {
    let list_len = read_u16(extension, 0)? as usize;
    let mut offset = 2usize;
    let list_end = offset.checked_add(list_len)?;
    if list_end > extension.len() {
        return None;
    }
    while offset + 3 <= list_end {
        let name_type = *extension.get(offset)?;
        let name_len = read_u16(extension, offset + 1)? as usize;
        offset += 3;
        let name_end = offset.checked_add(name_len)?;
        if name_end > list_end {
            return None;
        }
        if name_type == 0 {
            let name = std::str::from_utf8(&extension[offset..name_end]).ok()?;
            return Some(normalize_host(name));
        }
        offset = name_end;
    }
    None
}
