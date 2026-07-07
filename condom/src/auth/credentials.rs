use std::collections::BTreeMap;
use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{bail, Result};

use crate::app::helper::probe::configured_authorization_endpoint;
use crate::app::helper::protocol::{
    request_helper, HelperEndpoint, HelperRequest, HelperResponse, HELPER_PROTOCOL_VERSION,
};
use crate::model::config::CredentialSource;

pub fn request_credential(
    endpoint: &HelperEndpoint,
    project_root: &Path,
    request: &CredentialRequest,
) -> Result<Option<InjectedCredential>> {
    let response = request_helper(
        endpoint,
        &HelperRequest::Credential {
            protocol_version: HELPER_PROTOCOL_VERSION,
            project_root: project_root.display().to_string(),
            scheme: request.scheme.clone(),
            host: request.host.clone(),
            port: request.port,
            method: request.method.clone(),
            path: request.path.clone(),
        },
    )?;
    match response {
        HelperResponse::Credential {
            header_name,
            header_value,
        } => Ok(Some(InjectedCredential {
            header_name,
            header_value,
        })),
        HelperResponse::CredentialUnavailable { .. } => Ok(None),
        HelperResponse::UnsupportedProtocol { expected, actual } => {
            bail!("helper protocol mismatch: expected {expected}, got {actual}")
        }
        HelperResponse::InvalidRequest { message }
        | HelperResponse::NotInstalled { message }
        | HelperResponse::MissingCapabilities { message, .. } => {
            bail!("helper refused credential request: {message}")
        }
        HelperResponse::Ready { .. } => {
            bail!("helper returned probe response to credential request")
        }
        HelperResponse::SandboxPrepared { .. } => {
            bail!("helper returned sandbox preparation response to credential request")
        }
        HelperResponse::SandboxRunFinished { .. } => {
            bail!("helper returned sandbox execution response to credential request")
        }
        HelperResponse::FilesystemAuthorization { .. } => {
            bail!("helper returned filesystem authorization response to credential request")
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CredentialRequest {
    pub scheme: String,
    pub host: String,
    pub port: u16,
    pub method: String,
    pub path: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct InjectedCredential {
    pub header_name: String,
    pub header_value: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CredentialLookupError {
    reason: String,
}

impl CredentialLookupError {
    fn new(reason: impl Into<String>) -> Self {
        Self {
            reason: reason.into(),
        }
    }
}

impl fmt::Display for CredentialLookupError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.reason)
    }
}

impl std::error::Error for CredentialLookupError {}

pub trait CredentialProvider {
    fn credential_for(
        &self,
        request: &CredentialRequest,
    ) -> Result<Option<InjectedCredential>, CredentialLookupError>;
}

#[derive(Clone, Eq, PartialEq)]
pub struct HostCredentialProvider {
    source: CredentialSource,
    environment: BTreeMap<String, String>,
    file_credentials: BTreeMap<String, String>,
    file_error: Option<String>,
}

#[derive(Clone, Eq, PartialEq)]
pub struct HelperCredentialProvider {
    endpoint: Option<HelperEndpoint>,
    project_root: PathBuf,
}

#[derive(Clone, Eq, PartialEq)]
pub struct HostCommandCredentialProvider {
    command: Option<Vec<String>>,
}

#[derive(Clone, Eq, PartialEq)]
pub struct PassCredentialProvider {
    prefix: Option<String>,
    program: String,
}

#[derive(Clone, Eq, PartialEq)]
pub struct SecretToolCredentialProvider {
    service: Option<String>,
    program: String,
}

#[derive(Clone, Eq, PartialEq)]
pub enum ConfiguredCredentialProvider {
    Host(HostCredentialProvider),
    Helper(HelperCredentialProvider),
    HostCommand(HostCommandCredentialProvider),
    Pass(PassCredentialProvider),
    SecretTool(SecretToolCredentialProvider),
}

#[derive(Default, serde::Deserialize)]
#[serde(default, deny_unknown_fields)]
struct CredentialFile {
    hosts: BTreeMap<String, String>,
}

impl HostCredentialProvider {
    pub fn from_environment(
        source: CredentialSource,
        credential_file: Option<&Path>,
        environment: &BTreeMap<String, String>,
    ) -> Self {
        let (file_credentials, file_error) = match credential_file {
            Some(path) => match load_credential_file(path) {
                Ok(credentials) => (credentials, None),
                Err(error) => (BTreeMap::new(), Some(error.to_string())),
            },
            None => (BTreeMap::new(), None),
        };
        Self {
            source,
            environment: environment
                .iter()
                .filter(|(key, value)| key.starts_with("CONDOM_CREDENTIAL_") && !value.is_empty())
                .map(|(key, value)| (key.clone(), value.clone()))
                .collect(),
            file_credentials,
            file_error,
        }
    }

    pub fn from_current_environment(
        source: CredentialSource,
        credential_file: Option<&Path>,
    ) -> Self {
        Self::from_environment(source, credential_file, &std::env::vars().collect())
    }
}

impl HelperCredentialProvider {
    pub fn from_configured_endpoint(project_root: &Path) -> Self {
        Self {
            endpoint: configured_authorization_endpoint(),
            project_root: project_root.to_path_buf(),
        }
    }

    pub fn from_endpoint(endpoint: HelperEndpoint, project_root: &Path) -> Self {
        Self {
            endpoint: Some(endpoint),
            project_root: project_root.to_path_buf(),
        }
    }
}

impl HostCommandCredentialProvider {
    pub fn new(command: Option<&[String]>) -> Self {
        Self {
            command: command.map(<[String]>::to_vec),
        }
    }
}

impl PassCredentialProvider {
    pub fn new(prefix: Option<&str>) -> Self {
        Self::with_program(prefix, "pass")
    }

    fn with_program(prefix: Option<&str>, program: impl Into<String>) -> Self {
        Self {
            prefix: prefix
                .map(str::trim)
                .filter(|prefix| !prefix.is_empty())
                .map(str::to_string),
            program: program.into(),
        }
    }

    fn entry_for(&self, host: &str) -> String {
        let host = credential_file_key(host);
        match &self.prefix {
            Some(prefix) => format!("{}/{}", prefix.trim_matches('/'), host),
            None => format!("condom/{host}"),
        }
    }
}

impl SecretToolCredentialProvider {
    pub fn new(service: Option<&str>) -> Self {
        Self::with_program(service, "secret-tool")
    }

    fn with_program(service: Option<&str>, program: impl Into<String>) -> Self {
        Self {
            service: service
                .map(str::trim)
                .filter(|service| !service.is_empty())
                .map(str::to_string),
            program: program.into(),
        }
    }

    fn service(&self) -> &str {
        self.service.as_deref().unwrap_or("condom")
    }
}

impl ConfiguredCredentialProvider {
    pub fn from_current_environment(
        source: CredentialSource,
        credential_file: Option<&Path>,
        credential_command: Option<&[String]>,
        credential_pass_prefix: Option<&str>,
        credential_secret_service: Option<&str>,
        project_root: &Path,
    ) -> Self {
        match source {
            CredentialSource::HostFilesEnv | CredentialSource::HostFile => Self::Host(
                HostCredentialProvider::from_current_environment(source, credential_file),
            ),
            CredentialSource::HostCommand => {
                Self::HostCommand(HostCommandCredentialProvider::new(credential_command))
            }
            CredentialSource::Pass => {
                Self::Pass(PassCredentialProvider::new(credential_pass_prefix))
            }
            CredentialSource::SecretTool => {
                Self::SecretTool(SecretToolCredentialProvider::new(credential_secret_service))
            }
            CredentialSource::Helper => Self::Helper(
                HelperCredentialProvider::from_configured_endpoint(project_root),
            ),
        }
    }
}

impl fmt::Debug for HostCredentialProvider {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("HostCredentialProvider")
            .field("source", &self.source)
            .field("credential_count", &self.environment.len())
            .field("file_credential_count", &self.file_credentials.len())
            .finish()
    }
}

impl fmt::Debug for HelperCredentialProvider {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("HelperCredentialProvider")
            .field("endpoint_configured", &self.endpoint.is_some())
            .field("project_root", &self.project_root)
            .finish()
    }
}

impl fmt::Debug for HostCommandCredentialProvider {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("HostCommandCredentialProvider")
            .field("command_configured", &self.command.is_some())
            .finish()
    }
}

impl fmt::Debug for PassCredentialProvider {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("PassCredentialProvider")
            .field("prefix_configured", &self.prefix.is_some())
            .finish()
    }
}

impl fmt::Debug for SecretToolCredentialProvider {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("SecretToolCredentialProvider")
            .field("service_configured", &self.service.is_some())
            .finish()
    }
}

impl fmt::Debug for ConfiguredCredentialProvider {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Host(provider) => provider.fmt(formatter),
            Self::Helper(provider) => provider.fmt(formatter),
            Self::HostCommand(provider) => provider.fmt(formatter),
            Self::Pass(provider) => provider.fmt(formatter),
            Self::SecretTool(provider) => provider.fmt(formatter),
        }
    }
}

impl CredentialProvider for HostCredentialProvider {
    fn credential_for(
        &self,
        request: &CredentialRequest,
    ) -> Result<Option<InjectedCredential>, CredentialLookupError> {
        if let Some(error) = &self.file_error {
            return Err(CredentialLookupError::new(format!(
                "configured credential file failed: {error}"
            )));
        }
        let token = match self.source {
            CredentialSource::HostFilesEnv => self
                .environment
                .get(&credential_env_key(&request.host))
                .cloned(),
            CredentialSource::HostFile => self
                .file_credentials
                .get(&credential_file_key(&request.host))
                .cloned(),
            CredentialSource::HostCommand => None,
            CredentialSource::Pass => None,
            CredentialSource::SecretTool => None,
            CredentialSource::Helper => None,
        };
        let Some(token) = token else {
            return Ok(None);
        };
        Ok(Some(InjectedCredential {
            header_name: "Authorization".into(),
            header_value: format!("Bearer {token}"),
        }))
    }
}

impl CredentialProvider for HelperCredentialProvider {
    fn credential_for(
        &self,
        request: &CredentialRequest,
    ) -> Result<Option<InjectedCredential>, CredentialLookupError> {
        let endpoint = self.endpoint.as_ref().ok_or_else(|| {
            CredentialLookupError::new("credential helper endpoint is not configured")
        })?;
        request_credential(endpoint, &self.project_root, request).map_err(|error| {
            CredentialLookupError::new(format!("credential helper failed: {error:#}"))
        })
    }
}

impl CredentialProvider for HostCommandCredentialProvider {
    fn credential_for(
        &self,
        request: &CredentialRequest,
    ) -> Result<Option<InjectedCredential>, CredentialLookupError> {
        let command = self
            .command
            .as_ref()
            .ok_or_else(|| CredentialLookupError::new("credential command is not configured"))?;
        let program = command
            .first()
            .ok_or_else(|| CredentialLookupError::new("credential command is empty"))?;
        let output = Command::new(program)
            .args(&command[1..])
            .env("CONDOM_CREDENTIAL_SCHEME", &request.scheme)
            .env("CONDOM_CREDENTIAL_HOST", &request.host)
            .env("CONDOM_CREDENTIAL_PORT", request.port.to_string())
            .env("CONDOM_CREDENTIAL_METHOD", &request.method)
            .env("CONDOM_CREDENTIAL_PATH", &request.path)
            .output()
            .map_err(|error| {
                CredentialLookupError::new(format!("credential command failed to start: {error}"))
            })?;
        if !output.status.success() {
            return Err(CredentialLookupError::new(format!(
                "credential command exited with status {}",
                output.status
            )));
        }
        let token = String::from_utf8_lossy(&output.stdout)
            .lines()
            .map(str::trim)
            .find(|line| !line.is_empty())
            .ok_or_else(|| CredentialLookupError::new("credential command returned no token"))?
            .to_string();
        Ok(Some(InjectedCredential {
            header_name: "Authorization".into(),
            header_value: format!("Bearer {token}"),
        }))
    }
}

impl CredentialProvider for PassCredentialProvider {
    fn credential_for(
        &self,
        request: &CredentialRequest,
    ) -> Result<Option<InjectedCredential>, CredentialLookupError> {
        let output = Command::new(&self.program)
            .arg("show")
            .arg(self.entry_for(&request.host))
            .env("CONDOM_CREDENTIAL_SCHEME", &request.scheme)
            .env("CONDOM_CREDENTIAL_HOST", &request.host)
            .env("CONDOM_CREDENTIAL_PORT", request.port.to_string())
            .env("CONDOM_CREDENTIAL_METHOD", &request.method)
            .env("CONDOM_CREDENTIAL_PATH", &request.path)
            .output()
            .map_err(|error| {
                CredentialLookupError::new(format!(
                    "pass credential provider failed to start: {error}"
                ))
            })?;
        if !output.status.success() {
            return Err(CredentialLookupError::new(format!(
                "pass credential provider exited with status {}",
                output.status
            )));
        }
        let token = String::from_utf8_lossy(&output.stdout)
            .lines()
            .map(str::trim)
            .find(|line| !line.is_empty())
            .ok_or_else(|| {
                CredentialLookupError::new("pass credential provider returned no token")
            })?
            .to_string();
        Ok(Some(InjectedCredential {
            header_name: "Authorization".into(),
            header_value: format!("Bearer {token}"),
        }))
    }
}

impl CredentialProvider for SecretToolCredentialProvider {
    fn credential_for(
        &self,
        request: &CredentialRequest,
    ) -> Result<Option<InjectedCredential>, CredentialLookupError> {
        let output = Command::new(&self.program)
            .args([
                "lookup",
                "service",
                self.service(),
                "host",
                &credential_file_key(&request.host),
            ])
            .env("CONDOM_CREDENTIAL_SCHEME", &request.scheme)
            .env("CONDOM_CREDENTIAL_HOST", &request.host)
            .env("CONDOM_CREDENTIAL_PORT", request.port.to_string())
            .env("CONDOM_CREDENTIAL_METHOD", &request.method)
            .env("CONDOM_CREDENTIAL_PATH", &request.path)
            .output()
            .map_err(|error| {
                CredentialLookupError::new(format!(
                    "secret-tool credential provider failed to start: {error}"
                ))
            })?;
        if !output.status.success() {
            return Err(CredentialLookupError::new(format!(
                "secret-tool credential provider exited with status {}",
                output.status
            )));
        }
        let token = String::from_utf8_lossy(&output.stdout)
            .lines()
            .map(str::trim)
            .find(|line| !line.is_empty())
            .ok_or_else(|| {
                CredentialLookupError::new("secret-tool credential provider returned no token")
            })?
            .to_string();
        Ok(Some(InjectedCredential {
            header_name: "Authorization".into(),
            header_value: format!("Bearer {token}"),
        }))
    }
}

impl CredentialProvider for ConfiguredCredentialProvider {
    fn credential_for(
        &self,
        request: &CredentialRequest,
    ) -> Result<Option<InjectedCredential>, CredentialLookupError> {
        match self {
            Self::Host(provider) => provider.credential_for(request),
            Self::Helper(provider) => provider.credential_for(request),
            Self::HostCommand(provider) => provider.credential_for(request),
            Self::Pass(provider) => provider.credential_for(request),
            Self::SecretTool(provider) => provider.credential_for(request),
        }
    }
}

fn load_credential_file(path: &Path) -> Result<BTreeMap<String, String>, CredentialLookupError> {
    let content = fs::read_to_string(path).map_err(|error| {
        CredentialLookupError::new(format!(
            "failed to read credential file {}: {error}",
            path.display()
        ))
    })?;
    let file = toml::from_str::<CredentialFile>(&content).map_err(|error| {
        CredentialLookupError::new(format!(
            "failed to parse credential file {}: {error}",
            path.display()
        ))
    })?;
    Ok(file
        .hosts
        .into_iter()
        .filter(|(_, value)| !value.is_empty())
        .map(|(host, value)| (credential_file_key(&host), value))
        .collect())
}

pub fn credential_env_key(host: &str) -> String {
    let normalized = credential_file_key(host)
        .chars()
        .map(|ch| {
            if ch.is_ascii_alphanumeric() {
                ch.to_ascii_uppercase()
            } else {
                '_'
            }
        })
        .collect::<String>();
    format!("CONDOM_CREDENTIAL_{normalized}")
}

fn credential_file_key(host: &str) -> String {
    let normalized = host
        .trim()
        .trim_start_matches('[')
        .trim_end_matches(']')
        .trim_end_matches('.')
        .to_ascii_lowercase();
    normalized
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app::helper;
    use std::io::{Read, Write};
    use std::os::unix::fs::PermissionsExt;
    use std::os::unix::net::UnixListener;
    use std::thread;

    fn request(host: &str) -> CredentialRequest {
        CredentialRequest {
            scheme: "https".into(),
            host: host.into(),
            port: 443,
            method: "GET".into(),
            path: "/package".into(),
        }
    }

    #[test]
    fn credential_env_key_normalizes_host_names() {
        assert_eq!(
            credential_env_key("127.0.0.1"),
            "CONDOM_CREDENTIAL_127_0_0_1"
        );
        assert_eq!(
            credential_env_key("Registry.Example.Test."),
            "CONDOM_CREDENTIAL_REGISTRY_EXAMPLE_TEST"
        );
    }

    #[test]
    fn host_env_provider_returns_authorization_header() {
        let mut environment = BTreeMap::new();
        environment.insert(
            "CONDOM_CREDENTIAL_REGISTRY_EXAMPLE_TEST".into(),
            "secret-token".into(),
        );
        environment.insert("CONDOM_CREDENTIAL_EMPTY_EXAMPLE".into(), String::new());
        environment.insert("SOURCE_TOKEN".into(), "not-a-provider-key".into());
        let provider = HostCredentialProvider::from_environment(
            CredentialSource::HostFilesEnv,
            None,
            &environment,
        );

        assert_eq!(
            provider.credential_for(&request("registry.example.test")),
            Ok(Some(InjectedCredential {
                header_name: "Authorization".into(),
                header_value: "Bearer secret-token".into(),
            }))
        );
        assert_eq!(provider.credential_for(&request("empty.example")), Ok(None));
        assert_eq!(
            provider.credential_for(&request("source.example.test")),
            Ok(None)
        );
    }

    #[test]
    fn host_env_provider_debug_omits_secret_values() {
        let mut environment = BTreeMap::new();
        environment.insert(
            "CONDOM_CREDENTIAL_REGISTRY_EXAMPLE_TEST".into(),
            "secret-token".into(),
        );
        let provider = HostCredentialProvider::from_environment(
            CredentialSource::HostFilesEnv,
            None,
            &environment,
        );

        let debug = format!("{provider:?}");

        assert!(debug.contains("credential_count"));
        assert!(!debug.contains("secret-token"));
    }

    #[test]
    fn host_file_provider_returns_authorization_header() {
        let temp = tempfile::tempdir().unwrap();
        let credential_file = temp.path().join("credentials.toml");
        fs::write(
            &credential_file,
            "[hosts]\n\"registry.example.test\" = \"file-secret\"\n\"empty.example\" = \"\"\n",
        )
        .unwrap();
        let mut environment = BTreeMap::new();
        environment.insert(
            "CONDOM_CREDENTIAL_REGISTRY_EXAMPLE_TEST".into(),
            "env-secret".into(),
        );
        let provider = HostCredentialProvider::from_environment(
            CredentialSource::HostFile,
            Some(&credential_file),
            &environment,
        );

        assert_eq!(
            provider.credential_for(&request("Registry.Example.Test.")),
            Ok(Some(InjectedCredential {
                header_name: "Authorization".into(),
                header_value: "Bearer file-secret".into(),
            }))
        );
        assert_eq!(provider.credential_for(&request("empty.example")), Ok(None));
        assert_eq!(
            provider.credential_for(&request("source.example.test")),
            Ok(None)
        );
    }

    #[test]
    fn host_file_provider_debug_omits_secret_values() {
        let temp = tempfile::tempdir().unwrap();
        let credential_file = temp.path().join("credentials.toml");
        fs::write(
            &credential_file,
            "[hosts]\n\"registry.example.test\" = \"file-secret\"\n",
        )
        .unwrap();
        let provider = HostCredentialProvider::from_environment(
            CredentialSource::HostFile,
            Some(&credential_file),
            &BTreeMap::new(),
        );

        let debug = format!("{provider:?}");

        assert!(debug.contains("file_credential_count"));
        assert!(!debug.contains("file-secret"));
    }

    #[test]
    fn host_command_provider_returns_authorization_header() {
        let command = vec![
            "sh".into(),
            "-c".into(),
            r#"test "$CONDOM_CREDENTIAL_HOST" = registry.example.test &&
test "$CONDOM_CREDENTIAL_PATH" = /package &&
printf command-secret"#
                .into(),
        ];
        let provider = HostCommandCredentialProvider::new(Some(&command));

        assert_eq!(
            provider.credential_for(&request("registry.example.test")),
            Ok(Some(InjectedCredential {
                header_name: "Authorization".into(),
                header_value: "Bearer command-secret".into(),
            }))
        );
    }

    #[test]
    fn host_command_provider_errors_when_command_fails() {
        let command = vec!["sh".into(), "-c".into(), "exit 42".into()];
        let provider = HostCommandCredentialProvider::new(Some(&command));

        let error = provider
            .credential_for(&request("registry.example.test"))
            .unwrap_err();

        assert!(error.to_string().contains("credential command exited"));
    }

    #[test]
    fn host_command_provider_debug_omits_command_arguments() {
        let command = vec![
            "secret-provider".into(),
            "read".into(),
            "secret-token-path".into(),
        ];
        let provider = HostCommandCredentialProvider::new(Some(&command));

        let debug = format!("{provider:?}");

        assert!(debug.contains("command_configured"));
        assert!(!debug.contains("secret-token-path"));
    }

    #[test]
    fn pass_provider_returns_authorization_header() {
        let temp = tempfile::tempdir().unwrap();
        let pass = temp.path().join("pass");
        {
            let mut script = fs::File::create(&pass).unwrap();
            write!(
                script,
                r#"#!/bin/sh
test "$1" = show || exit 1
test "$2" = registries/registry.example.test || exit 1
test "$CONDOM_CREDENTIAL_HOST" = registry.example.test || exit 1
printf 'pass-secret\nmetadata\n'
"#,
            )
            .unwrap();
            script.sync_all().unwrap();
        }
        fs::set_permissions(&pass, fs::Permissions::from_mode(0o755)).unwrap();
        let provider =
            PassCredentialProvider::with_program(Some("registries"), pass.display().to_string());

        let credential = provider.credential_for(&request("registry.example.test"));

        assert_eq!(
            credential,
            Ok(Some(InjectedCredential {
                header_name: "Authorization".into(),
                header_value: "Bearer pass-secret".into(),
            }))
        );
    }

    #[test]
    fn pass_provider_errors_when_program_fails() {
        let provider = PassCredentialProvider::with_program(Some("registries"), "missing-pass");

        let error = provider
            .credential_for(&request("registry.example.test"))
            .unwrap_err();

        assert!(error.to_string().contains("pass credential provider"));
    }

    #[test]
    fn pass_provider_debug_omits_prefix_and_entry() {
        let provider = PassCredentialProvider::new(Some("secret-token-path"));

        let debug = format!("{provider:?}");

        assert!(debug.contains("prefix_configured"));
        assert!(!debug.contains("secret-token-path"));
        assert!(!debug.contains("registry.example.test"));
    }

    #[test]
    fn secret_tool_provider_returns_authorization_header() {
        let temp = tempfile::tempdir().unwrap();
        let secret_tool = temp.path().join("secret-tool");
        {
            let mut script = fs::File::create(&secret_tool).unwrap();
            write!(
                script,
                r#"#!/bin/sh
test "$1" = lookup || exit 1
test "$2" = service || exit 1
test "$3" = registries || exit 1
test "$4" = host || exit 1
test "$5" = registry.example.test || exit 1
test "$CONDOM_CREDENTIAL_HOST" = registry.example.test || exit 1
printf 'secret-tool-secret\nmetadata\n'
"#,
            )
            .unwrap();
        }
        fs::set_permissions(&secret_tool, fs::Permissions::from_mode(0o755)).unwrap();
        let provider = SecretToolCredentialProvider::with_program(
            Some("registries"),
            secret_tool.display().to_string(),
        );

        assert_eq!(
            provider.credential_for(&request("registry.example.test")),
            Ok(Some(InjectedCredential {
                header_name: "Authorization".into(),
                header_value: "Bearer secret-tool-secret".into(),
            }))
        );
    }

    #[test]
    fn secret_tool_provider_errors_when_program_fails() {
        let provider =
            SecretToolCredentialProvider::with_program(Some("registries"), "missing-secret-tool");

        let error = provider
            .credential_for(&request("registry.example.test"))
            .unwrap_err();

        assert!(error
            .to_string()
            .contains("secret-tool credential provider"));
    }

    #[test]
    fn secret_tool_provider_debug_omits_service_and_host() {
        let provider = SecretToolCredentialProvider::new(Some("secret-service-name"));

        let debug = format!("{provider:?}");

        assert!(debug.contains("service_configured"));
        assert!(!debug.contains("secret-service-name"));
        assert!(!debug.contains("registry.example.test"));
    }

    #[test]
    fn helper_provider_returns_authorization_header() {
        let temp = tempfile::tempdir().unwrap();
        let project_root = temp.path().join("project");
        fs::create_dir_all(&project_root).unwrap();
        let socket = temp.path().join("helper.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        let helper = thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let mut input = String::new();
            stream.read_to_string(&mut input).unwrap();
            let request = serde_json::from_str::<HelperRequest>(&input).unwrap();
            assert!(matches!(
                request,
                HelperRequest::Credential {
                    host,
                    path,
                    ..
                } if host == "registry.example.test" && path == "/package"
            ));
            helper::write_response(
                stream,
                &HelperResponse::Credential {
                    header_name: "Authorization".into(),
                    header_value: "Bearer helper-secret".into(),
                },
            )
            .unwrap();
        });
        let provider =
            HelperCredentialProvider::from_endpoint(HelperEndpoint::Socket(socket), &project_root);

        assert_eq!(
            provider.credential_for(&request("registry.example.test")),
            Ok(Some(InjectedCredential {
                header_name: "Authorization".into(),
                header_value: "Bearer helper-secret".into(),
            }))
        );
        helper.join().unwrap();
    }

    #[test]
    fn helper_provider_debug_omits_secret_values() {
        let temp = tempfile::tempdir().unwrap();
        let provider = HelperCredentialProvider::from_endpoint(
            HelperEndpoint::Binary(PathBuf::from("/run/condom/helper")),
            temp.path(),
        );

        let debug = format!("{provider:?}");

        assert!(debug.contains("endpoint_configured"));
        assert!(!debug.contains("helper-secret"));
    }
}
