use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
pub struct CondomConfig {
    pub defaults: Defaults,
    pub shims: BTreeMap<String, ShimRoute>,
    pub environment: EnvironmentConfig,
    pub filesystem: FilesystemConfig,
    pub exec: ExecConfig,
    pub network: NetworkConfig,
    pub proxy: ProxyConfig,
    pub review: ReviewConfig,
    pub events: EventsConfig,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
pub struct Defaults {
    pub prompt_mode: PromptMode,
    pub helper_mode: HelperMode,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum PromptMode {
    Tty,
    Deny,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum HelperMode {
    NixosRootHelper,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct ShimRoute {
    pub mode: ExecutionMode,
}

#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
pub struct EnvironmentConfig {
    pub allow: Vec<String>,
    pub deny: Vec<String>,
}

impl EnvironmentConfig {
    pub fn validate(&self) -> Result<()> {
        for key in self.allow.iter().chain(&self.deny) {
            validate_environment_key(key)?;
        }
        Ok(())
    }
}

pub fn validate_environment_key(key: &str) -> Result<()> {
    if key.is_empty() {
        anyhow::bail!("environment variable name cannot be empty");
    }
    if key.contains('=') {
        anyhow::bail!("environment variable name `{key}` cannot contain `=`");
    }
    if is_runtime_environment_key(key) {
        anyhow::bail!("environment variable `{key}` is owned by the condom runtime");
    }
    Ok(())
}

pub fn is_runtime_environment_key(key: &str) -> bool {
    matches!(key, "PATH" | "HOME" | "TMPDIR" | "TMP" | "TEMP") || key.starts_with("CONDOM_")
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ExecutionMode {
    Run,
    Review,
}

impl ExecutionMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Run => "run",
            Self::Review => "review",
        }
    }
}

#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
pub struct FilesystemConfig {
    pub allow_read: Vec<String>,
    pub allow_write: Vec<String>,
    pub allow_execute: Vec<String>,
    pub deny_read: Vec<String>,
    pub deny_write: Vec<String>,
    pub redact_read: Vec<String>,
}

#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
pub struct ExecConfig {
    pub allow: Vec<String>,
    pub deny: Vec<String>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
pub struct NetworkConfig {
    pub allow_loopback: bool,
    pub deny_metadata: bool,
    pub deny_private: bool,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
pub struct ProxyConfig {
    pub adapters: Vec<String>,
    pub credential_source: CredentialSource,
    pub credential_file: Option<String>,
    pub credential_command: Option<Vec<String>>,
    pub credential_pass_prefix: Option<String>,
    pub credential_secret_service: Option<String>,
    pub cache_ttl_seconds: u64,
    pub allowed_hosts: Vec<String>,
    pub npm_registry: Option<String>,
    pub npm_ignore_scripts: bool,
    pub pip_index_url: Option<String>,
    pub pip_no_input: bool,
    pub pip_disable_version_check: bool,
    pub cargo_git_fetch_with_cli: Option<bool>,
    pub go_proxy: Option<String>,
    pub go_sumdb: Option<String>,
    pub go_vcs: Option<String>,
    pub go_auth: Option<String>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum CredentialSource {
    HostFilesEnv,
    HostFile,
    HostCommand,
    Pass,
    SecretTool,
    Helper,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
pub struct ReviewConfig {
    pub artifact_mode: ReviewArtifactMode,
    pub conflict_policy: ConflictPolicy,
    pub file_rules: Vec<ReviewFileRule>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ReviewArtifactMode {
    JournalAndDiff,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct ReviewFileRule {
    #[serde(rename = "match")]
    pub pattern: String,
    #[serde(default)]
    pub visibility: ReviewFileVisibility,
    #[serde(default)]
    pub default_selected: Option<bool>,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ReviewFileVisibility {
    #[default]
    Normal,
    Hidden,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ConflictPolicy {
    DetectRefuseThenAskOverride,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
pub struct EventsConfig {
    pub require_logging: bool,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
struct PartialConfig {
    defaults: Option<PartialDefaults>,
    shims: Option<BTreeMap<String, ShimRoute>>,
    environment: Option<PartialEnvironmentConfig>,
    filesystem: Option<PartialFilesystemConfig>,
    exec: Option<PartialExecConfig>,
    network: Option<PartialNetworkConfig>,
    proxy: Option<PartialProxyConfig>,
    review: Option<PartialReviewConfig>,
    events: Option<PartialEventsConfig>,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
struct PartialDefaults {
    prompt_mode: Option<PromptMode>,
    helper_mode: Option<HelperMode>,
    event_logging: Option<bool>,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
struct PartialEnvironmentConfig {
    allow: Option<Vec<String>>,
    deny: Option<Vec<String>>,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
struct PartialFilesystemConfig {
    allow_read: Option<Vec<String>>,
    allow_write: Option<Vec<String>>,
    allow_execute: Option<Vec<String>>,
    deny_read: Option<Vec<String>>,
    deny_write: Option<Vec<String>>,
    redact_read: Option<Vec<String>>,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
struct PartialExecConfig {
    allow: Option<Vec<String>>,
    deny: Option<Vec<String>>,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
struct PartialNetworkConfig {
    allow_loopback: Option<bool>,
    deny_metadata: Option<bool>,
    deny_private: Option<bool>,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
struct PartialProxyConfig {
    adapters: Option<Vec<String>>,
    credential_source: Option<CredentialSource>,
    credential_file: Option<Option<String>>,
    credential_command: Option<Option<Vec<String>>>,
    credential_pass_prefix: Option<Option<String>>,
    credential_secret_service: Option<Option<String>>,
    cache_ttl_seconds: Option<u64>,
    allowed_hosts: Option<Vec<String>>,
    npm_registry: Option<Option<String>>,
    npm_ignore_scripts: Option<bool>,
    pip_index_url: Option<Option<String>>,
    pip_no_input: Option<bool>,
    pip_disable_version_check: Option<bool>,
    cargo_git_fetch_with_cli: Option<Option<bool>>,
    go_proxy: Option<Option<String>>,
    go_sumdb: Option<Option<String>>,
    go_vcs: Option<Option<String>>,
    go_auth: Option<Option<String>>,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
struct PartialReviewConfig {
    artifact_mode: Option<ReviewArtifactMode>,
    conflict_policy: Option<ConflictPolicy>,
    file_rules: Option<Vec<ReviewFileRule>>,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "camelCase")]
struct PartialEventsConfig {
    require_logging: Option<bool>,
}

impl CondomConfig {
    pub fn load(project_root: &Path, global_config: Option<&Path>) -> Result<Self> {
        let mut config = Self::default();
        if let Some(path) = global_config.filter(|path| path.is_file()) {
            config.merge_file(path)?;
        }
        let project_config = project_root.join(".condom/config.toml");
        if project_config.is_file() {
            config.merge_file(&project_config)?;
        }
        config.validate()?;
        Ok(config)
    }

    pub fn write_default(path: &Path) -> Result<()> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("failed to create {}", parent.display()))?;
        }
        let content =
            toml::to_string_pretty(&Self::default()).context("failed to render config")?;
        fs::write(path, content).with_context(|| format!("failed to write {}", path.display()))
    }

    fn merge_file(&mut self, path: &Path) -> Result<()> {
        let content = fs::read_to_string(path)
            .with_context(|| format!("failed to read {}", path.display()))?;
        let partial: PartialConfig = toml::from_str(&content)
            .with_context(|| format!("failed to parse {}", path.display()))?;
        self.merge(partial);
        Ok(())
    }

    fn merge(&mut self, partial: PartialConfig) {
        let default_event_logging = partial
            .defaults
            .as_ref()
            .and_then(|defaults| defaults.event_logging);
        let event_require_logging = partial
            .events
            .as_ref()
            .and_then(|events| events.require_logging);
        if let Some(defaults) = partial.defaults {
            if let Some(value) = defaults.prompt_mode {
                self.defaults.prompt_mode = value;
            }
            if let Some(value) = defaults.helper_mode {
                self.defaults.helper_mode = value;
            }
        }
        if let Some(shims) = partial.shims {
            self.shims.extend(shims);
        }
        if let Some(environment) = partial.environment {
            if let Some(value) = environment.allow {
                self.environment.allow = value;
            }
            if let Some(value) = environment.deny {
                self.environment.deny = value;
            }
        }
        if let Some(filesystem) = partial.filesystem {
            if let Some(value) = filesystem.allow_read {
                self.filesystem.allow_read = value;
            }
            if let Some(value) = filesystem.allow_write {
                self.filesystem.allow_write = value;
            }
            if let Some(value) = filesystem.allow_execute {
                self.filesystem.allow_execute = value;
            }
            if let Some(value) = filesystem.deny_read {
                self.filesystem.deny_read = value;
            }
            if let Some(value) = filesystem.deny_write {
                self.filesystem.deny_write = value;
            }
            if let Some(value) = filesystem.redact_read {
                self.filesystem.redact_read = value;
            }
        }
        if let Some(exec) = partial.exec {
            if let Some(value) = exec.allow {
                self.exec.allow = value;
            }
            if let Some(value) = exec.deny {
                self.exec.deny = value;
            }
        }
        if let Some(network) = partial.network {
            if let Some(value) = network.allow_loopback {
                self.network.allow_loopback = value;
            }
            if let Some(value) = network.deny_metadata {
                self.network.deny_metadata = value;
            }
            if let Some(value) = network.deny_private {
                self.network.deny_private = value;
            }
        }
        if let Some(proxy) = partial.proxy {
            if let Some(value) = proxy.adapters {
                self.proxy.adapters = value;
            }
            if let Some(value) = proxy.credential_source {
                self.proxy.credential_source = value;
            }
            if let Some(value) = proxy.credential_file {
                self.proxy.credential_file = value;
            }
            if let Some(value) = proxy.credential_command {
                self.proxy.credential_command = value;
            }
            if let Some(value) = proxy.credential_pass_prefix {
                self.proxy.credential_pass_prefix = value;
            }
            if let Some(value) = proxy.credential_secret_service {
                self.proxy.credential_secret_service = value;
            }
            if let Some(value) = proxy.cache_ttl_seconds {
                self.proxy.cache_ttl_seconds = value;
            }
            if let Some(value) = proxy.allowed_hosts {
                self.proxy.allowed_hosts = value;
            }
            if let Some(value) = proxy.npm_registry {
                self.proxy.npm_registry = value;
            }
            if let Some(value) = proxy.npm_ignore_scripts {
                self.proxy.npm_ignore_scripts = value;
            }
            if let Some(value) = proxy.pip_index_url {
                self.proxy.pip_index_url = value;
            }
            if let Some(value) = proxy.pip_no_input {
                self.proxy.pip_no_input = value;
            }
            if let Some(value) = proxy.pip_disable_version_check {
                self.proxy.pip_disable_version_check = value;
            }
            if let Some(value) = proxy.cargo_git_fetch_with_cli {
                self.proxy.cargo_git_fetch_with_cli = value;
            }
            if let Some(value) = proxy.go_proxy {
                self.proxy.go_proxy = value;
            }
            if let Some(value) = proxy.go_sumdb {
                self.proxy.go_sumdb = value;
            }
            if let Some(value) = proxy.go_vcs {
                self.proxy.go_vcs = value;
            }
            if let Some(value) = proxy.go_auth {
                self.proxy.go_auth = value;
            }
        }
        if let Some(review) = partial.review {
            if let Some(value) = review.artifact_mode {
                self.review.artifact_mode = value;
            }
            if let Some(value) = review.conflict_policy {
                self.review.conflict_policy = value;
            }
            if let Some(value) = review.file_rules {
                self.review.file_rules = value;
            }
        }
        if let Some(events) = partial.events {
            if let Some(value) = events.require_logging {
                self.events.require_logging = value;
            }
        }
        if event_require_logging.is_none() {
            if let Some(value) = default_event_logging {
                self.events.require_logging = value;
            }
        }
    }

    fn validate(&self) -> Result<()> {
        self.environment.validate()?;
        self.review.validate()?;
        Ok(())
    }
}

impl Default for CondomConfig {
    fn default() -> Self {
        let mut shims = BTreeMap::new();
        for command in ["npm", "pnpm", "yarn", "npx", "pip", "uv", "cargo", "go"] {
            shims.insert(
                command.into(),
                ShimRoute {
                    mode: ExecutionMode::Run,
                },
            );
        }

        Self {
            defaults: Defaults::default(),
            shims,
            environment: EnvironmentConfig::default(),
            filesystem: FilesystemConfig::default(),
            exec: ExecConfig::default(),
            network: NetworkConfig::default(),
            proxy: ProxyConfig::default(),
            review: ReviewConfig::default(),
            events: EventsConfig::default(),
        }
    }
}

impl Default for Defaults {
    fn default() -> Self {
        Self {
            prompt_mode: PromptMode::Tty,
            helper_mode: HelperMode::NixosRootHelper,
        }
    }
}

impl Default for NetworkConfig {
    fn default() -> Self {
        Self {
            allow_loopback: true,
            deny_metadata: false,
            deny_private: false,
        }
    }
}

impl Default for ProxyConfig {
    fn default() -> Self {
        Self {
            adapters: vec![
                "npm".into(),
                "pypi".into(),
                "cargo".into(),
                "go".into(),
                "generic-http".into(),
            ],
            credential_source: CredentialSource::HostFilesEnv,
            credential_file: None,
            credential_command: None,
            credential_pass_prefix: None,
            credential_secret_service: None,
            cache_ttl_seconds: 86_400,
            allowed_hosts: Vec::new(),
            npm_registry: None,
            npm_ignore_scripts: false,
            pip_index_url: None,
            pip_no_input: false,
            pip_disable_version_check: false,
            cargo_git_fetch_with_cli: None,
            go_proxy: None,
            go_sumdb: None,
            go_vcs: None,
            go_auth: None,
        }
    }
}

impl Default for ReviewConfig {
    fn default() -> Self {
        Self {
            artifact_mode: ReviewArtifactMode::JournalAndDiff,
            conflict_policy: ConflictPolicy::DetectRefuseThenAskOverride,
            file_rules: Vec::new(),
        }
    }
}

impl ReviewConfig {
    pub fn validate(&self) -> Result<()> {
        for rule in &self.file_rules {
            if rule.pattern.is_empty() {
                anyhow::bail!("review file rule match pattern cannot be empty");
            }
        }
        Ok(())
    }
}

impl Default for EventsConfig {
    fn default() -> Self {
        Self {
            require_logging: true,
        }
    }
}

pub fn default_global_config_path(
    config_home: Option<PathBuf>,
    home: Option<PathBuf>,
) -> Option<PathBuf> {
    config_home
        .map(|config_home| config_home.join("condom/config.toml"))
        .or_else(|| home.map(|home| home.join(".config/condom/config.toml")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn global_config_path_prefers_xdg_config_home() {
        assert_eq!(
            default_global_config_path(
                Some(PathBuf::from("/xdg")),
                Some(PathBuf::from("/home/me"))
            ),
            Some(PathBuf::from("/xdg/condom/config.toml"))
        );
    }

    #[test]
    fn global_config_path_falls_back_to_home_config() {
        assert_eq!(
            default_global_config_path(None, Some(PathBuf::from("/home/me"))),
            Some(PathBuf::from("/home/me/.config/condom/config.toml"))
        );
    }

    #[test]
    fn default_config_uses_canonical_event_logging_key() {
        let temp = tempfile::tempdir().unwrap();
        let config_path = temp.path().join("config.toml");

        CondomConfig::write_default(&config_path).unwrap();
        let content = fs::read_to_string(config_path).unwrap();

        assert!(content.contains("[events]"));
        assert!(content.contains("requireLogging = true"));
        assert!(!content.contains("eventLogging"));
    }

    #[test]
    fn default_config_has_no_builtin_exec_deny_list() {
        let config = CondomConfig::default();

        assert!(config.exec.allow.is_empty());
        assert!(config.exec.deny.is_empty());
    }

    #[test]
    fn default_config_has_no_builtin_network_denies_or_proxy_allowlist() {
        let config = CondomConfig::default();

        assert!(!config.network.deny_metadata);
        assert!(!config.network.deny_private);
        assert!(config.proxy.allowed_hosts.is_empty());
        assert!(config.proxy.npm_registry.is_none());
        assert!(!config.proxy.npm_ignore_scripts);
        assert!(config.proxy.pip_index_url.is_none());
        assert!(!config.proxy.pip_no_input);
        assert!(!config.proxy.pip_disable_version_check);
        assert!(config.proxy.cargo_git_fetch_with_cli.is_none());
        assert!(config.proxy.go_proxy.is_none());
        assert!(config.proxy.go_sumdb.is_none());
        assert!(config.proxy.go_vcs.is_none());
        assert!(config.proxy.go_auth.is_none());
    }

    #[test]
    fn defaults_event_logging_is_deprecated_alias_for_events_require_logging() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[defaults]
eventLogging = false
"#,
        )
        .unwrap();

        let config = CondomConfig::load(temp.path(), None).unwrap();

        assert!(!config.events.require_logging);
    }

    #[test]
    fn events_require_logging_overrides_deprecated_defaults_alias() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[defaults]
eventLogging = false

[events]
requireLogging = true
"#,
        )
        .unwrap();

        let config = CondomConfig::load(temp.path(), None).unwrap();

        assert!(config.events.require_logging);
    }

    #[test]
    fn project_config_overrides_scalars_and_replaces_lists() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[network]
allowLoopback = false
denyMetadata = true
denyPrivate = true

[filesystem]
allowRead = ["/opt/sdk"]
denyWrite = ["~/.config/fish/**"]
redactRead = ["/run/secret/token"]

[exec]
allow = ["cargo test"]
deny = ["cargo publish"]

[proxy]
adapters = ["npm"]
credentialSource = "host-file"
credentialFile = "/run/condom/credentials.toml"
credentialCommand = ["pass", "show", "npm/registry"]
credentialPassPrefix = "condom"
credentialSecretService = "condom"
cacheTtlSeconds = 42
allowedHosts = ["example.test"]
npmRegistry = "https://private-registry.example.test/"
npmIgnoreScripts = true
pipIndexUrl = "https://packages.example.test/simple"
pipNoInput = true
pipDisableVersionCheck = true
cargoGitFetchWithCli = false
goProxy = "https://proxy.modules.example.test"
goSumdb = "sum.modules.example.test"
goVcs = "*:off"
goAuth = "off"
"#,
        )
        .unwrap();
        let config = CondomConfig::load(temp.path(), None).unwrap();
        assert!(!config.network.allow_loopback);
        assert!(config.network.deny_metadata);
        assert!(config.network.deny_private);
        assert_eq!(config.filesystem.allow_read, vec!["/opt/sdk"]);
        assert_eq!(config.filesystem.deny_write, vec!["~/.config/fish/**"]);
        assert_eq!(config.filesystem.redact_read, vec!["/run/secret/token"]);
        assert_eq!(config.exec.allow, vec!["cargo test"]);
        assert_eq!(config.exec.deny, vec!["cargo publish"]);
        assert_eq!(config.proxy.adapters, vec!["npm"]);
        assert_eq!(config.proxy.credential_source, CredentialSource::HostFile);
        assert_eq!(
            config.proxy.credential_file,
            Some("/run/condom/credentials.toml".into())
        );
        assert_eq!(
            config.proxy.credential_command,
            Some(vec!["pass".into(), "show".into(), "npm/registry".into()])
        );
        assert_eq!(config.proxy.credential_pass_prefix, Some("condom".into()));
        assert_eq!(
            config.proxy.credential_secret_service,
            Some("condom".into())
        );
        assert_eq!(config.proxy.cache_ttl_seconds, 42);
        assert_eq!(config.proxy.allowed_hosts, vec!["example.test"]);
        assert_eq!(
            config.proxy.npm_registry,
            Some("https://private-registry.example.test/".into())
        );
        assert!(config.proxy.npm_ignore_scripts);
        assert_eq!(
            config.proxy.pip_index_url,
            Some("https://packages.example.test/simple".into())
        );
        assert!(config.proxy.pip_no_input);
        assert!(config.proxy.pip_disable_version_check);
        assert_eq!(config.proxy.cargo_git_fetch_with_cli, Some(false));
        assert_eq!(
            config.proxy.go_proxy,
            Some("https://proxy.modules.example.test".into())
        );
        assert_eq!(
            config.proxy.go_sumdb,
            Some("sum.modules.example.test".into())
        );
        assert_eq!(config.proxy.go_vcs, Some("*:off".into()));
        assert_eq!(config.proxy.go_auth, Some("off".into()));
    }

    #[test]
    fn project_config_accepts_environment_allow_and_deny() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[environment]
allow = ["CLOUD_PROFILE", "SOURCE_TOKEN"]
deny = ["SSH_AUTH_SOCK"]
"#,
        )
        .unwrap();

        let config = CondomConfig::load(temp.path(), None).unwrap();

        assert_eq!(
            config.environment.allow,
            vec!["CLOUD_PROFILE", "SOURCE_TOKEN"]
        );
        assert_eq!(config.environment.deny, vec!["SSH_AUTH_SOCK"]);
    }

    #[test]
    fn project_config_accepts_review_file_rules() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[[review.fileRules]]
match = "**/.git/index"
visibility = "hidden"
defaultSelected = true
"#,
        )
        .unwrap();

        let config = CondomConfig::load(temp.path(), None).unwrap();

        assert_eq!(
            config.review.file_rules,
            vec![ReviewFileRule {
                pattern: "**/.git/index".into(),
                visibility: ReviewFileVisibility::Hidden,
                default_selected: Some(true),
            }]
        );
    }

    #[test]
    fn project_config_rejects_runtime_owned_environment_keys() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[environment]
allow = ["HOME"]
"#,
        )
        .unwrap();

        let error = CondomConfig::load(temp.path(), None).unwrap_err();

        assert!(format!("{error:#}").contains("environment variable `HOME` is owned"));
    }

    #[test]
    fn project_config_rejects_internal_condom_environment_keys() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[environment]
allow = ["CONDOM_CREDENTIAL_127_0_0_1"]
"#,
        )
        .unwrap();

        let error = CondomConfig::load(temp.path(), None).unwrap_err();

        assert!(format!("{error:#}")
            .contains("environment variable `CONDOM_CREDENTIAL_127_0_0_1` is owned"));
    }

    #[test]
    fn project_config_rejects_proxy_route_rules() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[proxy]
allowedRoutes = [{ host = "example.test", pathPrefix = "" }]
"#,
        )
        .unwrap();

        let error = CondomConfig::load(temp.path(), None).unwrap_err();

        assert!(format!("{error:#}").contains("unknown field `allowedRoutes`"));
    }

    #[test]
    fn project_config_accepts_helper_credential_source() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[proxy]
credentialSource = "helper"
"#,
        )
        .unwrap();
        let config = CondomConfig::load(temp.path(), None).unwrap();

        assert_eq!(config.proxy.credential_source, CredentialSource::Helper);
    }

    #[test]
    fn project_config_accepts_host_command_credential_source() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[proxy]
credentialSource = "host-command"
credentialCommand = ["pass", "show", "npm/registry"]
"#,
        )
        .unwrap();
        let config = CondomConfig::load(temp.path(), None).unwrap();

        assert_eq!(
            config.proxy.credential_source,
            CredentialSource::HostCommand
        );
        assert_eq!(
            config.proxy.credential_command,
            Some(vec!["pass".into(), "show".into(), "npm/registry".into()])
        );
    }

    #[test]
    fn project_config_accepts_pass_credential_source() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[proxy]
credentialSource = "pass"
credentialPassPrefix = "registries"
"#,
        )
        .unwrap();
        let config = CondomConfig::load(temp.path(), None).unwrap();

        assert_eq!(config.proxy.credential_source, CredentialSource::Pass);
        assert_eq!(
            config.proxy.credential_pass_prefix,
            Some("registries".into())
        );
    }

    #[test]
    fn project_config_accepts_secret_tool_credential_source() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(
            &project_config,
            r#"
[proxy]
credentialSource = "secret-tool"
credentialSecretService = "registries"
"#,
        )
        .unwrap();
        let config = CondomConfig::load(temp.path(), None).unwrap();

        assert_eq!(config.proxy.credential_source, CredentialSource::SecretTool);
        assert_eq!(
            config.proxy.credential_secret_service,
            Some("registries".into())
        );
    }

    #[test]
    fn unknown_keys_fail() {
        let temp = tempfile::tempdir().unwrap();
        let project_config = temp.path().join(".condom/config.toml");
        fs::create_dir_all(project_config.parent().unwrap()).unwrap();
        fs::write(&project_config, "surprise = true\n").unwrap();
        let error = CondomConfig::load(temp.path(), None).unwrap_err();
        assert!(error.to_string().contains("failed to parse"));
    }
}
