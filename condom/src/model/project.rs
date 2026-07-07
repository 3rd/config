use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use sha2::{Digest, Sha256};

pub const PROJECT_ROOT_ENV: &str = "CONDOM_PROJECT_ROOT";

const PACKAGE_MARKERS: &[&str] = &[
    "Cargo.toml",
    "package.json",
    "pyproject.toml",
    "go.mod",
    "flake.nix",
];

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ProjectContext {
    pub root: PathBuf,
    pub id: String,
    pub origin: Option<String>,
}

impl ProjectContext {
    pub fn discover(explicit_root: Option<PathBuf>) -> Result<Self> {
        match explicit_root {
            Some(root) => Self::from_root(root),
            None => {
                if let Some(root) =
                    std::env::var_os(PROJECT_ROOT_ENV).filter(|value| !value.is_empty())
                {
                    return Self::from_root(PathBuf::from(root));
                }
                let current =
                    std::env::current_dir().context("failed to read current directory")?;
                Self::from_root(discover_root(&current))
            }
        }
    }

    pub fn from_root(root: PathBuf) -> Result<Self> {
        let root = canonical_or_original(&root);
        let origin = read_git_origin(&root);
        let id = project_id(&root, origin.as_deref());
        Ok(Self { root, id, origin })
    }
}

fn discover_root(start: &Path) -> PathBuf {
    let mut current = canonical_or_original(start);
    let mut marker_match = None;
    let mut git_match = None;
    loop {
        if current.join(".condom/config.toml").is_file() {
            return current;
        }
        if marker_match.is_none()
            && PACKAGE_MARKERS
                .iter()
                .any(|marker| current.join(marker).is_file())
        {
            marker_match = Some(current.clone());
        }
        if git_match.is_none() && current.join(".git").exists() {
            git_match = Some(current.clone());
        }
        if !current.pop() {
            break;
        }
    }
    marker_match
        .or(git_match)
        .unwrap_or_else(|| canonical_or_original(start))
}

fn canonical_or_original(path: &Path) -> PathBuf {
    fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf())
}

fn read_git_origin(root: &Path) -> Option<String> {
    let content = fs::read_to_string(root.join(".git/config")).ok()?;
    let mut in_origin = false;
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with('[') {
            in_origin = trimmed == r#"[remote "origin"]"#;
            continue;
        }
        if in_origin {
            if let Some((key, value)) = trimmed.split_once('=') {
                if key.trim() == "url" {
                    return Some(value.trim().to_string());
                }
            }
        }
    }
    None
}

fn project_id(root: &Path, origin: Option<&str>) -> String {
    let mut hasher = Sha256::new();
    hasher.update(root.to_string_lossy().as_bytes());
    hasher.update(b"\0");
    if let Some(origin) = origin {
        hasher.update(origin.as_bytes());
    }
    let digest = hasher.finalize();
    digest[..12]
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    fn restore_env(key: &str, value: Option<std::ffi::OsString>) {
        match value {
            Some(value) => std::env::set_var(key, value),
            None => std::env::remove_var(key),
        }
    }

    #[test]
    fn prefers_nested_package_marker_over_outer_git() {
        let temp = tempfile::tempdir().unwrap();
        fs::create_dir_all(temp.path().join(".git")).unwrap();
        let nested = temp.path().join("nested");
        fs::create_dir_all(&nested).unwrap();
        fs::write(
            nested.join("Cargo.toml"),
            "[package]\nname='x'\nversion='0.1.0'\n",
        )
        .unwrap();

        let project = ProjectContext::from_root(discover_root(&nested)).unwrap();

        assert_eq!(project.root, fs::canonicalize(&nested).unwrap());
    }

    #[test]
    fn explicit_root_is_exact() {
        let temp = tempfile::tempdir().unwrap();
        fs::create_dir_all(temp.path().join(".condom")).unwrap();
        fs::write(temp.path().join(".condom/config.toml"), "").unwrap();
        let nested = temp.path().join("nested");
        fs::create_dir_all(&nested).unwrap();

        let project = ProjectContext::discover(Some(nested.clone())).unwrap();

        assert_eq!(project.root, fs::canonicalize(&nested).unwrap());
    }

    #[test]
    fn implicit_root_uses_project_root_environment() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous = std::env::var_os(PROJECT_ROOT_ENV);
        let temp = tempfile::tempdir().unwrap();
        let project_root = temp.path().join("project");
        let nested = project_root.join("nested");
        fs::create_dir_all(project_root.join(".condom")).unwrap();
        fs::create_dir_all(&nested).unwrap();
        fs::write(project_root.join(".condom/config.toml"), "").unwrap();
        std::env::set_var(PROJECT_ROOT_ENV, &project_root);

        let project = ProjectContext::discover(None).unwrap();

        restore_env(PROJECT_ROOT_ENV, previous);
        assert_eq!(project.root, fs::canonicalize(&project_root).unwrap());
    }

    #[test]
    fn explicit_root_ignores_project_root_environment() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous = std::env::var_os(PROJECT_ROOT_ENV);
        let temp = tempfile::tempdir().unwrap();
        let project_root = temp.path().join("project");
        let explicit = temp.path().join("explicit");
        fs::create_dir_all(project_root.join(".condom")).unwrap();
        fs::create_dir_all(&explicit).unwrap();
        fs::write(project_root.join(".condom/config.toml"), "").unwrap();
        std::env::set_var(PROJECT_ROOT_ENV, &project_root);

        let project = ProjectContext::discover(Some(explicit.clone())).unwrap();

        restore_env(PROJECT_ROOT_ENV, previous);
        assert_eq!(project.root, fs::canonicalize(&explicit).unwrap());
    }

    #[test]
    fn project_id_is_stable() {
        let temp = tempfile::tempdir().unwrap();
        let a = ProjectContext::from_root(temp.path().to_path_buf()).unwrap();
        let b = ProjectContext::from_root(temp.path().to_path_buf()).unwrap();
        assert_eq!(a.id, b.id);
    }
}
