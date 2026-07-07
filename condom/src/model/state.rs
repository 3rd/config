use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};

use crate::model::project::ProjectContext;

pub const STATE_HOME_ENV: &str = "CONDOM_STATE_HOME";

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct StatePaths {
    pub project_dir: PathBuf,
    pub runtime_dir: PathBuf,
    pub project_config: PathBuf,
    pub shim_dir: PathBuf,
    pub xdg_state_dir: PathBuf,
    pub policy_dir: PathBuf,
    pub approvals_file: PathBuf,
    pub global_approvals_file: PathBuf,
    pub events_file: PathBuf,
}

impl StatePaths {
    pub fn from_environment(project: &ProjectContext) -> Self {
        let state_base = std::env::var_os(STATE_HOME_ENV)
            .map(PathBuf::from)
            .or_else(|| {
                std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".local/state"))
            })
            .unwrap_or_else(|| project.root.join(".condom/state"));
        Self::from_base(project, &state_base)
    }

    pub fn from_base(project: &ProjectContext, state_base: &Path) -> Self {
        let project_dir = project.root.join(".condom");
        let xdg_state_dir = state_base.join("condom").join(&project.id);
        Self::from_parts(project_dir.clone(), project_dir, state_base, xdg_state_dir)
    }

    pub fn with_runtime_dir(&self, runtime_dir: PathBuf) -> Self {
        Self {
            runtime_dir,
            ..self.clone()
        }
    }

    fn from_parts(
        project_dir: PathBuf,
        runtime_dir: PathBuf,
        state_base: &Path,
        xdg_state_dir: PathBuf,
    ) -> Self {
        Self {
            project_config: project_dir.join("config.toml"),
            shim_dir: project_dir.join("bin"),
            policy_dir: xdg_state_dir.join("policy-snapshots"),
            approvals_file: xdg_state_dir.join("approvals.json"),
            global_approvals_file: state_base.join("condom").join("approvals.json"),
            events_file: xdg_state_dir.join("events.jsonl"),
            project_dir,
            runtime_dir,
            xdg_state_dir,
        }
    }

    pub fn ensure_project_dirs(&self) -> Result<()> {
        for path in [&self.project_dir, &self.shim_dir] {
            fs::create_dir_all(path)
                .with_context(|| format!("failed to create {}", path.display()))?;
        }
        Ok(())
    }

    pub fn ensure_state_dir(&self) -> Result<()> {
        fs::create_dir_all(&self.xdg_state_dir)
            .with_context(|| format!("failed to create {}", self.xdg_state_dir.display()))
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    use std::sync::Mutex;

    use super::*;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    fn project() -> ProjectContext {
        ProjectContext {
            root: PathBuf::from("/tmp/app"),
            id: "project-id".into(),
            origin: None,
        }
    }

    #[test]
    fn state_home_ignores_temporary_xdg_state_home() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_state_home = std::env::var_os(STATE_HOME_ENV);
        let previous_xdg_state_home = std::env::var_os("XDG_STATE_HOME");
        let previous_home = std::env::var_os("HOME");
        std::env::remove_var(STATE_HOME_ENV);
        std::env::set_var("XDG_STATE_HOME", "/tmp/runtime-state");
        std::env::set_var("HOME", "/home/example");

        let state = StatePaths::from_environment(&project());

        restore_env(STATE_HOME_ENV, previous_state_home);
        restore_env("XDG_STATE_HOME", previous_xdg_state_home);
        restore_env("HOME", previous_home);
        assert_eq!(
            state.approvals_file,
            PathBuf::from("/home/example/.local/state/condom/project-id/approvals.json")
        );
    }

    #[test]
    fn explicit_state_home_overrides_home_default() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_state_home = std::env::var_os(STATE_HOME_ENV);
        let previous_home = std::env::var_os("HOME");
        std::env::set_var(STATE_HOME_ENV, "/tmp/condom-state");
        std::env::set_var("HOME", "/home/example");

        let state = StatePaths::from_environment(&project());

        restore_env(STATE_HOME_ENV, previous_state_home);
        restore_env("HOME", previous_home);
        assert_eq!(
            state.approvals_file,
            PathBuf::from("/tmp/condom-state/condom/project-id/approvals.json")
        );
    }

    fn restore_env(key: &str, value: Option<std::ffi::OsString>) {
        if let Some(value) = value {
            std::env::set_var(key, value);
        } else {
            std::env::remove_var(key);
        }
    }
}
