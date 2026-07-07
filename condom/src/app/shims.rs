use std::fs;
use std::path::Path;

use anyhow::{Context, Result};

use crate::model::config::CondomConfig;

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

const DIRENV_SHIM_PATH_LINE: &str = "PATH_add .condom/bin";

pub fn write_shims(config: &CondomConfig, shim_dir: &Path, force: bool) -> Result<Vec<String>> {
    fs::create_dir_all(shim_dir)
        .with_context(|| format!("failed to create {}", shim_dir.display()))?;
    let mut written = Vec::new();
    for (command, route) in &config.shims {
        let path = shim_dir.join(command);
        if path.exists() && !force {
            continue;
        }
        let mode = route.mode.as_str();
        let script = format!(
            "#!/usr/bin/env sh\ncommand_name=$(basename \"$0\")\nexec condom {mode} -- \"$command_name\" \"$@\"\n"
        );
        fs::write(&path, script).with_context(|| format!("failed to write {}", path.display()))?;
        #[cfg(unix)]
        {
            let mut permissions = fs::metadata(&path)?.permissions();
            permissions.set_mode(0o755);
            fs::set_permissions(&path, permissions)?;
        }
        written.push(command.clone());
    }
    written.sort();
    Ok(written)
}

pub fn ensure_direnv_shim_path(project_root: &Path) -> Result<bool> {
    let envrc = project_root.join(".envrc");
    let content = match fs::read_to_string(&envrc) {
        Ok(content) => content,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            fs::write(&envrc, format!("{DIRENV_SHIM_PATH_LINE}\n"))
                .with_context(|| format!("failed to write {}", envrc.display()))?;
            return Ok(true);
        }
        Err(error) => {
            return Err(error).with_context(|| format!("failed to read {}", envrc.display()));
        }
    };
    if content
        .lines()
        .any(|line| line.trim() == DIRENV_SHIM_PATH_LINE)
    {
        return Ok(false);
    }
    let mut updated = content;
    if !updated.ends_with('\n') {
        updated.push('\n');
    }
    updated.push_str(DIRENV_SHIM_PATH_LINE);
    updated.push('\n');
    fs::write(&envrc, updated).with_context(|| format!("failed to write {}", envrc.display()))?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn writes_curated_shims() {
        let temp = tempfile::tempdir().unwrap();
        let written = write_shims(&CondomConfig::default(), temp.path(), false).unwrap();
        assert!(written.contains(&"npm".to_string()));
        assert!(!written.iter().any(|shim| shim == "agent"));
        let npm = fs::read_to_string(temp.path().join("npm")).unwrap();
        assert!(npm.contains("condom run --"));
    }

    #[test]
    fn generated_shims_forward_command_name_and_arguments() {
        let temp = tempfile::tempdir().unwrap();

        write_shims(&CondomConfig::default(), temp.path(), false).unwrap();

        let npm = fs::read_to_string(temp.path().join("npm")).unwrap();
        assert!(npm.contains("command_name=$(basename \"$0\")"));
        assert!(npm.contains("\"$command_name\" \"$@\""));
    }

    #[test]
    fn direnv_hook_adds_shim_path_once() {
        let temp = tempfile::tempdir().unwrap();
        let envrc = temp.path().join(".envrc");
        fs::write(&envrc, "use flake").unwrap();

        assert!(ensure_direnv_shim_path(temp.path()).unwrap());
        assert!(!ensure_direnv_shim_path(temp.path()).unwrap());

        assert_eq!(
            fs::read_to_string(envrc).unwrap(),
            "use flake\nPATH_add .condom/bin\n"
        );
    }
}
