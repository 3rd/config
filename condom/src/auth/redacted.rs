use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use sha2::{Digest, Sha256};

const REDACTED_FILE_MODE: u32 = 0o600;
pub const REDACTED_CONTENT: &str =
    "# redacted by condom\n# Host secret content is intentionally unavailable here.\n";

pub fn materialize_host_path_view(project_dir: &Path, host_path: &str) -> Result<PathBuf> {
    let path = project_dir
        .join("redacted/host")
        .join(format!("{}.txt", digest_path(host_path)));
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }
    fs::write(&path, REDACTED_CONTENT)
        .with_context(|| format!("failed to write redacted view {}", path.display()))?;
    fs::set_permissions(&path, fs::Permissions::from_mode(REDACTED_FILE_MODE))
        .with_context(|| format!("failed to chmod redacted view {}", path.display()))?;
    Ok(path)
}

fn digest_path(path: &str) -> String {
    let digest = Sha256::digest(path.as_bytes());
    let mut output = String::with_capacity(digest.len() * 2);
    for byte in digest {
        output.push_str(&format!("{byte:02x}"));
    }
    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn materializes_deterministic_host_path_view() {
        let temp = tempfile::tempdir().unwrap();

        let first = materialize_host_path_view(temp.path(), "/run/secret/token").unwrap();
        let second = materialize_host_path_view(temp.path(), "/run/secret/token").unwrap();

        assert_eq!(first, second);
        assert!(first.starts_with(temp.path().join("redacted/host")));
        assert_eq!(fs::read_to_string(&first).unwrap(), REDACTED_CONTENT);
        assert_eq!(
            fs::metadata(&first).unwrap().permissions().mode() & 0o777,
            REDACTED_FILE_MODE
        );
    }
}
