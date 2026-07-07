use std::collections::BTreeMap;
use std::fs;
use std::io::{self, BufRead, BufReader, Read, Write};
use std::net::{
    IpAddr, Ipv4Addr, Ipv6Addr, Shutdown, SocketAddr, TcpListener, TcpStream, ToSocketAddrs,
};
use std::os::fd::{FromRawFd, RawFd};
use std::path::{Path, PathBuf};
use std::sync::{
    atomic::{AtomicBool, AtomicUsize, Ordering},
    Arc, Mutex,
};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::auth::approvals::{
    command_app, Approval, ApprovalDecision, ApprovalKind, ApprovalScope, ApprovalStores,
    NewApproval,
};
use crate::model::config::{CondomConfig, ExecutionMode, PromptMode, ProxyConfig};

mod cache;
mod server;
mod transparent;

use cache::*;
use server::*;
pub use server::*;
use transparent::*;

pub use crate::auth::credentials::credential_env_key;

use crate::auth::credentials::{
    ConfiguredCredentialProvider, CredentialProvider, CredentialRequest,
};

use crate::model::events::{Decision, Event, EventLog};

use crate::model::policy::TransparentProxySnapshot;

use crate::model::project::ProjectContext;

use crate::auth::prompt::{self, PromptDecision, ProxyPrompt};

use crate::model::state::StatePaths;

use crate::net::tproxy;

#[cfg(test)]
mod tests {
    use std::io::{BufRead, Cursor, Read};
    use std::os::unix::net::UnixListener;

    use tempfile::TempDir;

    use super::*;
    use crate::app::helper::{self, HelperEndpoint};
    use crate::auth::credentials::{HelperCredentialProvider, HostCommandCredentialProvider};

    static TPROXY_ENV_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

    struct TproxyEnvGuard {
        _lock: std::sync::MutexGuard<'static, ()>,
        previous: Vec<(&'static str, Option<std::ffi::OsString>)>,
    }

    impl Drop for TproxyEnvGuard {
        fn drop(&mut self) {
            for (key, value) in self.previous.drain(..) {
                if let Some(value) = value {
                    std::env::set_var(key, value);
                } else {
                    std::env::remove_var(key);
                }
            }
        }
    }

    fn without_tproxy_env() -> TproxyEnvGuard {
        let lock = TPROXY_ENV_LOCK.lock().unwrap();
        let previous = [tproxy::ROUTING_ENV, tproxy::PORT_ENV, tproxy::TCP_PORTS_ENV]
            .into_iter()
            .map(|key| {
                let value = std::env::var_os(key);
                std::env::remove_var(key);
                (key, value)
            })
            .collect();
        TproxyEnvGuard {
            _lock: lock,
            previous,
        }
    }

    fn test_policy(temp: &TempDir) -> ProxyPolicy {
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"))
            .with_runtime_dir(temp.path().join("runtime/.condom"));
        ProxyPolicy::from_config(&CondomConfig::default(), &project, &state)
    }

    fn test_approval_stores(temp: &TempDir) -> ApprovalStores {
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        ApprovalStores::from_state(&state)
    }

    #[test]
    fn proxy_cache_dir_lives_in_xdg_state() {
        let temp = tempfile::tempdir().unwrap();
        let policy = test_policy(&temp);

        assert!(policy
            .cache_dir
            .starts_with(temp.path().join("state/condom")));
        assert!(!policy.cache_dir.ends_with(".condom/proxy-cache"));
    }

    #[test]
    fn future_cached_proxy_metadata_is_stale() {
        let metadata = ProxyCacheMetadata {
            cached_at: Utc::now() + chrono::Duration::seconds(1),
            etag: None,
            last_modified: None,
        };

        assert!(proxy_cache_stale(
            &metadata,
            Duration::from_secs(86_400),
            Utc::now()
        ));
    }

    #[test]
    fn stale_cached_proxy_response_is_removed_on_read() {
        let temp = tempfile::tempdir().unwrap();
        let destination = Destination {
            scheme: "http".into(),
            host: "example.test".into(),
            port: 80,
            path: "/pkg.tgz".into(),
        };
        let stale_at = Utc::now() - chrono::Duration::seconds(2);
        write_cached_proxy_response(
            temp.path(),
            &destination,
            b"HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nbody",
            stale_at,
        );

        let cached = read_cached_proxy_response(
            temp.path(),
            &destination,
            Duration::from_secs(1),
            Utc::now(),
        );

        assert!(cached.is_none());
        assert!(!proxy_cache_path(temp.path(), &destination).exists());
    }

    #[test]
    fn stale_validator_backed_proxy_cache_survives_startup_prune() {
        let temp = tempfile::tempdir().unwrap();
        let destination = Destination {
            scheme: "http".into(),
            host: "example.test".into(),
            port: 80,
            path: "/pkg.tgz".into(),
        };
        let stale_at = Utc::now() - chrono::Duration::seconds(2);
        write_cached_proxy_response(
            temp.path(),
            &destination,
            b"HTTP/1.1 200 OK\r\nETag: \"v1\"\r\nContent-Length: 4\r\n\r\nbody",
            stale_at,
        );

        prune_proxy_cache(temp.path(), Duration::from_secs(1), Utc::now());

        let cached = read_cached_proxy_entry(temp.path(), &destination).unwrap();
        assert_eq!(cached.metadata.etag.as_deref(), Some("\"v1\""));
        assert_eq!(
            String::from_utf8_lossy(&cached.response),
            "HTTP/1.1 200 OK\r\nETag: \"v1\"\r\nContent-Length: 4\r\n\r\nbody"
        );
    }

    #[test]
    fn stale_unvalidated_proxy_cache_is_removed_on_startup_prune() {
        let temp = tempfile::tempdir().unwrap();
        let destination = Destination {
            scheme: "http".into(),
            host: "example.test".into(),
            port: 80,
            path: "/pkg.tgz".into(),
        };
        let stale_at = Utc::now() - chrono::Duration::seconds(2);
        write_cached_proxy_response(
            temp.path(),
            &destination,
            b"HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nbody",
            stale_at,
        );

        prune_proxy_cache(temp.path(), Duration::from_secs(1), Utc::now());

        assert!(read_cached_proxy_entry(temp.path(), &destination).is_none());
        assert!(!proxy_cache_path(temp.path(), &destination).exists());
    }

    #[test]
    fn invalid_content_length_is_rejected() {
        let mut reader = BufReader::new(Cursor::new(
            b"POST http://example.test/upload HTTP/1.1\r\nContent-Length: nope\r\n\r\nbody",
        ));

        let error = read_proxy_request(&mut reader).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::InvalidData);
        assert!(error.to_string().contains("invalid Content-Length"));
    }

    #[test]
    fn oversized_content_length_is_rejected_before_body_allocation() {
        let request = format!(
            "POST http://example.test/upload HTTP/1.1\r\nContent-Length: {}\r\n\r\n",
            MAX_PROXY_REQUEST_BODY_BYTES + 1
        );
        let mut reader = BufReader::new(Cursor::new(request.into_bytes()));

        let error = read_proxy_request(&mut reader).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::InvalidData);
        assert!(error.to_string().contains("request body exceeds"));
    }

    #[test]
    fn oversized_request_line_is_rejected() {
        let request = format!("GET /{} HTTP/1.1\r\n\r\n", "x".repeat(9 * 1024));
        let mut reader = BufReader::new(Cursor::new(request.into_bytes()));

        let error = read_proxy_request(&mut reader).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::InvalidData);
        assert!(error.to_string().contains("request line exceeds"));
    }

    #[test]
    fn excessive_header_count_is_rejected() {
        let mut request = String::from("GET / HTTP/1.1\r\n");
        for index in 0..=MAX_PROXY_REQUEST_HEADERS {
            request.push_str(&format!("X-Test-{index}: value\r\n"));
        }
        request.push_str("\r\n");
        let mut reader = BufReader::new(Cursor::new(request.into_bytes()));

        let error = read_proxy_request(&mut reader).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::InvalidData);
        assert!(error.to_string().contains("too many headers"));
    }

    #[test]
    fn cache_rejects_vary_and_no_cache_responses() {
        assert!(!proxy_cacheable_response(
            b"HTTP/1.1 200 OK\r\nVary: Accept-Encoding\r\n\r\nbody"
        ));
        assert!(!proxy_cacheable_response(
            b"HTTP/1.1 200 OK\r\nCache-Control: no-cache\r\n\r\nbody"
        ));
    }

    #[test]
    fn active_proxy_worker_limit_is_enforced_and_released() {
        let active_workers = Arc::new(AtomicUsize::new(0));
        let workers = (0..MAX_PROXY_CLIENT_WORKERS)
            .map(|_| try_acquire_proxy_worker(&active_workers).unwrap())
            .collect::<Vec<_>>();

        assert!(try_acquire_proxy_worker(&active_workers).is_none());
        drop(workers);
        assert!(try_acquire_proxy_worker(&active_workers).is_some());
    }

    #[test]
    fn saturated_proxy_worker_limit_returns_503() {
        let temp = tempfile::tempdir().unwrap();
        let (project, state) = test_project_and_state(&temp);
        let context = ProxyWorkerContext {
            policy: ProxyPolicy::from_config(&CondomConfig::default(), &project, &state),
            project,
            mode: ExecutionMode::Run,
            command: vec!["curl".into()],
            event_log: EventLog::new(temp.path().join("events.jsonl")),
        };
        let active_workers = Arc::new(AtomicUsize::new(0));
        let workers = (0..MAX_PROXY_CLIENT_WORKERS)
            .map(|_| try_acquire_proxy_worker(&active_workers).unwrap())
            .collect::<Vec<_>>();
        let (mut client, server) = loopback_pair();

        handle_accepted_proxy_client(server, &active_workers, context);

        let mut response = String::new();
        client.read_to_string(&mut response).unwrap();
        drop(workers);
        assert!(response.starts_with("HTTP/1.1 503"));
        assert!(response.contains("proxy worker limit reached"));
    }

    #[test]
    fn required_proxy_logging_failure_blocks_upstream_connection() {
        let temp = tempfile::tempdir().unwrap();
        let (project, state) = test_project_and_state(&temp);
        let blocked_parent = temp.path().join("events-parent");
        std::fs::write(&blocked_parent, "not a directory").unwrap();
        let upstream = TcpListener::bind("127.0.0.1:0").unwrap();
        upstream.set_nonblocking(true).unwrap();
        let mut policy = ProxyPolicy::from_config(&CondomConfig::default(), &project, &state);
        policy.require_logging = true;
        let context = ProxyWorkerContext {
            policy,
            project,
            mode: ExecutionMode::Run,
            command: vec!["curl".into()],
            event_log: EventLog::new(blocked_parent.join("events.jsonl")),
        };
        let active_workers = Arc::new(AtomicUsize::new(0));
        let (mut client, server) = loopback_pair();

        handle_accepted_proxy_client(server, &active_workers, context);
        write!(
            client,
            "GET http://127.0.0.1:{}/pkg HTTP/1.1\r\nHost: 127.0.0.1:{}\r\n\r\n",
            upstream.local_addr().unwrap().port(),
            upstream.local_addr().unwrap().port()
        )
        .unwrap();
        client.shutdown(Shutdown::Write).unwrap();
        let mut response = String::new();
        client.read_to_string(&mut response).unwrap();

        assert!(response.starts_with("HTTP/1.1 502"), "{response}");
        assert!(response.contains("failed to write required event log"));
        assert!(matches!(
            upstream.accept(),
            Err(error) if error.kind() == io::ErrorKind::WouldBlock
        ));
    }

    #[test]
    fn upstream_response_limit_is_enforced() {
        let mut upstream = Cursor::new(b"HTTP/1.1 200 OK\r\n\r\nabcdef".to_vec());

        let error = read_upstream_response_with_limit(&mut upstream, 8).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::InvalidData);
        assert!(error.to_string().contains("response exceeds"));
    }

    fn upstream_once(body: &'static [u8]) -> (SocketAddr, JoinHandle<()>) {
        let upstream = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = upstream.local_addr().unwrap();
        let handle = thread::spawn(move || {
            let (mut stream, _) = upstream.accept().unwrap();
            stream.set_read_timeout(Some(IO_TIMEOUT)).unwrap();
            let mut reader = BufReader::new(stream.try_clone().unwrap());
            loop {
                let mut line = String::new();
                reader.read_line(&mut line).unwrap();
                if line == "\r\n" {
                    break;
                }
            }
            write!(
                stream,
                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                body.len()
            )
            .unwrap();
            stream.write_all(body).unwrap();
        });
        (addr, handle)
    }

    fn test_project_and_state(temp: &TempDir) -> (ProjectContext, StatePaths) {
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        std::fs::create_dir_all(&project.root).unwrap();
        let state = StatePaths::from_base(&project, &temp.path().join("state"))
            .with_runtime_dir(temp.path().join("runtime/.condom"));
        (project, state)
    }

    fn loopback_pair() -> (TcpStream, TcpStream) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let client = TcpStream::connect(listener.local_addr().unwrap()).unwrap();
        let (server, _) = listener.accept().unwrap();
        (client, server)
    }

    fn get_request(target: &str) -> ProxyRequest {
        ProxyRequest {
            method: "GET".into(),
            target: target.into(),
            version: "HTTP/1.1".into(),
            headers: vec![("Host".into(), "registry.example.test".into())],
            body: Vec::new(),
        }
    }

    fn tls_client_hello_with_sni(host: &str) -> Vec<u8> {
        let host = host.as_bytes();
        let mut sni_extension = Vec::new();
        let server_name_len = 1 + 2 + host.len();
        sni_extension.extend_from_slice(&(server_name_len as u16).to_be_bytes());
        sni_extension.push(0);
        sni_extension.extend_from_slice(&(host.len() as u16).to_be_bytes());
        sni_extension.extend_from_slice(host);

        let mut extensions = Vec::new();
        extensions.extend_from_slice(&0u16.to_be_bytes());
        extensions.extend_from_slice(&(sni_extension.len() as u16).to_be_bytes());
        extensions.extend_from_slice(&sni_extension);

        let mut hello = Vec::new();
        hello.extend_from_slice(&[0x03, 0x03]);
        hello.extend_from_slice(&[0; 32]);
        hello.push(0);
        hello.extend_from_slice(&2u16.to_be_bytes());
        hello.extend_from_slice(&0x1301u16.to_be_bytes());
        hello.push(1);
        hello.push(0);
        hello.extend_from_slice(&(extensions.len() as u16).to_be_bytes());
        hello.extend_from_slice(&extensions);

        let mut handshake = Vec::new();
        handshake.push(0x01);
        let hello_len = hello.len() as u32;
        handshake.push(((hello_len >> 16) & 0xff) as u8);
        handshake.push(((hello_len >> 8) & 0xff) as u8);
        handshake.push((hello_len & 0xff) as u8);
        handshake.extend_from_slice(&hello);

        let mut record = Vec::new();
        record.extend_from_slice(&[0x16, 0x03, 0x01]);
        record.extend_from_slice(&(handshake.len() as u16).to_be_bytes());
        record.extend_from_slice(&handshake);
        record
    }

    #[test]
    fn parses_transparent_proxy_ports_from_env_value() {
        assert_eq!(
            parse_tproxy_tcp_ports(Some(std::ffi::OsStr::new("443, 80,443"))).unwrap(),
            vec![80, 443]
        );
        assert!(parse_tproxy_tcp_ports(Some(std::ffi::OsStr::new(""))).is_err());
    }

    #[test]
    fn transparent_tcp_destination_uses_tls_sni_when_available() {
        let original = SocketAddr::from((Ipv4Addr::new(93, 184, 216, 34), 443));
        let destination = transparent_tcp_destination(
            original,
            &tls_client_hello_with_sni("Registry.Example.Test"),
        );

        assert_eq!(destination.scheme, "https");
        assert_eq!(destination.host, "registry.example.test");
        assert_eq!(destination.port, 443);
    }

    #[test]
    fn transparent_http_destination_falls_back_to_original_address() {
        let request = ProxyRequest {
            method: "GET".into(),
            target: "/index.json".into(),
            version: "HTTP/1.1".into(),
            headers: Vec::new(),
            body: Vec::new(),
        };
        let original = SocketAddr::from((Ipv4Addr::new(93, 184, 216, 34), 80));
        let destination = destination_from_transparent_request(&request, original).unwrap();

        assert_eq!(destination.scheme, "http");
        assert_eq!(destination.host, "93.184.216.34");
        assert_eq!(destination.port, 80);
        assert_eq!(destination.path, "/index.json");
    }

    #[test]
    fn sanitizes_npmrc_without_secret_values() {
        let content = r#"
registry=https://registry.example.test/
@private:registry=https://private-registry.example.test/
//registry.example.test/:_authToken=secret
"#;
        let sanitized = sanitize_npmrc(content, "http://127.0.0.1:1234", None, false);
        assert!(sanitized.contains("registry=https://registry.example.test/"));
        assert!(sanitized.contains("@private:registry=https://private-registry.example.test/"));
        assert!(sanitized.contains("proxy=http://127.0.0.1:1234"));
        assert!(sanitized.contains("https-proxy=http://127.0.0.1:1234"));
        assert!(!sanitized.contains("ignore-scripts=true"));
        assert!(!sanitized.contains("secret"));
    }

    #[test]
    fn npm_adapter_hardening_is_configured() {
        let sanitized = sanitize_npmrc(
            "",
            "http://127.0.0.1:1234",
            Some("https://private-registry.example.test/"),
            true,
        );

        assert!(sanitized.contains("registry=https://private-registry.example.test/"));
        assert!(sanitized.contains("ignore-scripts=true"));
    }

    #[test]
    fn materializes_sanitized_npm_adapter_config() {
        let temp = tempfile::tempdir().unwrap();
        let (project, state) = test_project_and_state(&temp);
        std::fs::write(
            project.root.join(".npmrc"),
            "registry=https://registry.example.test/\n@private:registry=https://private-registry.example.test/\n//private-registry.example.test/:_authToken=secret\n",
        )
        .unwrap();

        let proxy = ProxyConfig::default();
        let npmrc =
            materialize_npm_adapter_config(&project, &state, "http://127.0.0.1:32123", &proxy)
                .unwrap();
        let content = std::fs::read_to_string(&npmrc).unwrap();

        assert!(npmrc.starts_with(state.runtime_dir.join("xdg/config/npm")));
        assert!(!npmrc.starts_with(state.project_dir.join("xdg/config/npm")));
        assert!(content.contains("registry=https://registry.example.test/"));
        assert!(content.contains("@private:registry=https://private-registry.example.test/"));
        assert!(content.contains("proxy=http://127.0.0.1:32123"));
        assert!(content.contains("https-proxy=http://127.0.0.1:32123"));
        assert!(content.contains("always-auth=false"));
        assert!(!content.contains("ignore-scripts=true"));
        assert!(!content.contains("_authToken"));
        assert!(!content.contains("secret"));
    }

    #[test]
    fn materializes_pip_adapter_config() {
        let temp = tempfile::tempdir().unwrap();
        let (_project, state) = test_project_and_state(&temp);

        let proxy = ProxyConfig::default();
        let pip_conf =
            materialize_pip_adapter_config(&state, "http://127.0.0.1:32123", &proxy).unwrap();
        let content = std::fs::read_to_string(&pip_conf).unwrap();

        assert!(pip_conf.starts_with(state.runtime_dir.join("xdg/config/pip")));
        assert_eq!(content, "[global]\nproxy = http://127.0.0.1:32123\n");
    }

    #[test]
    fn pip_adapter_hardening_is_configured() {
        let temp = tempfile::tempdir().unwrap();
        let (_project, state) = test_project_and_state(&temp);
        let proxy = ProxyConfig {
            pip_index_url: Some("https://packages.example.test/simple".into()),
            pip_no_input: true,
            pip_disable_version_check: true,
            ..ProxyConfig::default()
        };

        let pip_conf =
            materialize_pip_adapter_config(&state, "http://127.0.0.1:32123", &proxy).unwrap();
        let content = std::fs::read_to_string(&pip_conf).unwrap();

        assert_eq!(
            content,
            "[global]\nproxy = http://127.0.0.1:32123\nindex-url = https://packages.example.test/simple\nno-input = true\ndisable-pip-version-check = true\n"
        );
    }

    #[test]
    fn materializes_cargo_adapter_config() {
        let temp = tempfile::tempdir().unwrap();
        let (_project, state) = test_project_and_state(&temp);

        let proxy = ProxyConfig::default();
        let cargo_home =
            materialize_cargo_adapter_config(&state, "http://127.0.0.1:32123", &proxy).unwrap();
        let content = std::fs::read_to_string(cargo_home.join("config.toml")).unwrap();

        assert!(cargo_home.starts_with(state.runtime_dir.join("xdg/cache/cargo")));
        assert_eq!(content, "[http]\nproxy = \"http://127.0.0.1:32123\"\n");
    }

    #[test]
    fn cargo_adapter_git_fetch_mode_is_configured() {
        let temp = tempfile::tempdir().unwrap();
        let (_project, state) = test_project_and_state(&temp);
        let proxy = ProxyConfig {
            cargo_git_fetch_with_cli: Some(false),
            ..ProxyConfig::default()
        };

        let cargo_home =
            materialize_cargo_adapter_config(&state, "http://127.0.0.1:32123", &proxy).unwrap();
        let content = std::fs::read_to_string(cargo_home.join("config.toml")).unwrap();

        assert_eq!(
            content,
            "[http]\nproxy = \"http://127.0.0.1:32123\"\n\n[net]\ngit-fetch-with-cli = false\n"
        );
    }

    #[test]
    fn materializes_go_adapter_config() {
        let temp = tempfile::tempdir().unwrap();
        let (_project, state) = test_project_and_state(&temp);

        let proxy = ProxyConfig::default();
        let go_config = materialize_go_adapter_config(&state, &proxy).unwrap();
        let content = std::fs::read_to_string(&go_config.env_file).unwrap();

        assert!(go_config
            .env_file
            .starts_with(state.runtime_dir.join("xdg/config/go")));
        assert!(go_config.module_cache.is_dir());
        assert!(go_config.build_cache.is_dir());
        assert_eq!(
            content,
            format!(
                "GOCACHE={}\nGOMODCACHE={}\n",
                go_config.build_cache.display(),
                go_config.module_cache.display()
            )
        );
    }

    #[test]
    fn go_adapter_hardening_is_configured() {
        let temp = tempfile::tempdir().unwrap();
        let (_project, state) = test_project_and_state(&temp);
        let proxy = ProxyConfig {
            go_auth: Some("off".into()),
            go_proxy: Some("https://proxy.modules.example.test".into()),
            go_sumdb: Some("sum.modules.example.test".into()),
            go_vcs: Some("*:off".into()),
            ..ProxyConfig::default()
        };

        let go_config = materialize_go_adapter_config(&state, &proxy).unwrap();
        let content = std::fs::read_to_string(&go_config.env_file).unwrap();

        assert!(content.contains("GOAUTH=off\n"));
        assert!(content.contains("GOPROXY=https://proxy.modules.example.test\n"));
        assert!(content.contains("GOSUMDB=sum.modules.example.test\n"));
        assert!(content.contains("GOVCS=*:off\n"));
    }

    #[test]
    fn destination_policy_prompts_for_metadata_service_by_default() {
        let temp = tempfile::tempdir().unwrap();
        let policy = test_policy(&temp);
        let HostDecision::Promptable { host, reason } = policy.classify_host("169.254.169.254")
        else {
            panic!("metadata service was not promptable");
        };

        assert_eq!(host, "169.254.169.254");
        assert!(reason.contains("allowedHosts"));
    }

    #[test]
    fn destination_policy_denies_metadata_service_when_configured() {
        let temp = tempfile::tempdir().unwrap();
        let mut policy = test_policy(&temp);
        policy.deny_metadata = true;
        let HostDecision::Denied(error) = policy.classify_host("169.254.169.254") else {
            panic!("metadata service was not denied");
        };

        assert!(error.contains("metadata service"));
    }

    #[test]
    fn destination_policy_allows_loopback_when_configured() {
        let temp = tempfile::tempdir().unwrap();
        let policy = test_policy(&temp);

        assert_eq!(policy.classify_host("127.0.0.1"), HostDecision::Allowed);
        assert!(policy.validate_ip(IpAddr::V4(Ipv4Addr::LOCALHOST)).is_ok());
    }

    #[test]
    fn wildcard_hosts_match_only_subdomains() {
        assert!(host_matches(
            "*.packages.example.test",
            "registry.packages.example.test"
        ));
        assert!(!host_matches(
            "*.packages.example.test",
            "packages.example.test"
        ));
    }

    #[test]
    fn credential_env_key_normalizes_host_names() {
        assert_eq!(
            credential_env_key("127.0.0.1"),
            "CONDOM_CREDENTIAL_127_0_0_1"
        );
        assert_eq!(
            credential_env_key("Registry.Example.Test"),
            "CONDOM_CREDENTIAL_REGISTRY_EXAMPLE_TEST"
        );
    }

    #[test]
    fn child_environment_includes_adapter_specific_proxy_variables() {
        let temp = tempfile::tempdir().unwrap();
        let (project, state) = test_project_and_state(&temp);
        let addr = "127.0.0.1:32123".parse().unwrap();
        let proxy = ProxyConfig {
            adapters: vec![
                "npm".into(),
                "pypi".into(),
                "cargo".into(),
                "go".into(),
                "generic-http".into(),
            ],
            ..ProxyConfig::default()
        };
        let env = child_environment(&project, &state, addr, &proxy).unwrap();

        for key in [
            "HTTP_PROXY",
            "HTTPS_PROXY",
            "NPM_CONFIG_PROXY",
            "npm_config_proxy",
            "PIP_PROXY",
            "CARGO_HTTP_PROXY",
            "CONDOM_HTTP_PROXY",
        ] {
            assert_eq!(
                env.get(key).map(String::as_str),
                Some("http://127.0.0.1:32123")
            );
        }
        assert_eq!(env.get("NO_PROXY").map(String::as_str), Some(""));
        assert_eq!(env.get("no_proxy").map(String::as_str), Some(""));
        let userconfig = env
            .get("NPM_CONFIG_USERCONFIG")
            .expect("npm userconfig should be set");
        assert_eq!(
            env.get("npm_config_userconfig").map(String::as_str),
            Some(userconfig.as_str())
        );
        assert!(std::path::Path::new(userconfig).is_file());
        assert!(!env.contains_key("NPM_CONFIG_IGNORE_SCRIPTS"));
        assert!(!env.contains_key("NPM_CONFIG_REGISTRY"));
        assert_eq!(
            env.get("NPM_CONFIG_CACHE").map(String::as_str),
            Some(
                state
                    .runtime_dir
                    .join("xdg/cache/npm")
                    .display()
                    .to_string()
                    .as_str()
            )
        );
        let pip_config = env
            .get("PIP_CONFIG_FILE")
            .expect("pip config file should be set");
        assert!(std::path::Path::new(pip_config).is_file());
        assert!(!env.contains_key("PIP_NO_INPUT"));
        assert!(!env.contains_key("PIP_DISABLE_PIP_VERSION_CHECK"));
        assert!(!env.contains_key("PIP_INDEX_URL"));
        let cargo_home = env.get("CARGO_HOME").expect("cargo home should be set");
        assert!(std::path::Path::new(cargo_home)
            .join("config.toml")
            .is_file());
        assert_eq!(
            env.get("CARGO_NET_OFFLINE").map(String::as_str),
            Some("false")
        );
        assert!(!env.contains_key("GOPROXY"));
        assert!(!env.contains_key("GOSUMDB"));
        assert!(!env.contains_key("GOVCS"));
        assert!(!env.contains_key("GOAUTH"));
        assert!(!env.contains_key("GONOPROXY"));
        assert!(!env.contains_key("GONOSUMDB"));
        assert!(!env.contains_key("GOPRIVATE"));
        assert!(!env.contains_key("GOINSECURE"));
        let goenv = env.get("GOENV").expect("go env file should be set");
        let gomodcache = env
            .get("GOMODCACHE")
            .expect("go module cache should be set");
        let gocache = env.get("GOCACHE").expect("go build cache should be set");
        assert!(std::path::Path::new(goenv).is_file());
        assert!(std::path::Path::new(gomodcache).is_dir());
        assert!(std::path::Path::new(gocache).is_dir());
    }

    #[test]
    fn child_environment_includes_configured_adapter_hardening() {
        let temp = tempfile::tempdir().unwrap();
        let (project, state) = test_project_and_state(&temp);
        let addr = "127.0.0.1:32123".parse().unwrap();
        let proxy = ProxyConfig {
            adapters: vec!["npm".into(), "pypi".into(), "cargo".into(), "go".into()],
            npm_registry: Some("https://private-registry.example.test/".into()),
            npm_ignore_scripts: true,
            pip_index_url: Some("https://packages.example.test/simple".into()),
            pip_no_input: true,
            pip_disable_version_check: true,
            cargo_git_fetch_with_cli: Some(false),
            go_auth: Some("off".into()),
            go_proxy: Some("https://proxy.modules.example.test".into()),
            go_sumdb: Some("sum.modules.example.test".into()),
            go_vcs: Some("*:off".into()),
            ..ProxyConfig::default()
        };

        let env = child_environment(&project, &state, addr, &proxy).unwrap();

        assert_eq!(
            env.get("NPM_CONFIG_REGISTRY").map(String::as_str),
            Some("https://private-registry.example.test/")
        );
        assert_eq!(
            env.get("NPM_CONFIG_IGNORE_SCRIPTS").map(String::as_str),
            Some("true")
        );
        assert_eq!(
            env.get("PIP_INDEX_URL").map(String::as_str),
            Some("https://packages.example.test/simple")
        );
        assert_eq!(env.get("PIP_NO_INPUT").map(String::as_str), Some("1"));
        assert_eq!(
            env.get("PIP_DISABLE_PIP_VERSION_CHECK").map(String::as_str),
            Some("1")
        );
        assert_eq!(
            env.get("GOPROXY").map(String::as_str),
            Some("https://proxy.modules.example.test")
        );
        assert_eq!(
            env.get("GOSUMDB").map(String::as_str),
            Some("sum.modules.example.test")
        );
        assert_eq!(env.get("GOVCS").map(String::as_str), Some("*:off"));
        assert_eq!(env.get("GOAUTH").map(String::as_str), Some("off"));
    }

    #[test]
    fn child_environment_respects_configured_adapters() {
        let temp = tempfile::tempdir().unwrap();
        let (project, state) = test_project_and_state(&temp);
        let addr = "127.0.0.1:32123".parse().unwrap();
        let proxy = ProxyConfig {
            adapters: vec!["pypi".into()],
            ..ProxyConfig::default()
        };
        let env = child_environment(&project, &state, addr, &proxy).unwrap();

        assert_eq!(
            env.get("PIP_PROXY").map(String::as_str),
            Some("http://127.0.0.1:32123")
        );
        assert!(!env.contains_key("HTTP_PROXY"));
        assert!(!env.contains_key("HTTPS_PROXY"));
        assert!(!env.contains_key("CONDOM_HTTP_PROXY"));
        assert!(!env.contains_key("NPM_CONFIG_PROXY"));
        assert!(!env.contains_key("NPM_CONFIG_USERCONFIG"));
        assert!(!env.contains_key("CARGO_HTTP_PROXY"));
        assert!(!env.contains_key("GOPROXY"));
    }

    #[test]
    fn forward_http_serves_cached_get_without_upstream() {
        let temp = tempfile::tempdir().unwrap();
        let policy = test_policy(&temp);
        let now = Utc::now();
        let destination = Destination {
            scheme: "http".into(),
            host: "registry.example.test".into(),
            port: 80,
            path: "/package.tgz".into(),
        };
        let cached = b"HTTP/1.1 200 OK\r\nContent-Length: 6\r\nConnection: close\r\n\r\ncached";
        write_cached_proxy_response(&policy.cache_dir, &destination, cached, now);
        let (mut client, mut server) = loopback_pair();

        forward_http_request(
            &mut server,
            &get_request("http://registry.example.test/package.tgz"),
            &destination,
            &policy,
        )
        .unwrap();
        drop(server);
        let mut response = String::new();
        client.read_to_string(&mut response).unwrap();

        assert!(response.ends_with("cached"));
    }

    #[test]
    fn forward_http_refreshes_stale_cached_get_from_upstream() {
        let temp = tempfile::tempdir().unwrap();
        let mut policy = test_policy(&temp);
        policy.cache_ttl = Duration::from_secs(1);
        let (upstream_addr, upstream_thread) = upstream_once(b"fresh");
        let destination = Destination {
            scheme: "http".into(),
            host: "127.0.0.1".into(),
            port: upstream_addr.port(),
            path: "/package.tgz".into(),
        };
        let stale_at = Utc::now() - chrono::Duration::seconds(2);
        let cached = b"HTTP/1.1 200 OK\r\nContent-Length: 6\r\nConnection: close\r\n\r\nstale!";
        write_cached_proxy_response(&policy.cache_dir, &destination, cached, stale_at);
        let (mut client, mut server) = loopback_pair();

        forward_http_request(
            &mut server,
            &get_request(&format!("http://{}/package.tgz", destination.authority())),
            &destination,
            &policy,
        )
        .unwrap();
        drop(server);
        let mut response = String::new();
        client.read_to_string(&mut response).unwrap();
        upstream_thread.join().unwrap();

        assert!(response.ends_with("fresh"));
        let refreshed = read_cached_proxy_response(
            &policy.cache_dir,
            &destination,
            policy.cache_ttl,
            Utc::now(),
        )
        .unwrap();
        assert!(String::from_utf8_lossy(&refreshed).ends_with("fresh"));
    }

    #[test]
    fn forward_http_revalidates_stale_cached_get_with_validators() {
        let temp = tempfile::tempdir().unwrap();
        let mut policy = test_policy(&temp);
        policy.cache_ttl = Duration::from_secs(1);
        let upstream = TcpListener::bind("127.0.0.1:0").unwrap();
        let destination = Destination {
            scheme: "http".into(),
            host: "127.0.0.1".into(),
            port: upstream.local_addr().unwrap().port(),
            path: "/package.tgz".into(),
        };
        let upstream_thread = thread::spawn(move || {
            let (mut stream, _) = upstream.accept().unwrap();
            stream.set_read_timeout(Some(IO_TIMEOUT)).unwrap();
            let mut reader = BufReader::new(stream.try_clone().unwrap());
            let mut request = String::new();
            loop {
                let mut line = String::new();
                reader.read_line(&mut line).unwrap();
                request.push_str(&line);
                if line == "\r\n" {
                    break;
                }
            }
            assert!(
                request.contains("If-None-Match: \"package-v1\""),
                "{request}"
            );
            assert!(
                request.contains("If-Modified-Since: Wed, 21 Oct 2015 07:28:00 GMT"),
                "{request}"
            );
            stream
                .write_all(
                    b"HTTP/1.1 304 Not Modified\r\nETag: \"package-v1\"\r\nConnection: close\r\n\r\n",
                )
                .unwrap();
        });
        let stale_at = Utc::now() - chrono::Duration::seconds(2);
        let cached = b"HTTP/1.1 200 OK\r\nETag: \"package-v1\"\r\nLast-Modified: Wed, 21 Oct 2015 07:28:00 GMT\r\nContent-Length: 6\r\nConnection: close\r\n\r\ncached";
        write_cached_proxy_response(&policy.cache_dir, &destination, cached, stale_at);
        let (mut client, mut server) = loopback_pair();

        forward_http_request(
            &mut server,
            &get_request(&format!("http://{}/package.tgz", destination.authority())),
            &destination,
            &policy,
        )
        .unwrap();
        drop(server);
        let mut response = String::new();
        client.read_to_string(&mut response).unwrap();
        upstream_thread.join().unwrap();

        assert!(response.ends_with("cached"));
        let refreshed = read_cached_proxy_response(
            &policy.cache_dir,
            &destination,
            policy.cache_ttl,
            Utc::now(),
        )
        .unwrap();
        assert!(String::from_utf8_lossy(&refreshed).ends_with("cached"));
    }

    #[test]
    fn forward_http_ignores_cache_when_ttl_is_zero() {
        let temp = tempfile::tempdir().unwrap();
        let mut policy = test_policy(&temp);
        policy.cache_ttl = Duration::from_secs(0);
        let (upstream_addr, upstream_thread) = upstream_once(b"live");
        let destination = Destination {
            scheme: "http".into(),
            host: "127.0.0.1".into(),
            port: upstream_addr.port(),
            path: "/package.tgz".into(),
        };
        let cached = b"HTTP/1.1 200 OK\r\nContent-Length: 6\r\nConnection: close\r\n\r\ncached";
        write_cached_proxy_response(&policy.cache_dir, &destination, cached, Utc::now());
        let (mut client, mut server) = loopback_pair();

        forward_http_request(
            &mut server,
            &get_request(&format!("http://{}/package.tgz", destination.authority())),
            &destination,
            &policy,
        )
        .unwrap();
        drop(server);
        let mut response = String::new();
        client.read_to_string(&mut response).unwrap();
        upstream_thread.join().unwrap();

        assert!(response.ends_with("live"));
    }

    #[test]
    fn forward_http_does_not_cache_credential_injected_responses() {
        let temp = tempfile::tempdir().unwrap();
        let mut environment = BTreeMap::new();
        environment.insert("CONDOM_CREDENTIAL_127_0_0_1".into(), "secret-token".into());
        let policy = ProxyPolicy {
            allowed_hosts: Vec::new(),
            allow_loopback: true,
            deny_metadata: true,
            deny_private: true,
            prompt_mode: PromptMode::Deny,
            require_logging: false,
            approval_store: test_approval_stores(&temp),
            instance_prompt_decisions: Arc::new(Mutex::new(BTreeMap::new())),
            credential_provider: ConfiguredCredentialProvider::Host(
                crate::auth::credentials::HostCredentialProvider::from_environment(
                    crate::model::config::CredentialSource::HostFilesEnv,
                    None,
                    &environment,
                ),
            ),
            cache_dir: temp.path().join("cache"),
            cache_ttl: Duration::from_secs(86_400),
        };
        let upstream = TcpListener::bind("127.0.0.1:0").unwrap();
        let destination = Destination {
            scheme: "http".into(),
            host: "127.0.0.1".into(),
            port: upstream.local_addr().unwrap().port(),
            path: "/private.tgz".into(),
        };
        let upstream_thread = thread::spawn(move || {
            let (mut stream, _) = upstream.accept().unwrap();
            stream.set_read_timeout(Some(IO_TIMEOUT)).unwrap();
            let mut reader = BufReader::new(stream.try_clone().unwrap());
            let mut request = String::new();
            loop {
                let mut line = String::new();
                reader.read_line(&mut line).unwrap();
                request.push_str(&line);
                if line == "\r\n" {
                    break;
                }
            }
            assert!(request.contains("Authorization: Bearer secret-token"));
            stream
                .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
                .unwrap();
        });
        let (mut client, mut server) = loopback_pair();

        forward_http_request(
            &mut server,
            &get_request(&format!("http://{}/private.tgz", destination.authority())),
            &destination,
            &policy,
        )
        .unwrap();
        drop(server);
        let mut response = String::new();
        client.read_to_string(&mut response).unwrap();
        upstream_thread.join().unwrap();

        assert!(response.ends_with("ok"));
        assert!(!proxy_cache_path(&policy.cache_dir, &destination).exists());
    }

    #[test]
    fn forward_http_fails_closed_when_credential_provider_fails() {
        let temp = tempfile::tempdir().unwrap();
        let command = vec![temp.path().join("missing-command").display().to_string()];
        let policy = ProxyPolicy {
            allowed_hosts: Vec::new(),
            allow_loopback: true,
            deny_metadata: true,
            deny_private: true,
            prompt_mode: PromptMode::Deny,
            require_logging: false,
            approval_store: test_approval_stores(&temp),
            instance_prompt_decisions: Arc::new(Mutex::new(BTreeMap::new())),
            credential_provider: ConfiguredCredentialProvider::HostCommand(
                HostCommandCredentialProvider::new(Some(&command)),
            ),
            cache_dir: temp.path().join("cache"),
            cache_ttl: Duration::from_secs(86_400),
        };
        let upstream = TcpListener::bind("127.0.0.1:0").unwrap();
        upstream.set_nonblocking(true).unwrap();
        let destination = Destination {
            scheme: "http".into(),
            host: "127.0.0.1".into(),
            port: upstream.local_addr().unwrap().port(),
            path: "/private.tgz".into(),
        };
        let (_client, mut server) = loopback_pair();

        let error = forward_http_request(
            &mut server,
            &get_request(&format!("http://{}/private.tgz", destination.authority())),
            &destination,
            &policy,
        )
        .unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied);
        assert!(error.to_string().contains("credential lookup failed"));
        assert!(matches!(
            upstream.accept(),
            Err(error) if error.kind() == io::ErrorKind::WouldBlock
        ));
    }

    #[test]
    fn forward_http_injects_helper_credentials() {
        let temp = tempfile::tempdir().unwrap();
        let project_root = temp.path().join("project");
        std::fs::create_dir_all(&project_root).unwrap();
        let socket = temp.path().join("helper.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        let helper = thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let request = helper::read_request(&mut stream).unwrap();
            assert!(matches!(
                request,
                helper::HelperRequest::Credential {
                    host,
                    path,
                    ..
                } if host == "127.0.0.1" && path == "/private.tgz"
            ));
            helper::write_response(
                stream,
                &helper::HelperResponse::Credential {
                    header_name: "Authorization".into(),
                    header_value: "Bearer helper-secret".into(),
                },
            )
            .unwrap();
        });
        let policy = ProxyPolicy {
            allowed_hosts: Vec::new(),
            allow_loopback: true,
            deny_metadata: true,
            deny_private: true,
            prompt_mode: PromptMode::Deny,
            require_logging: false,
            approval_store: test_approval_stores(&temp),
            instance_prompt_decisions: Arc::new(Mutex::new(BTreeMap::new())),
            credential_provider: ConfiguredCredentialProvider::Helper(
                HelperCredentialProvider::from_endpoint(
                    HelperEndpoint::Socket(socket),
                    &project_root,
                ),
            ),
            cache_dir: temp.path().join("cache"),
            cache_ttl: Duration::from_secs(86_400),
        };
        let upstream = TcpListener::bind("127.0.0.1:0").unwrap();
        let destination = Destination {
            scheme: "http".into(),
            host: "127.0.0.1".into(),
            port: upstream.local_addr().unwrap().port(),
            path: "/private.tgz".into(),
        };
        let upstream_thread = thread::spawn(move || {
            let (mut stream, _) = upstream.accept().unwrap();
            stream.set_read_timeout(Some(IO_TIMEOUT)).unwrap();
            let mut reader = BufReader::new(stream.try_clone().unwrap());
            let mut request = String::new();
            loop {
                let mut line = String::new();
                reader.read_line(&mut line).unwrap();
                request.push_str(&line);
                if line == "\r\n" {
                    break;
                }
            }
            assert!(request.contains("Authorization: Bearer helper-secret"));
            stream
                .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
                .unwrap();
        });
        let (mut client, mut server) = loopback_pair();

        forward_http_request(
            &mut server,
            &get_request(&format!("http://{}/private.tgz", destination.authority())),
            &destination,
            &policy,
        )
        .unwrap();
        drop(server);
        let mut response = String::new();
        client.read_to_string(&mut response).unwrap();
        helper.join().unwrap();
        upstream_thread.join().unwrap();

        assert!(response.ends_with("ok"));
    }

    #[test]
    fn connect_tunnel_preserves_buffered_client_payload() {
        let upstream_listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let upstream_addr = upstream_listener.local_addr().unwrap();
        let upstream = thread::spawn(move || {
            let (mut stream, _peer) = upstream_listener.accept().unwrap();
            stream.set_read_timeout(Some(IO_TIMEOUT)).unwrap();
            stream.set_write_timeout(Some(IO_TIMEOUT)).unwrap();
            let mut payload = [0; 4];
            stream.read_exact(&mut payload).unwrap();
            stream.write_all(b"pong").unwrap();
            payload
        });

        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let config = CondomConfig::default();
        let event_log = EventLog::new(temp.path().join("events.jsonl"));
        let context = ProxyWorkerContext {
            policy: ProxyPolicy::from_config(&config, &project, &state),
            project,
            mode: ExecutionMode::Run,
            command: vec!["curl".into()],
            event_log,
        };
        let active_workers = Arc::new(AtomicUsize::new(0));
        let (mut client, server) = loopback_pair();
        handle_accepted_proxy_client(server, &active_workers, context);
        client.set_read_timeout(Some(IO_TIMEOUT)).unwrap();
        client.set_write_timeout(Some(IO_TIMEOUT)).unwrap();
        write!(
            client,
            "CONNECT 127.0.0.1:{} HTTP/1.1\r\nHost: 127.0.0.1:{}\r\n\r\nping",
            upstream_addr.port(),
            upstream_addr.port()
        )
        .unwrap();
        client.shutdown(Shutdown::Write).unwrap();

        let mut response = String::new();
        client.read_to_string(&mut response).unwrap();

        assert!(response.starts_with("HTTP/1.1 200 Connection Established"));
        assert!(response.ends_with("pong"));
        assert_eq!(upstream.join().unwrap(), *b"ping");
    }

    #[test]
    fn start_proxy_fails_closed_without_transparent_routing() {
        let _guard = without_tproxy_env();
        let temp = tempfile::tempdir().unwrap();
        let (project, state) = test_project_and_state(&temp);
        let config = CondomConfig::default();
        let event_log = EventLog::new(temp.path().join("events.jsonl"));
        let error = match start_proxy(
            &config,
            &project,
            &state,
            ExecutionMode::Run,
            &["curl".into()],
            &event_log,
        ) {
            Ok(_) => panic!("proxy started without transparent routing"),
            Err(error) => error,
        };

        assert!(error
            .to_string()
            .contains("network enforcement unavailable: transparent proxy routing is not active"));
    }

    #[test]
    fn proxy_listener_fails_closed_when_transparent_port_is_busy() {
        let config = ProxyListenConfig {
            addr: SocketAddr::from((Ipv4Addr::LOCALHOST, 15080)),
            transparent_tcp_ports: vec![80, 443],
        };

        let error = match bind_proxy_listener_with(&config, |_| {
            Err(io::Error::from_raw_os_error(libc::EADDRINUSE))
        }) {
            Ok(_) => panic!("proxy listener started without transparent enforcement"),
            Err(error) => error,
        };
        let message = format!("{error:#}");

        assert!(message.contains("transparent proxy port 127.0.0.1:15080 is already in use"));
        assert!(message.contains("refusing to run without transparent network enforcement"));
    }

    #[test]
    fn stored_approval_allows_proxy_destination() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let mut config = CondomConfig::default();
        config.defaults.prompt_mode = PromptMode::Deny;
        let policy = ProxyPolicy::from_config(&config, &project, &state);
        policy
            .approval_store
            .add(
                Approval::new(
                    &project,
                    NewApproval {
                        decision: ApprovalDecision::Allow,
                        scope: ApprovalScope::Project,
                        kind: ApprovalKind::NetDomain,
                        subject: "example.test".into(),
                        ttl: None,
                        once: true,
                        reason: None,
                    },
                )
                .unwrap(),
            )
            .unwrap();
        let event_log = EventLog::new(temp.path().join("events.jsonl"));
        let destination = Destination {
            scheme: "http".into(),
            host: "example.test".into(),
            port: 80,
            path: "/".into(),
        };

        assert!(policy
            .authorize_destination(
                &destination,
                ProxyDecisionContext {
                    project: &project,
                    mode: ExecutionMode::Run,
                    command: &["npm".into()],
                    event_log: &event_log,
                },
            )
            .is_ok());
        let error = policy
            .authorize_destination(
                &destination,
                ProxyDecisionContext {
                    project: &project,
                    mode: ExecutionMode::Run,
                    command: &["npm".into()],
                    event_log: &event_log,
                },
            )
            .unwrap_err();
        assert!(error.contains("prompt mode is deny"));
    }

    #[test]
    fn persistent_prompt_deny_stores_project_scoped_approval() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let mut config = CondomConfig::default();
        config.defaults.prompt_mode = PromptMode::Deny;
        let policy = ProxyPolicy::from_config(&config, &project, &state);
        let event_log = EventLog::new(temp.path().join("events.jsonl"));

        let error = policy
            .apply_prompt_decision(
                PromptDecision::DenyProject,
                "example.test",
                ProxyDecisionContext {
                    project: &project,
                    mode: ExecutionMode::Run,
                    command: &["npm".into()],
                    event_log: &event_log,
                },
            )
            .unwrap_err();
        assert!(error.contains("denied by prompt"));

        let approvals = policy.approval_store.load().unwrap();
        assert_eq!(approvals.len(), 1);
        assert_eq!(approvals[0].decision, ApprovalDecision::Deny);
        assert_eq!(approvals[0].scope, ApprovalScope::Project);

        let destination = Destination {
            scheme: "http".into(),
            host: "example.test".into(),
            port: 80,
            path: "/".into(),
        };
        let stored_error = policy
            .authorize_destination(
                &destination,
                ProxyDecisionContext {
                    project: &project,
                    mode: ExecutionMode::Run,
                    command: &["curl".into()],
                    event_log: &event_log,
                },
            )
            .unwrap_err();
        assert!(stored_error.contains("stored approval"));
    }

    #[test]
    fn instance_prompt_allow_caches_host_without_storing_approval() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let mut config = CondomConfig::default();
        config.defaults.prompt_mode = PromptMode::Deny;
        let policy = ProxyPolicy::from_config(&config, &project, &state);
        let event_log = EventLog::new(temp.path().join("events.jsonl"));

        policy
            .apply_prompt_decision(
                PromptDecision::AllowInstance,
                "example.test",
                ProxyDecisionContext {
                    project: &project,
                    mode: ExecutionMode::Run,
                    command: &["curl".into()],
                    event_log: &event_log,
                },
            )
            .unwrap();
        let destination = Destination {
            scheme: "http".into(),
            host: "example.test".into(),
            port: 80,
            path: "/".into(),
        };

        policy
            .authorize_destination(
                &destination,
                ProxyDecisionContext {
                    project: &project,
                    mode: ExecutionMode::Run,
                    command: &["curl".into()],
                    event_log: &event_log,
                },
            )
            .unwrap();

        assert!(policy.approval_store.load().unwrap().is_empty());
    }

    #[test]
    fn required_prompt_logging_failure_rejects_prompt_decision() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let policy = ProxyPolicy::from_config(&CondomConfig::default(), &project, &state);
        let blocked_parent = temp.path().join("events-parent");
        std::fs::write(&blocked_parent, "not a directory").unwrap();
        let event_log = EventLog::new(blocked_parent.join("events.jsonl"));

        let error = policy
            .apply_prompt_decision(
                PromptDecision::AllowOnce,
                "example.test",
                ProxyDecisionContext {
                    project: &project,
                    mode: ExecutionMode::Run,
                    command: &["curl".into()],
                    event_log: &event_log,
                },
            )
            .unwrap_err();

        assert!(error.contains("failed to write required event log"));
    }

    #[test]
    fn instance_prompt_deny_caches_host_without_storing_approval() {
        let temp = tempfile::tempdir().unwrap();
        let project = ProjectContext {
            root: temp.path().join("project"),
            id: "project-id".into(),
            origin: None,
        };
        let state = StatePaths::from_base(&project, &temp.path().join("state"));
        let mut config = CondomConfig::default();
        config.defaults.prompt_mode = PromptMode::Deny;
        let policy = ProxyPolicy::from_config(&config, &project, &state);
        let event_log = EventLog::new(temp.path().join("events.jsonl"));

        let error = policy
            .apply_prompt_decision(
                PromptDecision::DenyInstance,
                "example.test",
                ProxyDecisionContext {
                    project: &project,
                    mode: ExecutionMode::Run,
                    command: &["curl".into()],
                    event_log: &event_log,
                },
            )
            .unwrap_err();
        let destination = Destination {
            scheme: "http".into(),
            host: "example.test".into(),
            port: 80,
            path: "/".into(),
        };
        let cached_error = policy
            .authorize_destination(
                &destination,
                ProxyDecisionContext {
                    project: &project,
                    mode: ExecutionMode::Run,
                    command: &["curl".into()],
                    event_log: &event_log,
                },
            )
            .unwrap_err();

        assert!(error.contains("denied by prompt"));
        assert!(cached_error.contains("instance prompt"));
        assert!(policy.approval_store.load().unwrap().is_empty());
    }
}
