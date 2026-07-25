use std::collections::{BTreeMap, BTreeSet};
use std::ffi::OsStr;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Component, Path, PathBuf};

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
    "/etc/host.conf",
    "/etc/hosts",
    "/etc/localtime",
    "/etc/nsswitch.conf",
    "/etc/os-release",
    "/etc/pki/tls/certs",
    "/etc/pki/tls/openssl.cnf",
    "/etc/protocols",
    "/etc/resolv.conf",
    "/etc/services",
    "/etc/ssl/certs",
    "/etc/ssl/openssl.cnf",
    "/usr/lib/os-release",
    "/usr/share/locale",
    "/usr/share/zoneinfo",
    "/sys/devices/system/cpu/online",
    "/sys/devices/system/cpu/possible",
    "/sys/devices/system/cpu/present",
    "/sys/devices/system/node/online",
    "/sys/devices/system/node/possible",
    "/sys/kernel/mm/transparent_hugepage/enabled",
    "/sys/kernel/mm/transparent_hugepage/hpage_pmd_size",
];

const CGROUP_V2_ROOT: &str = "/sys/fs/cgroup";
const CGROUP_RUNTIME_READ_FILES: &[&str] = &[
    "cgroup.controllers",
    "cgroup.type",
    "cpu.max",
    "cpuset.cpus.effective",
    "cpuset.mems.effective",
    "memory.high",
    "memory.max",
    "memory.swap.max",
    "pids.max",
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
    plan_runtime_read_paths_with_cgroup_root(environment, cgroup, Path::new(CGROUP_V2_ROOT))
}

fn plan_runtime_read_paths_with_cgroup_root(
    environment: &BTreeMap<String, String>,
    cgroup: Option<&str>,
    cgroup_root: &Path,
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
    if let Some(contents) = cgroup {
        paths.extend(current_cgroup_runtime_read_paths(contents, cgroup_root));
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

fn current_cgroup_runtime_read_paths(contents: &str, cgroup_root: &Path) -> BTreeSet<String> {
    let mut paths = BTreeSet::new();
    let Some(relative) = contents.lines().find_map(|line| line.strip_prefix("0::")) else {
        return paths;
    };
    let relative = Path::new(relative);
    if !relative.is_absolute()
        || relative
            .components()
            .any(|component| !matches!(component, Component::RootDir | Component::Normal(_)))
    {
        return paths;
    }
    let Ok(relative) = relative.strip_prefix("/") else {
        return paths;
    };
    let current = cgroup_root.join(relative);
    for directory in current
        .ancestors()
        .take_while(|path| path.starts_with(cgroup_root))
    {
        for file in CGROUP_RUNTIME_READ_FILES {
            let candidate = directory.join(file);
            if candidate
                .metadata()
                .is_ok_and(|metadata| metadata.is_file())
            {
                paths.insert(path_string(&candidate));
            }
        }
    }
    paths
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
    fn runtime_read_paths_include_fixed_and_configured_paths() {
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

        let paths = plan_runtime_read_paths_with_cgroup_root(&environment, None, temp.path());

        for expected in [
            "/etc/host.conf",
            "/etc/hosts",
            "/etc/resolv.conf",
            "/etc/nsswitch.conf",
            "/etc/os-release",
            "/etc/services",
            "/etc/localtime",
            "/usr/share/locale",
            "/usr/share/zoneinfo",
            "/sys/devices/system/cpu/online",
            "/sys/devices/system/cpu/possible",
            "/sys/devices/system/node/online",
            "/sys/kernel/mm/transparent_hugepage/enabled",
            "/sys/kernel/mm/transparent_hugepage/hpage_pmd_size",
            certificate.to_str().unwrap(),
            certificate_directory.to_str().unwrap(),
        ] {
            assert!(
                paths.iter().any(|path| path == expected),
                "missing {expected}"
            );
        }
        assert!(!paths.iter().any(|path| path.ends_with("missing.pem")));
        assert!(!paths.iter().any(|path| path == "relative-ca.pem"));
        assert!(paths.windows(2).all(|pair| pair[0] < pair[1]));
    }

    #[test]
    fn runtime_read_paths_include_only_limit_files_on_the_current_cgroup_ancestry() {
        let temp = tempfile::tempdir().unwrap();
        let root = temp.path();
        let parent = root.join("system.slice");
        let current = parent.join("condom-helper.service");
        let sibling = parent.join("other.service");
        fs::create_dir_all(&current).unwrap();
        fs::create_dir(&sibling).unwrap();
        fs::write(root.join("cpu.max"), "max 100000").unwrap();
        fs::write(parent.join("memory.high"), "max").unwrap();
        fs::write(current.join("memory.max"), "1073741824").unwrap();
        fs::write(current.join("not-preallowed"), "secret").unwrap();
        fs::write(sibling.join("cpu.max"), "10000 100000").unwrap();

        let paths = plan_runtime_read_paths_with_cgroup_root(
            &BTreeMap::new(),
            Some("0::/system.slice/condom-helper.service\n"),
            root,
        );

        for expected in [
            root.join("cpu.max"),
            parent.join("memory.high"),
            current.join("memory.max"),
        ] {
            assert!(
                paths
                    .iter()
                    .any(|path| path == &expected.display().to_string()),
                "missing {}",
                expected.display()
            );
        }
        for excluded in [
            current.display().to_string(),
            current.join("not-preallowed").display().to_string(),
            sibling.join("cpu.max").display().to_string(),
        ] {
            assert!(!paths.iter().any(|path| path == &excluded));
        }
    }

    #[test]
    fn malformed_or_legacy_cgroup_memberships_add_no_runtime_paths() {
        let temp = tempfile::tempdir().unwrap();

        for contents in [
            "1:name=systemd:/system.slice/example.service\n",
            "0::relative/path\n",
            "0::/system.slice/../other.service\n",
        ] {
            assert!(
                current_cgroup_runtime_read_paths(contents, temp.path()).is_empty(),
                "unexpected paths for {contents:?}"
            );
        }
    }
}
