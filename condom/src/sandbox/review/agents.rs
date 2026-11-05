use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use anyhow::{bail, Context, Result};
use serde::Deserialize;

use crate::model::config::ReviewAgent;

pub(super) struct PreparedReviewer {
    pub name: &'static str,
    pub files: Vec<ReviewerFile>,
    pub sandbox_dir: PathBuf,
    launcher: &'static str,
    pub runtime_dir: PathBuf,
    state_dir: PathBuf,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ReviewerManifest {
    files: Vec<ReviewerFile>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct ReviewerFile {
    pub source: PathBuf,
    pub destination: PathBuf,
}

pub(super) fn prepare_review_agents(
    agents: &[ReviewAgent],
    session_dir: &Path,
    project_root: &Path,
) -> Result<Vec<PreparedReviewer>> {
    let mut reviewers = Vec::new();
    for agent in agents {
        let (name, launcher) = match agent {
            ReviewAgent::Ccodex => ("ccodex", "ccodex"),
            ReviewAgent::Ccc => ("ccc", "cccc"),
        };
        let runtime_dir = session_dir.join("agent-runtime").join(name);
        let sandbox_dir = project_root.join(".condom/review/agents").join(name);
        let state_dir = session_dir.join("agent-auth").join(name);
        let output = Command::new(launcher)
            .arg("--prepare-condom-review")
            .arg(&runtime_dir)
            .arg(&sandbox_dir)
            .arg(&state_dir)
            .stdin(Stdio::null())
            .stderr(Stdio::inherit())
            .output()
            .with_context(|| format!("failed to prepare {name} reviewer through {launcher}"))?;
        if !output.status.success() {
            bail!("{name} reviewer preparation failed ({})", output.status);
        }
        let manifest: ReviewerManifest = serde_json::from_slice(&output.stdout)
            .with_context(|| format!("invalid {name} reviewer manifest"))?;
        for file in &manifest.files {
            if !file.source.is_absolute()
                || !file.source.is_file()
                || !file.destination.is_absolute()
            {
                bail!("{name} reviewer mounts require existing absolute source files and absolute destinations");
            }
        }
        reviewers.push(PreparedReviewer {
            name,
            files: manifest.files,
            sandbox_dir,
            launcher,
            runtime_dir,
            state_dir,
        });
    }
    Ok(reviewers)
}

pub(super) fn install_review_agent_commands(
    reviewers: &[PreparedReviewer],
    session_dir: &Path,
) -> Result<()> {
    let bin_dir = session_dir.join("runtime/.condom/review/bin");
    fs::create_dir_all(&bin_dir)?;

    for reviewer in reviewers {
        symlink(
            format!("../agents/{}/launch", reviewer.name),
            bin_dir.join(reviewer.name),
        )?;
    }

    Ok(())
}

pub(super) fn finish_review_agents(reviewers: &[PreparedReviewer]) -> Result<()> {
    let mut errors = Vec::new();
    for reviewer in reviewers {
        let result = Command::new(reviewer.launcher)
            .arg("--finish-condom-review")
            .arg(&reviewer.runtime_dir)
            .arg(&reviewer.sandbox_dir)
            .arg(&reviewer.state_dir)
            .stdin(Stdio::null())
            .status();
        match result {
            Ok(status) if status.success() => {}
            Ok(status) => errors.push(format!(
                "{} reviewer login finalization failed ({status})",
                reviewer.name
            )),
            Err(error) => errors.push(format!(
                "{} reviewer login finalization failed: {error}",
                reviewer.name
            )),
        }
    }
    if !errors.is_empty() {
        bail!("{}", errors.join("; "));
    }
    Ok(())
}
