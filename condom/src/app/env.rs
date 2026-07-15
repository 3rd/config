use std::collections::BTreeMap;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use crate::model::config::{EnvironmentConfig, ExecutionMode};
use crate::model::project::{ProjectContext, PROJECT_ROOT_ENV};
use crate::model::runtime_support::{
    is_safe_operational_environment_key, SAFE_OPERATIONAL_ENV_KEYS,
};
use crate::model::state::{StatePaths, STATE_HOME_ENV};

pub const ORIGINAL_PATH_ENV: &str = "CONDOM_ORIGINAL_PATH";
pub const WRAPPER_REEXEC_ENV: &str = "CONDOM_WRAPPER_REEXEC";
pub const USER_ENV_KEYS: &[&str] = &[
    "DBUS_SESSION_BUS_ADDRESS",
    "DISPLAY",
    "HOME",
    "USER",
    "LOGNAME",
    "SHELL",
    "WAYLAND_DISPLAY",
    "XAUTHORITY",
    "XDG_CACHE_HOME",
    "XDG_CONFIG_HOME",
    "XDG_DATA_HOME",
    "XDG_RUNTIME_DIR",
    "XDG_STATE_HOME",
    crate::app::debug::DEBUG_LOG_ENV,
    STATE_HOME_ENV,
];

pub fn current_environment() -> BTreeMap<String, String> {
    std::env::vars().collect()
}

pub fn current_user_environment() -> BTreeMap<String, String> {
    current_environment()
        .into_iter()
        .filter(|(key, _)| is_caller_environment_key(key))
        .collect()
}

pub fn is_caller_environment_key(key: &str) -> bool {
    USER_ENV_KEYS.contains(&key) || is_safe_operational_environment_key(key)
}

pub fn caller_environment_keys() -> impl Iterator<Item = &'static str> {
    USER_ENV_KEYS
        .iter()
        .chain(SAFE_OPERATIONAL_ENV_KEYS)
        .copied()
}

pub fn sanitized_environment(
    source: &BTreeMap<String, String>,
    mode: ExecutionMode,
    project: &ProjectContext,
    state: &StatePaths,
    environment: &EnvironmentConfig,
) -> BTreeMap<String, String> {
    let mut env = BTreeMap::new();

    for (key, value) in source {
        if keep_passthrough_key(key, environment) {
            env.insert(key.clone(), value.clone());
        }
    }
    let path = source_path(source);
    env.insert("PATH".into(), runtime_path(path));
    if environment.allow.iter().any(|key| key == "SHELL")
        && !environment.deny.iter().any(|key| key == "SHELL")
    {
        if let Some(shell) = resolved_shell(source, path) {
            env.insert("SHELL".into(), shell);
        }
    }

    let home = source
        .get("HOME")
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| state.runtime_dir.join("home"));
    let tmp = state.runtime_dir.join("tmp");
    env.insert("HOME".into(), home.display().to_string());
    env.insert("TMPDIR".into(), tmp.display().to_string());
    env.insert("TMP".into(), tmp.display().to_string());
    env.insert("TEMP".into(), tmp.display().to_string());
    env.insert("CONDOM_MODE".into(), mode.as_str().to_string());
    env.insert("CONDOM_PROJECT_ID".into(), project.id.clone());
    env.insert(PROJECT_ROOT_ENV.into(), project.root.display().to_string());

    env
}

// Keys the sandbox pins for its own security; a client-supplied extra_env must
// never override these (path/temp resolution and transparent-proxy routing).
pub fn is_reserved_sandbox_env_key(key: &str) -> bool {
    matches!(key, "PATH" | "HOME" | "TMPDIR" | "TMP" | "TEMP") || key.starts_with("CONDOM_TPROXY_")
}

fn keep_passthrough_key(key: &str, environment: &EnvironmentConfig) -> bool {
    if environment.deny.iter().any(|denied| denied == key) {
        return false;
    }
    is_safe_operational_environment_key(key)
        || environment.allow.iter().any(|allowed| allowed == key)
}

fn source_path(source: &BTreeMap<String, String>) -> Option<&String> {
    source.get(ORIGINAL_PATH_ENV).or_else(|| source.get("PATH"))
}

fn resolved_shell(source: &BTreeMap<String, String>, path: Option<&String>) -> Option<String> {
    let path = path.map(String::as_str);
    source
        .get("SHELL")
        .and_then(|shell| resolve_shell(shell, path))
        .or_else(|| resolve_shell("bash", path))
        .or_else(|| resolve_shell("sh", path))
        .or_else(default_shell)
}

fn resolve_shell(shell: &str, path: Option<&str>) -> Option<String> {
    let shell_path = Path::new(shell);
    if shell_path.is_absolute() && is_executable_file(shell_path) {
        return Some(shell.to_string());
    }
    if shell_path.components().count() > 1 {
        return None;
    }
    path.and_then(|path| {
        path.split(':')
            .filter(|entry| !entry.is_empty())
            .map(|entry| PathBuf::from(entry).join(shell))
            .find(|candidate| is_executable_file(candidate))
            .map(|candidate| candidate.display().to_string())
    })
}

fn default_shell() -> Option<String> {
    [
        "/run/current-system/sw/bin/bash",
        "/bin/bash",
        "/usr/bin/bash",
        "/run/current-system/sw/bin/sh",
        "/bin/sh",
    ]
    .iter()
    .find(|path| is_executable_file(Path::new(path)))
    .map(|path| (*path).to_string())
}

fn is_executable_file(path: &Path) -> bool {
    path.is_file()
        && path
            .metadata()
            .map(|metadata| metadata.permissions().mode() & 0o111 != 0)
            .unwrap_or(false)
}

fn runtime_path(source_path: Option<&String>) -> String {
    let mut entries = Vec::new();
    if let Some(path) = source_path {
        entries.extend(
            path.split(':')
                .filter(|entry| !entry.is_empty())
                .map(str::to_string),
        );
    }
    for path in ["/run/current-system/sw/bin", "/usr/bin", "/bin"] {
        if Path::new(path).exists() && !entries.iter().any(|entry| entry == path) {
            entries.push(path.into());
        }
    }
    entries.join(":")
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::PathBuf;

    use super::*;

    fn project() -> ProjectContext {
        ProjectContext {
            root: PathBuf::from("/tmp/app"),
            id: "project-id".into(),
            origin: None,
        }
    }

    fn state() -> StatePaths {
        StatePaths::from_base(&project(), &PathBuf::from("/tmp/state"))
    }

    fn environment() -> EnvironmentConfig {
        EnvironmentConfig::default()
    }

    #[test]
    fn default_environment_passes_only_runtime_owned_values() {
        let mut source = BTreeMap::new();
        source.insert("PATH".into(), "/run/current-system/sw/bin".into());
        source.insert("HOME".into(), "/home/me".into());
        source.insert("XDG_CONFIG_HOME".into(), "/home/me/.config".into());
        source.insert("XDG_STATE_HOME".into(), "/home/me/.local/state".into());
        source.insert("SOURCE_TOKEN".into(), "secret".into());
        source.insert("MODEL_API_KEY".into(), "secret".into());
        source.insert("CONDOM_CREDENTIAL_127_0_0_1".into(), "secret".into());
        source.insert("CONDOM_INTERNAL_DISABLE_HELPER_REENTRY".into(), "1".into());
        source.insert(
            "CONDOM_INTERNAL_AUTH_HELPER_SOCKET".into(),
            "/run/condom/helper.sock".into(),
        );
        source.insert("SSH_AUTH_SOCK".into(), "/tmp/ssh-agent".into());
        source.insert("LC_ALL".into(), "C.UTF-8".into());
        source.insert("SSL_CERT_DIR".into(), "/etc/ssl/certs".into());
        source.insert("SSL_CERT_FILE".into(), "/home/me/combined-ca.pem".into());
        source.insert("NODE_OPTIONS".into(), "--require=/home/me/inject.js".into());
        source.insert("COLORTERM".into(), "truecolor".into());
        source.insert("TERM_PROGRAM".into(), "kitty".into());
        source.insert("COLUMNS".into(), "120".into());
        source.insert("LINES".into(), "40".into());

        let env = sanitized_environment(
            &source,
            ExecutionMode::Run,
            &project(),
            &state(),
            &EnvironmentConfig {
                allow: vec!["SHELL".into()],
                deny: Vec::new(),
            },
        );

        let path = env.get("PATH").unwrap();
        assert!(path
            .split(':')
            .any(|entry| entry == "/run/current-system/sw/bin"));
        assert_eq!(env.get("LC_ALL").map(String::as_str), Some("C.UTF-8"));
        assert_eq!(
            env.get("SSL_CERT_DIR").map(String::as_str),
            Some("/etc/ssl/certs")
        );
        assert_eq!(
            env.get("SSL_CERT_FILE").map(String::as_str),
            Some("/home/me/combined-ca.pem")
        );
        assert_eq!(env.get("HOME").map(String::as_str), Some("/home/me"));
        assert!(!env.contains_key("XDG_CONFIG_HOME"));
        assert!(!env.contains_key("XDG_STATE_HOME"));
        assert_eq!(
            env.get("TMPDIR").map(String::as_str),
            Some("/tmp/app/.condom/tmp")
        );
        assert_eq!(
            env.get("TMP").map(String::as_str),
            Some("/tmp/app/.condom/tmp")
        );
        assert_eq!(
            env.get("TEMP").map(String::as_str),
            Some("/tmp/app/.condom/tmp")
        );
        assert!(!env.contains_key("SOURCE_TOKEN"));
        assert!(!env.contains_key("MODEL_API_KEY"));
        assert!(!env.contains_key("CONDOM_CREDENTIAL_127_0_0_1"));
        assert!(!env.contains_key("CONDOM_INTERNAL_DISABLE_HELPER_REENTRY"));
        assert!(!env.contains_key("CONDOM_INTERNAL_AUTH_HELPER_SOCKET"));
        assert!(!env.contains_key("COLORTERM"));
        assert!(!env.contains_key("TERM_PROGRAM"));
        assert!(!env.contains_key("COLUMNS"));
        assert!(!env.contains_key("LINES"));
        assert!(!env.contains_key("SSH_AUTH_SOCK"));
        assert!(!env.contains_key("NODE_OPTIONS"));
    }

    #[test]
    fn configured_environment_allow_passes_keys_and_deny_wins() {
        let mut source = BTreeMap::new();
        source.insert("CLOUD_PROFILE".into(), "work".into());
        source.insert("SOURCE_TOKEN".into(), "needed-for-install".into());
        source.insert("SHELL".into(), "/bin/sh".into());
        source.insert("SSL_CERT_FILE".into(), "/home/me/combined-ca.pem".into());
        source.insert("XDG_CONFIG_HOME".into(), "/home/me/.config".into());
        let environment = EnvironmentConfig {
            allow: vec![
                "CLOUD_PROFILE".into(),
                "SOURCE_TOKEN".into(),
                "SHELL".into(),
                "XDG_CONFIG_HOME".into(),
            ],
            deny: vec![
                "SOURCE_TOKEN".into(),
                "SHELL".into(),
                "SSL_CERT_FILE".into(),
            ],
        };

        let env = sanitized_environment(
            &source,
            ExecutionMode::Run,
            &project(),
            &state(),
            &environment,
        );

        assert_eq!(env.get("CLOUD_PROFILE").map(String::as_str), Some("work"));
        assert_eq!(
            env.get("XDG_CONFIG_HOME").map(String::as_str),
            Some("/home/me/.config")
        );
        assert!(!env.contains_key("SOURCE_TOKEN"));
        assert!(!env.contains_key("SHELL"));
        assert!(!env.contains_key("SSL_CERT_FILE"));
    }

    #[test]
    fn review_preserves_user_home_and_configured_xdg_locations() {
        let runtime_dir = PathBuf::from("/tmp/review-session/.condom");
        let state = state().with_runtime_dir(runtime_dir.clone());
        let mut source = BTreeMap::new();
        source.insert("HOME".into(), "/home/me".into());
        source.insert("XDG_CACHE_HOME".into(), "/home/me/.cache".into());
        source.insert("XDG_CONFIG_HOME".into(), "/home/me/.config".into());
        source.insert("XDG_DATA_HOME".into(), "/home/me/.local/share".into());
        source.insert("XDG_STATE_HOME".into(), "/home/me/.local/state".into());

        let env = sanitized_environment(
            &source,
            ExecutionMode::Review,
            &project(),
            &state,
            &EnvironmentConfig {
                allow: vec![
                    "XDG_CACHE_HOME".into(),
                    "XDG_CONFIG_HOME".into(),
                    "XDG_DATA_HOME".into(),
                    "XDG_STATE_HOME".into(),
                ],
                deny: Vec::new(),
            },
        );
        let tmp = runtime_dir.join("tmp").display().to_string();

        assert_eq!(env.get("HOME").map(String::as_str), Some("/home/me"));
        assert_eq!(
            env.get("XDG_CACHE_HOME").map(String::as_str),
            Some("/home/me/.cache")
        );
        assert_eq!(
            env.get("XDG_CONFIG_HOME").map(String::as_str),
            Some("/home/me/.config")
        );
        assert_eq!(
            env.get("XDG_DATA_HOME").map(String::as_str),
            Some("/home/me/.local/share")
        );
        assert_eq!(
            env.get("XDG_STATE_HOME").map(String::as_str),
            Some("/home/me/.local/state")
        );
        assert_eq!(env.get("TMPDIR").map(String::as_str), Some(tmp.as_str()));
    }

    #[test]
    fn reserved_sandbox_keys_cover_path_temp_and_tproxy_only() {
        for key in [
            "PATH",
            "HOME",
            "TMPDIR",
            "TMP",
            "TEMP",
            "CONDOM_TPROXY_ROUTING",
        ] {
            assert!(is_reserved_sandbox_env_key(key), "{key} should be reserved");
        }
        for key in [
            "SHELL",
            "CONDOM_PROMPT_SOCKET",
            "NPM_CONFIG_PROXY",
            "CONDOM_MODE",
        ] {
            assert!(
                !is_reserved_sandbox_env_key(key),
                "{key} should be forwardable"
            );
        }
    }

    #[test]
    fn sets_condom_mode_for_child_processes() {
        let env = sanitized_environment(
            &BTreeMap::new(),
            ExecutionMode::Review,
            &project(),
            &state(),
            &environment(),
        );

        assert_eq!(env.get("CONDOM_MODE").map(String::as_str), Some("review"));
    }

    #[test]
    fn resolves_named_shell_against_preserved_path() {
        let temp = tempfile::tempdir().unwrap();
        let bin_dir = temp.path().join("bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let shell = bin_dir.join("bash");
        fs::write(&shell, "").unwrap();
        let mut permissions = fs::metadata(&shell).unwrap().permissions();
        permissions.set_mode(0o755);
        fs::set_permissions(&shell, permissions).unwrap();
        let mut source = BTreeMap::new();
        source.insert("PATH".into(), bin_dir.display().to_string());
        source.insert("SHELL".into(), "bash".into());

        let env = sanitized_environment(
            &source,
            ExecutionMode::Run,
            &project(),
            &state(),
            &EnvironmentConfig {
                allow: vec!["SHELL".into()],
                deny: Vec::new(),
            },
        );
        let expected = shell.display().to_string();

        assert_eq!(
            env.get("SHELL").map(String::as_str),
            Some(expected.as_str())
        );
    }

    #[test]
    fn preserves_user_shell_even_when_posix_shell_exists() {
        let temp = tempfile::tempdir().unwrap();
        let bin_dir = temp.path().join("bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let bash = bin_dir.join("bash");
        let fish = bin_dir.join("fish");
        fs::write(&bash, "").unwrap();
        fs::write(&fish, "").unwrap();
        for shell in [&bash, &fish] {
            let mut permissions = fs::metadata(shell).unwrap().permissions();
            permissions.set_mode(0o755);
            fs::set_permissions(shell, permissions).unwrap();
        }
        let mut source = BTreeMap::new();
        source.insert("PATH".into(), bin_dir.display().to_string());
        source.insert("SHELL".into(), fish.display().to_string());

        let env = sanitized_environment(
            &source,
            ExecutionMode::Run,
            &project(),
            &state(),
            &EnvironmentConfig {
                allow: vec!["SHELL".into()],
                deny: Vec::new(),
            },
        );
        let expected = fish.display().to_string();

        assert_eq!(
            env.get("SHELL").map(String::as_str),
            Some(expected.as_str())
        );
    }

    #[test]
    fn ignores_non_executable_shell_candidates() {
        let temp = tempfile::tempdir().unwrap();
        let bin_dir = temp.path().join("bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let fake_bash = bin_dir.join("bash");
        let shell_dir = bin_dir.join("sh");
        fs::write(&fake_bash, "").unwrap();
        fs::create_dir(&shell_dir).unwrap();
        let mut source = BTreeMap::new();
        source.insert("PATH".into(), bin_dir.display().to_string());

        let env = sanitized_environment(
            &source,
            ExecutionMode::Run,
            &project(),
            &state(),
            &environment(),
        );

        assert_ne!(
            env.get("SHELL").map(String::as_str),
            Some(fake_bash.display().to_string().as_str())
        );
        assert_ne!(
            env.get("SHELL").map(String::as_str),
            Some(shell_dir.display().to_string().as_str())
        );
    }

    #[test]
    fn preserved_original_path_wins_after_wrapper_reexec() {
        let mut source = BTreeMap::new();
        source.insert(
            "PATH".into(),
            "/run/wrappers/bin:/run/current-system/sw/bin".into(),
        );
        source.insert(
            ORIGINAL_PATH_ENV.into(),
            "/home/me/.local/bin:/run/current-system/sw/bin".into(),
        );

        let env = sanitized_environment(
            &source,
            ExecutionMode::Run,
            &project(),
            &state(),
            &environment(),
        );
        let path = env.get("PATH").unwrap();

        assert!(path.split(':').any(|entry| entry == "/home/me/.local/bin"));
        assert!(!env.contains_key(ORIGINAL_PATH_ENV));
    }

    #[test]
    fn runtime_path_keeps_source_and_adds_system_shell_dirs() {
        let temp = tempfile::tempdir().unwrap();
        let source_bin = temp.path().join("bin");
        fs::create_dir_all(&source_bin).unwrap();
        let mut source = BTreeMap::new();
        source.insert("PATH".into(), source_bin.display().to_string());

        let env = sanitized_environment(
            &source,
            ExecutionMode::Run,
            &project(),
            &state(),
            &environment(),
        );
        let path = env.get("PATH").unwrap();
        let source_bin = source_bin.display().to_string();

        assert!(path.split(':').any(|entry| entry == source_bin));
        assert!(path
            .split(':')
            .any(|entry| entry == "/run/current-system/sw/bin"));
    }
}
