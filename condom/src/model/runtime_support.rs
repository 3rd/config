use std::collections::{BTreeMap, BTreeSet};
use std::ffi::OsStr;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use crate::model::policy_pattern::{expand_home, policy_pattern_matches};

pub(crate) const SAFE_OPERATIONAL_ENV_KEYS: &[&str] = &[
    "CURL_CA_BUNDLE",
    "GIT_SSL_CAINFO",
    "LANG",
    "LANGUAGE",
    "LC_ADDRESS",
    "LC_ALL",
    "LC_COLLATE",
    "LC_CTYPE",
    "LC_IDENTIFICATION",
    "LC_MEASUREMENT",
    "LC_MESSAGES",
    "LC_MONETARY",
    "LC_NAME",
    "LC_NUMERIC",
    "LC_PAPER",
    "LC_TELEPHONE",
    "LC_TIME",
    "LOCALE_ARCHIVE",
    "NIX_SSL_CERT_FILE",
    "NODE_EXTRA_CA_CERTS",
    "REQUESTS_CA_BUNDLE",
    "SSL_CERT_DIR",
    "SSL_CERT_FILE",
    "TZ",
    "TZDIR",
];

const FIXED_RUNTIME_READ_PATHS: &[&str] = &[
    "/etc/gai.conf",
    "/etc/hosts",
    "/etc/localtime",
    "/etc/nsswitch.conf",
    "/etc/pki/tls/certs",
    "/etc/resolv.conf",
    "/etc/ssl/certs",
    "/sys/devices/system/cpu/online",
];

const SINGLE_PATH_ENV_KEYS: &[&str] = &[
    "CURL_CA_BUNDLE",
    "GIT_SSL_CAINFO",
    "LOCALE_ARCHIVE",
    "NIX_SSL_CERT_FILE",
    "NODE_EXTRA_CA_CERTS",
    "REQUESTS_CA_BUNDLE",
    "SSL_CERT_FILE",
    "TZDIR",
];

pub(crate) fn is_safe_operational_environment_key(key: &str) -> bool {
    SAFE_OPERATIONAL_ENV_KEYS.contains(&key)
}

pub(crate) fn plan_runtime_read_paths(
    environment: &BTreeMap<String, String>,
    cgroup: Option<&str>,
) -> Vec<String> {
    let mut paths = FIXED_RUNTIME_READ_PATHS
        .iter()
        .map(|path| (*path).to_string())
        .collect::<BTreeSet<_>>();
    for key in SINGLE_PATH_ENV_KEYS {
        if let Some(path) = environment.get(*key) {
            insert_existing_absolute_path(&mut paths, Path::new(path));
        }
    }
    if let Some(value) = environment.get("SSL_CERT_DIR") {
        for path in std::env::split_paths(OsStr::new(value)) {
            insert_existing_absolute_path(&mut paths, &path);
        }
    }
    if let Some(path) = cgroup.and_then(current_cgroup_path) {
        paths.insert(path);
    }
    paths.into_iter().collect()
}

fn insert_existing_absolute_path(paths: &mut BTreeSet<String>, path: &Path) {
    if !path.is_absolute() || !path.exists() {
        return;
    }
    paths.insert(path_string(path));
    if let Ok(resolved) = fs::canonicalize(path) {
        paths.insert(path_string(&resolved));
    }
}

fn current_cgroup_path(contents: &str) -> Option<String> {
    let relative = contents.lines().find_map(|line| line.strip_prefix("0::"))?;
    if relative == "/" || !relative.starts_with('/') {
        return None;
    }
    Some(format!("/sys/fs/cgroup{relative}"))
}

pub(crate) fn resolve_executable_target(
    command: &[String],
    path: Option<&OsStr>,
) -> Option<String> {
    let executable = resolve_executable(command, path)?;
    let resolved = fs::canonicalize(&executable).unwrap_or(executable);
    Some(path_string(&resolved))
}

pub(crate) fn path_is_blocked_by_patterns<'a>(
    path: &str,
    patterns: impl IntoIterator<Item = &'a String>,
) -> bool {
    patterns.into_iter().any(|pattern| {
        if policy_pattern_matches(pattern, path) {
            return true;
        }
        let expanded = expand_home(pattern);
        let fixed_prefix = expanded
            .split_once('*')
            .map_or(expanded.as_str(), |(prefix, _)| prefix)
            .trim_end_matches('/');
        !fixed_prefix.is_empty() && Path::new(fixed_prefix).starts_with(path)
    })
}

fn resolve_executable(command: &[String], path: Option<&OsStr>) -> Option<PathBuf> {
    let program = Path::new(command.first()?);
    if program.components().count() > 1 {
        return executable_file(program).then(|| program.to_path_buf());
    }
    std::env::split_paths(path?)
        .filter(|directory| directory.is_absolute())
        .map(|directory| directory.join(program))
        .find(|candidate| executable_file(candidate))
}

fn executable_file(path: &Path) -> bool {
    path.metadata()
        .map(|metadata| metadata.is_file() && metadata.permissions().mode() & 0o111 != 0)
        .unwrap_or(false)
}

fn path_string(path: &Path) -> String {
    path.display().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn selected_path_executable_resolves_to_its_canonical_target() {
        let temp = tempfile::tempdir().unwrap();
        let bin = temp.path().join("bin");
        let tool = temp.path().join("tools/example");
        fs::create_dir_all(tool.join("dist")).unwrap();
        fs::create_dir_all(&bin).unwrap();
        let entrypoint = tool.join("dist/example");
        fs::write(&entrypoint, "#!/bin/sh\n").unwrap();
        fs::set_permissions(&entrypoint, fs::Permissions::from_mode(0o755)).unwrap();
        std::os::unix::fs::symlink(&entrypoint, bin.join("example")).unwrap();
        let path = std::env::join_paths([bin]).unwrap();

        assert_eq!(
            resolve_executable_target(&["example".into(), "--help".into()], Some(path.as_os_str())),
            Some(entrypoint.display().to_string())
        );
    }

    #[test]
    fn runtime_read_paths_are_fixed_existing_and_current_cgroup_scoped() {
        let temp = tempfile::tempdir().unwrap();
        let certificate = temp.path().join("combined-ca.pem");
        let certificate_directory = temp.path().join("certs");
        fs::write(&certificate, "certificate").unwrap();
        fs::create_dir(&certificate_directory).unwrap();
        let environment = BTreeMap::from([
            ("SSL_CERT_FILE".into(), certificate.display().to_string()),
            (
                "SSL_CERT_DIR".into(),
                certificate_directory.display().to_string(),
            ),
            ("NODE_EXTRA_CA_CERTS".into(), "relative-ca.pem".into()),
            (
                "NIX_SSL_CERT_FILE".into(),
                temp.path().join("missing.pem").display().to_string(),
            ),
        ]);

        let paths = plan_runtime_read_paths(
            &environment,
            Some("0::/system.slice/condom-helper.service\n"),
        );

        for expected in [
            "/etc/hosts",
            "/etc/resolv.conf",
            "/etc/nsswitch.conf",
            "/etc/localtime",
            "/sys/devices/system/cpu/online",
            "/sys/fs/cgroup/system.slice/condom-helper.service",
            certificate.to_str().unwrap(),
            certificate_directory.to_str().unwrap(),
        ] {
            assert!(
                paths.iter().any(|path| path == expected),
                "missing {expected}"
            );
        }
        assert!(!paths.iter().any(|path| path == "/sys/fs/cgroup"));
        assert!(!paths.iter().any(|path| path.ends_with("missing.pem")));
        assert!(!paths.iter().any(|path| path == "relative-ca.pem"));
    }
}
