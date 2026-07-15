use std::collections::BTreeMap;
use std::fs;
use std::io::{Read, Write};
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::UnixListener;
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::{Command, Output, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

use condom::app::helper::HELPER_PROTOCOL_VERSION;
use condom::model::config::{CondomConfig, ExecutionMode};
use condom::model::events::EventLog;
use condom::model::policy::{write_snapshot, NetworkMediationSnapshot, TransparentProxySnapshot};
use condom::model::project::ProjectContext;
use condom::model::state::StatePaths;
use condom::sandbox::capture::{self, BindCaptureRun};

const TPROXY_ENV_KEYS: &[&str] = &[
    "CONDOM_TPROXY_ROUTING",
    "CONDOM_TPROXY_PORT",
    "CONDOM_TPROXY_MARK",
    "CONDOM_TPROXY_TABLE",
    "CONDOM_TPROXY_TABLE_NAME",
    "CONDOM_TPROXY_INTERFACE",
    "CONDOM_TPROXY_TCP_PORTS",
];

fn bin() -> &'static str {
    env!("CARGO_BIN_EXE_condom")
}

fn helper_bin() -> &'static str {
    env!("CARGO_BIN_EXE_condom-helper")
}

#[test]
fn nixos_module_declares_tproxy_host_routing() {
    let module = include_str!("../modules/condom.nix");

    assert!(module.contains("transparentProxy"));
    assert!(module.contains("networking.nftables.tables"));
    assert!(module.contains("default = \"lo\";"));
    assert!(module.contains("iifname \"${tproxy.interceptInterface}\""));
    assert!(module.contains("tproxy to :${toString tproxy.proxyPort}"));
    assert!(module.contains("default = 49374;"));
    assert!(module.contains("default = 15080;"));
    assert!(module.contains("while ip rule del pref ${toString tproxy.rulePriority} fwmark"));
    assert!(module.contains("ip rule add pref ${toString tproxy.rulePriority} fwmark"));
    assert!(module.contains("ip route del local 0.0.0.0/0 dev lo table"));
    assert!(module.contains("CONDOM_TPROXY_ROUTING=1"));
    assert!(module.contains("CONDOM_TPROXY_MARK = toString tproxy.mark;"));
    assert!(module.contains("CONDOM_TPROXY_TABLE = toString tproxy.routingTable;"));
    assert!(module.contains("CONDOM_TPROXY_TABLE_NAME = tproxy.tableName;"));
    assert!(module.contains("CONDOM_TPROXY_INTERFACE = tproxy.interceptInterface;"));
    assert!(module.contains("CONDOM_TPROXY_TCP_PORTS=${tcpPortsEnv}"));
    assert!(module.contains("environment.sessionVariables"));
    assert!(module.contains("systemd.services.condom = {"));
    assert!(module.contains("description = \"Condom runtime enforcement\";"));
    assert!(module.contains("wantedBy = [ \"multi-user.target\" ];"));
    assert!(module.contains("wants = [\n        \"nftables.service\"\n      ]"));
    assert!(module.contains("++ lib.optionals (cfg.helperSocket.enable && hasHelperBinary) [ \"condom-helper.socket\" ];"));
    assert!(module.contains("partOf = [ \"condom.service\" ];"));
    assert!(module.contains("requires = [ \"condom.service\" ];"));
    assert!(module.contains("after = [ \"condom.service\" ];"));
    assert!(!module.contains("PrivateTmp = true;"));
    assert!(!module.contains("ProtectSystem = \"strict\";"));
    assert!(!module.contains("wantedBy = [ \"sockets.target\" ];"));
    assert!(!module.contains("systemd.services.condom-tproxy-routing"));
    assert!(module.contains("binaryPath"));
    assert!(module.contains("helperBinaryPath"));
    assert!(!module.contains("tproxy.enable"));
    assert!(!module.contains("installRuntimeWrapper"));
    assert!(module.contains("source = condomBinary;"));
    assert!(module.contains("ExecStart = \"${helperBinary} socket-request\";"));
    assert!(module.contains("UMask = \"0007\";"));
    assert!(module.contains("programs.condom.installPackage requires programs.condom.package."));
    assert!(module.contains("lib.optionals cfg.installSandboxTools ["));
    assert!(module.contains("pkgs.bubblewrap"));
    assert!(module.contains("pkgs.fence"));
    assert!(module.contains(
        "++ lib.optionals (cfg.captureBackendPackage != null) [ cfg.captureBackendPackage ]"
    ));
    assert!(module.contains("installSandboxTools"));
    assert!(module.contains("pkgs.bubblewrap"));
    assert!(module.contains("pkgs.fence"));
    assert!(module.contains("security.wrappers.\"condom-tproxy\""));
    assert!(module.contains("cap_net_admin+ep"));
    assert!(module.contains("helperRuntimeCapabilities = ["));
    assert!(module.contains("\"CAP_CHOWN\""));
    assert!(module.contains("\"CAP_DAC_OVERRIDE\""));
    assert!(module.contains("\"CAP_SETGID\""));
    assert!(module.contains("\"CAP_SETUID\""));
    assert!(module.contains("\"CAP_NET_ADMIN\""));
    assert!(module.contains("CapabilityBoundingSet = helperRuntimeCapabilities;"));
    assert!(module.contains("Type = \"exec\";"));
    assert!(module.contains("Restart = \"no\";"));
    assert!(module.contains("TimeoutStartSec = \"30s\";"));
    assert!(module.contains("TimeoutStopSec = \"10s\";"));
    assert!(module.contains("KillMode = \"mixed\";"));
    assert!(module.contains("NoNewPrivileges = false;"));
    assert!(module.contains("LockPersonality = true;"));
    assert!(module.contains("RestrictRealtime = true;"));
    assert!(module.contains("SystemCallArchitectures = \"native\";"));
}

fn command_with_state(temp: &tempfile::TempDir) -> Command {
    let mut command = Command::new(bin());
    command.env("XDG_CONFIG_HOME", temp.path().join("config"));
    command.env("CONDOM_STATE_HOME", temp.path().join("state"));
    command.env("HOME", temp.path().join("home"));
    command.env_remove("CONDOM_HELPER");
    command.env_remove("CONDOM_HELPER_SOCKET");
    command.env("CONDOM_INTERNAL_DISABLE_HELPER_REENTRY", "1");
    for key in TPROXY_ENV_KEYS {
        command.env_remove(key);
    }
    add_default_fake_approval_prompt(&mut command, temp);
    detach_from_controlling_tty(&mut command);
    command
}

fn add_fake_tproxy_tools(command: &mut Command, temp: &tempfile::TempDir) {
    let bin_dir = temp.path().join("fake-bin");
    fs::create_dir_all(&bin_dir).unwrap();
    let ip = bin_dir.join("ip");
    fs::write(
        &ip,
        r#"#!/bin/sh
case "$*" in
  "-4 rule show")
    printf '%s\n' '15080: from all fwmark 0xc0de lookup 15080'
    ;;
  "-4 route show table 15080")
    printf '%s\n' 'local default dev lo scope host'
    ;;
  *)
    exit 1
    ;;
esac
"#,
    )
    .unwrap();
    fs::set_permissions(&ip, fs::Permissions::from_mode(0o755)).unwrap();
    let nft = bin_dir.join("nft");
    fs::write(
        &nft,
        r#"#!/bin/sh
if [ "$*" = "list table ip condom-tproxy" ]; then
  printf '%s\n' 'table ip condom-tproxy { chain divert { iifname "lo" tcp dport { 80, 443 } tproxy to :15080 meta mark set 49374 accept } }'
else
  exit 1
fi
"#,
    )
    .unwrap();
    fs::set_permissions(&nft, fs::Permissions::from_mode(0o755)).unwrap();
    let old_path = std::env::var("PATH").unwrap_or_default();
    command.env("PATH", format!("{}:{old_path}", bin_dir.display()));
    command.env("CONDOM_TPROXY_ROUTING", "1");
    command.env("CONDOM_TPROXY_PORT", "15080");
    command.env("CONDOM_TPROXY_MARK", "49374");
    command.env("CONDOM_TPROXY_TABLE", "15080");
    command.env("CONDOM_TPROXY_TABLE_NAME", "condom-tproxy");
    command.env("CONDOM_TPROXY_INTERFACE", "lo");
    command.env("CONDOM_TPROXY_TCP_PORTS", "80,443");
}

fn output_with_stdin(mut command: Command, input: &str) -> Output {
    detach_from_controlling_tty(&mut command);
    let mut child = command
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    stdin.write_all(input.as_bytes()).unwrap();
    drop(stdin);
    child.wait_with_output().unwrap()
}

struct ChildProcessGuard {
    child: std::process::Child,
}

impl ChildProcessGuard {
    fn sleeping() -> Self {
        Self {
            child: Command::new("sleep").arg("30").spawn().unwrap(),
        }
    }

    fn id(&self) -> u32 {
        self.child.id()
    }

    fn assert_running(&mut self) {
        assert!(self.child.try_wait().unwrap().is_none());
    }
}

impl Drop for ChildProcessGuard {
    fn drop(&mut self) {
        if matches!(self.child.try_wait(), Ok(None)) {
            let _ = self.child.kill();
        }
        let _ = self.child.wait();
    }
}

fn script_available() -> bool {
    Command::new("script")
        .arg("--version")
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

fn require_script() {
    assert!(
        script_available(),
        "`script` from util-linux is required for PTY integration tests; run through `nix develop . -c make verify`"
    );
}

#[test]
fn makefile_installs_approval_gui_binary() {
    let makefile = fs::read_to_string("Makefile").unwrap();

    assert!(makefile.contains("target/release/condom-approval"));
    assert!(makefile.contains("\"$(BINDIR)/condom-approval\""));
    assert!(!makefile.contains("condom-approval-bin"));
    assert!(!makefile.contains("condom-tproxy-routing.service condom-helper.socket"));
    assert!(!makefile.contains("LD_LIBRARY_PATH"));
}

fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\\''"))
}

fn fake_quiet_approval_prompt_environment(
    temp: &tempfile::TempDir,
    decision: &str,
    output_path: &std::path::Path,
) -> std::collections::BTreeMap<String, String> {
    fake_approval_prompt_environment_with_output(
        temp,
        "fake-approval-bin",
        decision,
        Some(output_path),
    )
}

fn fake_approval_prompt_environment_with_output(
    temp: &tempfile::TempDir,
    bin_dir_name: &str,
    decision: &str,
    output_path: Option<&std::path::Path>,
) -> std::collections::BTreeMap<String, String> {
    let bin_dir = temp.path().join(bin_dir_name);
    fs::create_dir_all(&bin_dir).unwrap();
    let approval = bin_dir.join("condom-approval");
    let output_redirect = output_path
        .map(|path| {
            format!(
                "printf '%s\\n' \"$@\" > {}\n",
                shell_quote(&path.display().to_string())
            )
        })
        .unwrap_or_default();
    fs::write(
        &approval,
        format!(
            "#!/bin/sh\n{}printf '%s\\n' {}\n",
            output_redirect,
            shell_quote(decision)
        ),
    )
    .unwrap();
    fs::set_permissions(&approval, fs::Permissions::from_mode(0o755)).unwrap();
    let mut environment = std::collections::BTreeMap::new();
    environment.insert("CONDOM_APPROVAL_DISPLAY".into(), ":99".into());
    environment.insert(
        "CONDOM_APPROVAL_PATH".into(),
        format!(
            "{}:{}",
            bin_dir.display(),
            std::env::var("PATH").unwrap_or_default()
        ),
    );
    environment
}

fn fake_default_approval_prompt_environment(
    temp: &tempfile::TempDir,
) -> std::collections::BTreeMap<String, String> {
    fake_approval_prompt_environment_with_output(temp, "fake-default-approval-bin", "d", None)
}

fn add_default_fake_approval_prompt(command: &mut Command, temp: &tempfile::TempDir) {
    command.envs(fake_default_approval_prompt_environment(temp));
}

fn remove_prompt_environment(command: &mut Command) {
    for key in [
        "CONDOM_PROMPT_TTY_FD",
        "CONDOM_PROMPT_TTY_PATH",
        "CONDOM_APPROVAL_DISPLAY",
        "CONDOM_APPROVAL_WAYLAND_DISPLAY",
        "CONDOM_APPROVAL_PATH",
        "CONDOM_APPROVAL_XAUTHORITY",
        "CONDOM_APPROVAL_DBUS_SESSION_BUS_ADDRESS",
        "CONDOM_APPROVAL_XDG_RUNTIME_DIR",
        "DISPLAY",
        "WAYLAND_DISPLAY",
        "XDG_RUNTIME_DIR",
    ] {
        command.env_remove(key);
    }
}

fn detach_from_controlling_tty(command: &mut Command) {
    unsafe {
        command.pre_exec(|| {
            if libc::setsid() == -1 {
                Err(std::io::Error::last_os_error())
            } else {
                Ok(())
            }
        });
    }
}

fn output_script_command_with_tty_delay(
    shell_command: &str,
    input: &str,
    input_delay: Duration,
) -> Output {
    require_script();

    let mut command = Command::new("script");
    command
        .args(["--quiet", "--return", "--command"])
        .arg(shell_command)
        .arg("/dev/null")
        .env_remove("LD_PRELOAD")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    for key in TPROXY_ENV_KEYS {
        command.env_remove(key);
    }
    let mut child = command.spawn().unwrap();
    let mut stdin = child.stdin.take().unwrap();
    thread::sleep(input_delay);
    for byte in input.as_bytes() {
        if let Err(error) = stdin.write_all(&[*byte]) {
            assert_eq!(error.kind(), std::io::ErrorKind::BrokenPipe);
            break;
        }
        thread::sleep(Duration::from_millis(250));
    }
    drop(stdin);
    child.wait_with_output().unwrap()
}

fn assert_network_enforcement_unavailable(output: &Output) {
    assert!(
        !output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(
        String::from_utf8_lossy(&output.stderr)
            .contains("network enforcement unavailable: transparent proxy routing is not active"),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}

fn json_value_from_tty_output(output: &Output) -> serde_json::Value {
    let stdout = String::from_utf8_lossy(&output.stdout);
    let start = stdout.find('{').unwrap_or_else(|| {
        panic!(
            "missing JSON object in tty output\nstdout={stdout}\nstderr={}",
            String::from_utf8_lossy(&output.stderr)
        )
    });
    serde_json::from_str(&stdout[start..]).unwrap()
}

fn policy_snapshots(temp: &tempfile::TempDir) -> Vec<serde_json::Value> {
    policy_snapshot_paths(temp)
        .into_iter()
        .map(|path| serde_json::from_str(&fs::read_to_string(path).unwrap()).unwrap())
        .collect()
}

fn project_context(temp: &tempfile::TempDir) -> ProjectContext {
    ProjectContext::from_root(temp.path().to_path_buf()).unwrap()
}

fn write_run_policy_snapshot(
    temp: &tempfile::TempDir,
    config: &CondomConfig,
    command: &[String],
) -> condom::model::policy::PolicySnapshot {
    let project = project_context(temp);
    let state = StatePaths::from_base(&project, &temp.path().join("state"));
    condom::model::policy::write_snapshot_with_network(
        &project,
        &state,
        config,
        ExecutionMode::Run,
        command,
        NetworkMediationSnapshot {
            allowed_loopback_ports: vec![80, 443, 15080],
            proxy_listen_port: Some(15080),
            transparent_proxy: TransparentProxySnapshot {
                enabled: true,
                tcp_ports: vec![80, 443],
                allowed_hosts: Vec::new(),
            },
        },
    )
    .unwrap()
}

fn policy_snapshot_paths(temp: &tempfile::TempDir) -> Vec<std::path::PathBuf> {
    let state_root = temp.path().join("state/condom");
    if !state_root.is_dir() {
        return Vec::new();
    }
    let mut paths = Vec::new();
    for project_entry in fs::read_dir(state_root).unwrap() {
        let policy_dir = project_entry.unwrap().path().join("policy-snapshots");
        if !policy_dir.is_dir() {
            continue;
        }
        for snapshot_entry in fs::read_dir(policy_dir).unwrap() {
            paths.push(snapshot_entry.unwrap().path());
        }
    }
    paths
}

fn helper_run_result_paths(temp: &tempfile::TempDir) -> Vec<std::path::PathBuf> {
    let state_root = temp.path().join("state/condom");
    if !state_root.is_dir() {
        return Vec::new();
    }
    let mut paths = Vec::new();
    for project_entry in fs::read_dir(state_root).unwrap() {
        for state_entry in fs::read_dir(project_entry.unwrap().path()).unwrap() {
            let path = state_entry.unwrap().path();
            if path
                .file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| {
                    name.ends_with("-helper-run-result.json")
                        || name.ends_with("-helper-review-result.json")
                })
            {
                paths.push(path);
            }
        }
    }
    paths
}

fn fence_available() -> bool {
    Command::new("fence")
        .arg("--help")
        .output()
        .map(|output| {
            let help = format!(
                "{}\n{}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
            help.contains("-m") && help.contains("--settings") && help.contains("--fence-log-file")
        })
        .unwrap_or(false)
}

fn require_fence() {
    assert!(
        fence_available(),
        "`fence -m --settings --fence-log-file` is required for host integration tests; run through `nix develop . -c make verify`"
    );
}

fn bwrap_supervisor_surface_available() -> bool {
    Command::new("bwrap")
        .arg("--help")
        .output()
        .map(|output| {
            if !output.status.success() {
                return false;
            }
            let help = format!(
                "{}\n{}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
            [
                "--bind",
                "--ro-bind",
                "--tmpfs",
                "--proc",
                "--dev",
                "--unshare-pid",
                "--die-with-parent",
            ]
            .iter()
            .all(|flag| help.contains(flag))
        })
        .unwrap_or(false)
}

const REQUIRED_HELPER_CAPABILITIES: &[&str] = &[
    "mount-isolation",
    "process-restrictions",
    "syscall-restrictions",
];
fn capability_names(capabilities: &[serde_json::Value]) -> Vec<String> {
    capabilities
        .iter()
        .map(|capability| capability.as_str().unwrap().to_string())
        .collect()
}

fn helper_probe_capability_names() -> Vec<String> {
    let mut command = Command::new(helper_bin());
    command.arg("request");
    let output = output_with_stdin(
        command,
        &format!(r#"{{"type":"probe","protocolVersion":{HELPER_PROTOCOL_VERSION}}}"#),
    );
    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["type"], "ready");
    capability_names(value["capabilities"].as_array().unwrap())
}

fn has_required_helper_capabilities(capabilities: &[String]) -> bool {
    REQUIRED_HELPER_CAPABILITIES
        .iter()
        .all(|capability| capabilities.iter().any(|available| available == capability))
}

fn doctor_json_has_failed_check(value: &serde_json::Value) -> bool {
    value
        .as_array()
        .unwrap()
        .iter()
        .any(|check| check["status"] == "fail")
}

fn require_fuse_device() {
    assert!(
        std::path::Path::new("/dev/fuse").exists(),
        "`/dev/fuse` is required for configured capture backend integration tests"
    );
}

#[test]
fn init_writes_config_and_shims() {
    let temp = tempfile::tempdir().unwrap();
    let output = command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );

    assert!(temp.path().join(".condom/config.toml").is_file());
    assert_eq!(
        fs::read_to_string(temp.path().join(".envrc")).unwrap(),
        "PATH_add .condom/bin\n"
    );
    assert!(temp.path().join(".condom/bin/npm").is_file());
    let npm = fs::read_to_string(temp.path().join(".condom/bin/npm")).unwrap();
    assert!(npm.contains("command_name=$(basename \"$0\")"));
    assert!(npm.contains("exec condom run -- \"$command_name\" \"$@\""));
}

#[test]
fn env_command_updates_project_environment_policy() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let allow = command_with_state(&temp)
        .args(["env", "--root"])
        .arg(temp.path())
        .args(["allow", "SOURCE_TOKEN"])
        .output()
        .unwrap();
    assert!(
        allow.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        allow.status.code(),
        String::from_utf8_lossy(&allow.stdout),
        String::from_utf8_lossy(&allow.stderr)
    );

    let deny = command_with_state(&temp)
        .args(["env", "--root"])
        .arg(temp.path())
        .args(["deny", "SOURCE_TOKEN"])
        .output()
        .unwrap();
    assert!(
        deny.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        deny.status.code(),
        String::from_utf8_lossy(&deny.stdout),
        String::from_utf8_lossy(&deny.stderr)
    );

    let list = command_with_state(&temp)
        .args(["env", "--root"])
        .arg(temp.path())
        .args(["ls", "--json"])
        .output()
        .unwrap();
    assert!(
        list.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        list.status.code(),
        String::from_utf8_lossy(&list.stdout),
        String::from_utf8_lossy(&list.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&list.stdout).unwrap();
    assert!(value["allow"].as_array().unwrap().is_empty());
    assert_eq!(value["deny"], serde_json::json!(["SOURCE_TOKEN"]));

    let config = fs::read_to_string(temp.path().join(".condom/config.toml")).unwrap();
    assert!(config.contains("[environment]"));
    assert!(config.contains("deny = [\"SOURCE_TOKEN\"]"));

    let remove = command_with_state(&temp)
        .args(["env", "--root"])
        .arg(temp.path())
        .args(["rm", "SOURCE_TOKEN"])
        .output()
        .unwrap();
    assert!(
        remove.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        remove.status.code(),
        String::from_utf8_lossy(&remove.stdout),
        String::from_utf8_lossy(&remove.stderr)
    );

    let list = command_with_state(&temp)
        .args(["env", "--root"])
        .arg(temp.path())
        .args(["ls", "--json"])
        .output()
        .unwrap();
    assert!(list.status.success());
    let value: serde_json::Value = serde_json::from_slice(&list.stdout).unwrap();
    assert!(value["allow"].as_array().unwrap().is_empty());
    assert!(value["deny"].as_array().unwrap().is_empty());
}

#[test]
fn env_command_removes_invalid_project_environment_policy() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    fs::write(
        temp.path().join(".condom/config.toml"),
        "[environment]\nallow = [\"HOME\"]\n",
    )
    .unwrap();

    let remove = command_with_state(&temp)
        .args(["env", "--root"])
        .arg(temp.path())
        .args(["rm", "HOME"])
        .output()
        .unwrap();
    assert!(
        remove.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        remove.status.code(),
        String::from_utf8_lossy(&remove.stdout),
        String::from_utf8_lossy(&remove.stderr)
    );

    let list = command_with_state(&temp)
        .args(["env", "--root"])
        .arg(temp.path())
        .args(["ls", "--json"])
        .output()
        .unwrap();
    assert!(list.status.success());
    let value: serde_json::Value = serde_json::from_slice(&list.stdout).unwrap();
    assert!(value["allow"].as_array().unwrap().is_empty());
    assert!(value["deny"].as_array().unwrap().is_empty());
}

#[test]
fn init_refuses_noninteractive_overwrite_without_force() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let config_path = temp.path().join(".condom/config.toml");
    fs::write(&config_path, "sentinel = true\n").unwrap();

    let output = command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap();

    assert!(!output.status.success());
    assert_eq!(
        fs::read_to_string(config_path).unwrap(),
        "sentinel = true\n"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("rerun from an interactive terminal"));
}

#[test]
fn init_force_overwrites_existing_config() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let config_path = temp.path().join(".condom/config.toml");
    fs::write(&config_path, "sentinel = true\n").unwrap();

    let output = command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .arg("--force")
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let config = fs::read_to_string(config_path).unwrap();
    assert!(config.contains("[defaults]"));
    assert!(!config.contains("sentinel"));
}

#[test]
fn status_json_reports_initialized_project() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let output = command_with_state(&temp)
        .args(["status", "--root"])
        .arg(temp.path())
        .arg("--json")
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["initialized"], true);
    assert_eq!(value["recentBlockCount"], 0);
    assert!(value["recentBlocks"].as_array().unwrap().is_empty());
    assert_eq!(value["proxyStatus"]["configured"], true);
    assert!(value["proxyStatus"]["adapters"]
        .as_array()
        .unwrap()
        .iter()
        .any(|adapter| adapter == "npm"));
    assert_eq!(
        value["proxyStatus"]["lastDecision"],
        serde_json::Value::Null
    );
}

#[test]
fn run_fails_before_fence_when_network_enforcement_is_missing() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let marker = temp.path().join("marker");
    let script = format!(
        "test -z \"${{CONDOM_INTERNAL_DISABLE_HELPER_REENTRY+x}}\" && touch {}",
        marker.display()
    );
    let output = command_with_state(&temp)
        .args(["run", "--root"])
        .arg(temp.path())
        .args(["--", "sh", "-c"])
        .arg(&script)
        .output()
        .unwrap();

    assert_network_enforcement_unavailable(&output);
    assert!(!marker.exists());
    assert!(policy_snapshots(&temp).is_empty());
}

#[test]
fn run_fails_before_configured_helper_binary_when_network_enforcement_is_missing() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let output = command_with_state(&temp)
        .env_remove("CONDOM_INTERNAL_DISABLE_HELPER_REENTRY")
        .env("CONDOM_HELPER", helper_bin())
        .args(["run", "--root"])
        .arg(temp.path())
        .args([
            "--",
            "sh",
            "-c",
            "printf delegated > helper-owned-run.txt; exit 7",
        ])
        .output()
        .unwrap();

    assert_network_enforcement_unavailable(&output);
    assert!(!temp.path().join("helper-owned-run.txt").exists());
    assert!(helper_run_result_paths(&temp).is_empty());
    assert!(policy_snapshots(&temp).is_empty());
}

#[test]
fn run_fails_before_configured_helper_socket_when_network_enforcement_is_missing() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let socket = temp.path().join("helper.sock");

    let output = command_with_state(&temp)
        .env_remove("CONDOM_INTERNAL_DISABLE_HELPER_REENTRY")
        .env("CONDOM_HELPER_SOCKET", &socket)
        .args(["run", "--root"])
        .arg(temp.path())
        .args([
            "--",
            "sh",
            "-c",
            "printf socket-delegated > helper-socket-run.txt; exit 7",
        ])
        .output()
        .unwrap();
    assert_network_enforcement_unavailable(&output);
    assert!(!temp.path().join("helper-socket-run.txt").exists());
    assert!(helper_run_result_paths(&temp).is_empty());
    assert!(policy_snapshots(&temp).is_empty());
}

#[test]
fn run_fails_before_home_read_when_network_enforcement_is_missing() {
    let temp = tempfile::tempdir().unwrap();
    let host = tempfile::tempdir_in(std::env::current_dir().unwrap()).unwrap();
    let home = host.path().join("home");
    let secret = home.join(".ssh/id_rsa");
    fs::create_dir_all(secret.parent().unwrap()).unwrap();
    fs::write(&secret, "host secret").unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let output = command_with_state(&temp)
        .env("HOME", &home)
        .env_remove("TMUX")
        .env_remove("DISPLAY")
        .env_remove("WAYLAND_DISPLAY")
        .env_remove("CONDOM_APPROVAL_DISPLAY")
        .env_remove("CONDOM_APPROVAL_WAYLAND_DISPLAY")
        .args(["run", "--root"])
        .arg(temp.path())
        .args(["--", "sh", "-c", "cat \"$HOME/.ssh/id_rsa\""])
        .output()
        .unwrap();

    assert_network_enforcement_unavailable(&output);
    assert!(!String::from_utf8_lossy(&output.stdout).contains("host secret"));
    assert!(policy_snapshots(&temp).is_empty());
}

#[test]
fn landlock_runner_serves_configured_redacted_host_file_view() {
    require_fence();
    let temp = tempfile::tempdir().unwrap();
    let secret = std::path::PathBuf::from("/etc/passwd");
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    fs::write(
        temp.path().join(".condom/config.toml"),
        format!("[filesystem]\nredactRead = [\"{}\"]\n", secret.display()),
    )
    .unwrap();
    let command = vec!["cat".into(), secret.display().to_string()];
    let config = CondomConfig::load(temp.path(), None).unwrap();
    let snapshot = write_run_policy_snapshot(&temp, &config, &command);

    let output = command_with_state(&temp)
        .args(["__landlock-exec", "--policy-snapshot"])
        .arg(snapshot.path)
        .args(["--", "cat"])
        .arg(&secret)
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("redacted by condom"));
    assert!(!stdout.contains("root:"));
    let events = command_with_state(&temp)
        .args(["events", "--root"])
        .arg(temp.path())
        .arg("--json")
        .output()
        .unwrap();
    assert!(events.status.success());
    let value: serde_json::Value = serde_json::from_slice(&events.stdout).unwrap();
    assert!(value.as_array().unwrap().iter().any(|event| {
        event["eventType"] == "filesystem"
            && event["decision"] == "redacted"
            && event["subject"] == secret.display().to_string()
    }));
}

#[test]
fn landlock_runner_allows_system_trust_store_reads() {
    require_fence();
    let temp = tempfile::tempdir().unwrap();
    let certificate_bundle = std::path::PathBuf::from("/etc/ssl/certs/ca-certificates.crt");
    assert!(certificate_bundle.exists());
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let command = vec![
        "sh".into(),
        "-c".into(),
        "test -r \"$1\" && head -c 1 \"$1\" >/dev/null && printf cert-ok".into(),
        "sh".into(),
        certificate_bundle.display().to_string(),
    ];
    let config = CondomConfig::load(temp.path(), None).unwrap();
    let snapshot = write_run_policy_snapshot(&temp, &config, &command);

    let output = command_with_state(&temp)
        .args(["__landlock-exec", "--policy-snapshot"])
        .arg(snapshot.path)
        .arg("--")
        .args(command)
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "cert-ok");
}

#[test]
fn review_capture_mediates_write_and_preserves_captured_content() {
    assert!(
        bwrap_supervisor_surface_available(),
        "bubblewrap capture surface is required"
    );
    let temp = tempfile::tempdir().unwrap();
    let project = ProjectContext {
        root: temp.path().join("project"),
        id: "project-id".into(),
        origin: None,
    };
    fs::create_dir_all(&project.root).unwrap();
    fs::write(project.root.join("baseline.txt"), "baseline\n").unwrap();
    let state = StatePaths::from_base(&project, &temp.path().join("state"))
        .with_runtime_dir(temp.path().join("runtime/.condom"));
    let config = CondomConfig::default();
    let captured_path = project.root.join("captured.txt");
    let command = vec![
        "/run/current-system/sw/bin/sh".into(),
        "-c".into(),
        format!(
            "printf '%s' 'captured bytes' > '{}'",
            captured_path.display()
        ),
    ];
    let snapshot = write_snapshot(
        &project,
        &state,
        &config,
        ExecutionMode::Review,
        &command,
        &[],
    )
    .unwrap();
    let session_dir = temp.path().join("session");
    let workspace_dir = session_dir.join("workspace");
    fs::create_dir_all(&workspace_dir).unwrap();
    fs::copy(
        project.root.join("baseline.txt"),
        workspace_dir.join("baseline.txt"),
    )
    .unwrap();
    let event_log = EventLog::new(state.events_file.clone());
    let runtime_path = std::env::var("PATH").ok();

    let code = capture::run_with_bind_capture(BindCaptureRun {
        project: &project,
        state: &state,
        session_dir: &session_dir,
        workspace_dir: &workspace_dir,
        config: &config,
        mode: ExecutionMode::Review,
        command: &command,
        extra_env: &BTreeMap::new(),
        event_log: &event_log,
        policy_snapshot: &snapshot,
        runner_path: Some(Path::new(bin())),
        runtime_path: runtime_path.as_deref(),
        ephemeral_overlays: &[],
        mediate_filesystem: true,
        review_inspection: false,
    })
    .unwrap();

    assert_eq!(code, 0);
    assert!(!captured_path.exists());
    assert_eq!(
        fs::read_to_string(workspace_dir.join("captured.txt")).unwrap(),
        "captured bytes"
    );
}

#[test]
fn landlock_runner_denies_outside_project_write() {
    require_fence();
    let temp = tempfile::tempdir().unwrap();
    let outside = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    fs::write(
        temp.path().join(".condom/config.toml"),
        format!(
            "[filesystem]\nallowRead = [\"{}\"]\n",
            outside.path().display()
        ),
    )
    .unwrap();
    let config = CondomConfig::load(temp.path(), None).unwrap();
    let snapshot =
        write_run_policy_snapshot(&temp, &config, &["sh".into(), "-c".into(), "true".into()]);

    let blocked = outside.path().join("blocked");
    let output = command_with_state(&temp)
        .args(["__landlock-exec", "--policy-snapshot"])
        .arg(snapshot.path)
        .args(["--", "sh", "-c", "echo no > \"$1\"", "sh"])
        .arg(&blocked)
        .output()
        .unwrap();

    assert!(!output.status.success());
    assert!(!blocked.exists());
    assert!(
        String::from_utf8_lossy(&output.stderr).contains("Permission denied"),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}

#[test]
fn approved_filesystem_write_allows_outside_project_write() {
    require_fence();
    let temp = tempfile::tempdir().unwrap();
    let outside = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let approval = command_with_state(&temp)
        .args(["allow", "--root"])
        .arg(temp.path())
        .args(["add", "fs-write"])
        .arg(outside.path())
        .output()
        .unwrap();
    assert!(
        approval.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        approval.status.code(),
        String::from_utf8_lossy(&approval.stdout),
        String::from_utf8_lossy(&approval.stderr)
    );

    let marker = outside.path().join("approved.txt");
    let command = vec![
        "sh".into(),
        "-c".into(),
        "printf ok > \"$1/approved.txt\"".into(),
        "sh".into(),
        outside.path().display().to_string(),
    ];
    let config = CondomConfig::load(temp.path(), None).unwrap();
    let snapshot = write_run_policy_snapshot(&temp, &config, &command);
    let output = command_with_state(&temp)
        .args(["__landlock-exec", "--policy-snapshot"])
        .arg(snapshot.path)
        .arg("--")
        .args(command)
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(fs::read_to_string(marker).unwrap(), "ok");
}

#[test]
fn landlock_runner_denies_signaling_outside_process() {
    require_fence();
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let config = CondomConfig::load(temp.path(), None).unwrap();
    let snapshot =
        write_run_policy_snapshot(&temp, &config, &["sh".into(), "-c".into(), "true".into()]);
    let mut outside_process = ChildProcessGuard::sleeping();
    let output = command_with_state(&temp)
        .args(["__landlock-exec", "--policy-snapshot"])
        .arg(snapshot.path)
        .args(["--", "sh", "-c", "kill -0 \"$1\"", "sh"])
        .arg(outside_process.id().to_string())
        .output()
        .unwrap();

    assert!(!output.status.success());
    assert!(
        String::from_utf8_lossy(&output.stderr).contains("Operation not permitted"),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    outside_process.assert_running();
}

#[test]
fn landlock_runner_propagates_child_exit_code() {
    require_fence();
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let command = vec!["sh".into(), "-c".into(), "exit 7".into()];
    let config = CondomConfig::load(temp.path(), None).unwrap();
    let snapshot = write_run_policy_snapshot(&temp, &config, &command);

    let output = command_with_state(&temp)
        .args(["__landlock-exec", "--policy-snapshot"])
        .arg(snapshot.path)
        .arg("--")
        .args(command)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(7));
}

#[test]
fn landlock_runner_fails_closed_when_gui_fails() {
    require_script();
    let temp = tempfile::tempdir().unwrap();
    let outside = tempfile::NamedTempFile::new().unwrap();
    fs::write(outside.path(), "host secret").unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let command = vec!["cat".into(), outside.path().display().to_string()];
    let config = CondomConfig::load(temp.path(), None).unwrap();
    let snapshot = write_run_policy_snapshot(&temp, &config, &command);
    let bin_dir = temp.path().join("failing-approval-bin");
    fs::create_dir_all(&bin_dir).unwrap();
    let approval = bin_dir.join("condom-approval");
    let approval_args = temp.path().join("approval-args");
    fs::write(
        &approval,
        format!(
            "#!/bin/sh\nprintf '%s\\n' \"$@\" > {}\nprintf '%s\\n' 'gui failed' >&2\nexit 1\n",
            shell_quote(&approval_args.display().to_string())
        ),
    )
    .unwrap();
    fs::set_permissions(&approval, fs::Permissions::from_mode(0o755)).unwrap();

    let shell_command = format!(
        "CONDOM_APPROVAL_DISPLAY=:99 CONDOM_APPROVAL_PATH={} {} __landlock-exec --policy-snapshot {} -- cat {}",
        shell_quote(&bin_dir.display().to_string()),
        shell_quote(bin()),
        shell_quote(&snapshot.path.display().to_string()),
        shell_quote(&outside.path().display().to_string()),
    );
    let output =
        output_script_command_with_tty_delay(&shell_command, "d\n", Duration::from_millis(250));

    assert!(
        !output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(!stdout.contains("condom blocked filesystem access"));
    assert!(!stdout.contains("decision:"));
    assert!(!stdout.contains("host secret"));
    let args = fs::read_to_string(approval_args).unwrap();
    assert!(args.contains("--request-json"));
}

#[test]
fn landlock_runner_applies_approved_host_read_from_supervisor() {
    require_fence();
    let temp = tempfile::tempdir().unwrap();
    let prompt_bin = tempfile::tempdir().unwrap();
    let outside = tempfile::NamedTempFile::new().unwrap();
    fs::write(outside.path(), "host secret").unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let approval = prompt_bin.path().join("condom-approval");
    fs::write(&approval, "#!/bin/sh\nprintf '%s\\n' o\n").unwrap();
    fs::set_permissions(&approval, fs::Permissions::from_mode(0o755)).unwrap();
    let command = vec!["cat".into(), outside.path().display().to_string()];
    let config = CondomConfig::load(temp.path(), None).unwrap();
    let snapshot = write_run_policy_snapshot(&temp, &config, &command);

    let output = command_with_state(&temp)
        .env("CONDOM_APPROVAL_DISPLAY", ":99")
        .env("CONDOM_APPROVAL_PATH", prompt_bin.path())
        .args(["__landlock-exec", "--policy-snapshot"])
        .arg(snapshot.path)
        .args(["--", "cat"])
        .arg(outside.path())
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "host secret");
}

#[test]
fn review_fails_before_capture_when_network_enforcement_is_missing() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let live_file = temp.path().join("reviewed.txt");
    let output = command_with_state(&temp)
        .env("CONDOM_REVIEW_SHELL", "true")
        .args(["review", "--root"])
        .arg(temp.path())
        .args(["--", "sh", "-c", "echo should-not-run > reviewed.txt"])
        .output()
        .unwrap();

    assert_network_enforcement_unavailable(&output);
    assert!(!live_file.exists());
    assert!(policy_snapshots(&temp).is_empty());
}

#[test]
fn helper_request_rejects_protocol_mismatch() {
    let mut command = Command::new(helper_bin());
    command.arg("request");
    let output = output_with_stdin(command, r#"{"type":"probe","protocolVersion":999}"#);

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["type"], "unsupported-protocol");
    assert_eq!(value["expected"], HELPER_PROTOCOL_VERSION);
    assert_eq!(value["actual"], 999);
}

#[test]
fn helper_request_reports_capabilities() {
    let mut command = Command::new(helper_bin());
    command.arg("request");
    let output = output_with_stdin(
        command,
        &format!(r#"{{"type":"probe","protocolVersion":{HELPER_PROTOCOL_VERSION}}}"#),
    );

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["type"], "ready");
    assert_eq!(value["protocolVersion"], HELPER_PROTOCOL_VERSION);
    let capabilities = capability_names(value["capabilities"].as_array().unwrap());
    if bwrap_supervisor_surface_available() {
        assert!(capabilities
            .iter()
            .any(|capability| capability == "mount-isolation"));
        assert!(capabilities
            .iter()
            .any(|capability| capability == "process-restrictions"));
    } else {
        assert!(!capabilities
            .iter()
            .any(|capability| capability == "mount-isolation"));
        assert!(!capabilities
            .iter()
            .any(|capability| capability == "process-restrictions"));
    }
    if cfg!(target_arch = "x86_64") {
        assert!(capabilities
            .iter()
            .any(|capability| capability == "syscall-restrictions"));
    }
    assert!(!capabilities
        .iter()
        .any(|capability| capability == "network-routing"));
}

#[test]
fn helper_request_reports_network_routing_when_tproxy_is_configured() {
    let temp = tempfile::tempdir().unwrap();
    let mut command = Command::new(helper_bin());
    command.arg("request");
    add_fake_tproxy_tools(&mut command, &temp);
    let output = output_with_stdin(
        command,
        &format!(r#"{{"type":"probe","protocolVersion":{HELPER_PROTOCOL_VERSION}}}"#),
    );

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    let capabilities = capability_names(value["capabilities"].as_array().unwrap());
    assert!(capabilities
        .iter()
        .any(|capability| capability == "network-routing"));
}

#[test]
fn helper_prepare_sandbox_rejects_missing_policy_snapshot() {
    let temp = tempfile::tempdir().unwrap();
    let project = project_context(&temp);
    let mut command = Command::new(helper_bin());
    command.arg("request");
    let missing_id = "00000000-0000-0000-0000-000000000000";
    let output = output_with_stdin(
        command,
        &serde_json::json!({
            "type": "prepare-sandbox",
            "protocolVersion": HELPER_PROTOCOL_VERSION,
            "projectRoot": project.root,
            "projectId": project.id,
            "stateRoot": temp.path().join("state"),
            "policySnapshotId": missing_id,
        })
        .to_string(),
    );

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["type"], "invalid-request");
    assert!(value["message"]
        .as_str()
        .unwrap()
        .contains(&format!("failed to load policy snapshot `{missing_id}`")));
}

#[test]
fn helper_prepare_sandbox_reports_missing_capabilities_after_snapshot_preflight() {
    require_fence();
    let helper_capabilities = helper_probe_capability_names();
    let temp = tempfile::tempdir().unwrap();
    let project = project_context(&temp);
    let state = StatePaths::from_base(&project, &temp.path().join("state"));
    let snapshot = condom::model::policy::write_snapshot_with_network(
        &project,
        &state,
        &CondomConfig::default(),
        ExecutionMode::Run,
        &["sh".into(), "-c".into(), "true".into()],
        NetworkMediationSnapshot {
            allowed_loopback_ports: vec![80, 443, 15080],
            proxy_listen_port: Some(15080),
            transparent_proxy: TransparentProxySnapshot {
                enabled: true,
                tcp_ports: vec![80, 443],
                allowed_hosts: Vec::new(),
            },
        },
    )
    .unwrap();
    let mut command = Command::new(helper_bin());
    command.arg("request");
    let output = output_with_stdin(
        command,
        &serde_json::json!({
            "type": "prepare-sandbox",
            "protocolVersion": HELPER_PROTOCOL_VERSION,
            "projectRoot": project.root,
            "projectId": project.id,
            "stateRoot": temp.path().join("state"),
            "policySnapshotId": snapshot.id,
        })
        .to_string(),
    );

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    let required_capabilities = [
        "mount-isolation",
        "process-restrictions",
        "syscall-restrictions",
        "network-routing",
    ];
    let has_snapshot_capabilities = required_capabilities.iter().all(|capability| {
        helper_capabilities
            .iter()
            .any(|available| available == capability)
    });
    if has_snapshot_capabilities {
        assert_eq!(value["type"], "sandbox-prepared");
        assert_eq!(value["protocolVersion"], HELPER_PROTOCOL_VERSION);
        assert_eq!(value["policySnapshotId"], snapshot.id.to_string());
        assert_eq!(value["runner"], "fence-landlock-seccomp");
        let capabilities = capability_names(value["capabilities"].as_array().unwrap());
        for capability in required_capabilities {
            assert!(capabilities.iter().any(|available| available == capability));
        }
    } else {
        assert_eq!(value["type"], "missing-capabilities");
        let missing = capability_names(value["missingCapabilities"].as_array().unwrap());
        assert!(!missing.is_empty());
        for capability in required_capabilities {
            if !helper_capabilities
                .iter()
                .any(|available| available == capability)
            {
                assert!(missing.iter().any(|missing| missing == capability));
            }
        }
        if bwrap_supervisor_surface_available() {
            assert!(!missing.iter().any(|missing| missing == "mount-isolation"));
            assert!(!missing
                .iter()
                .any(|missing| missing == "process-restrictions"));
        }
    }
}

#[test]
fn helper_authorizes_filesystem_access_with_stored_approval() {
    let temp = tempfile::tempdir().unwrap();
    let project = project_context(&temp);
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let output = command_with_state(&temp)
        .args(["allow", "--root"])
        .arg(temp.path())
        .args(["add", "fs-read", "/opt/sdk", "--once"])
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );

    let request = serde_json::json!({
        "type": "authorize-filesystem",
        "protocolVersion": HELPER_PROTOCOL_VERSION,
        "projectRoot": project.root,
        "projectId": project.id,
        "stateRoot": temp.path().join("state"),
        "mode": "run",
        "command": ["tool"],
        "kind": "fs-read",
        "path": "/opt/sdk",
        "promptEnvironment": {}
    });
    let mut command = Command::new(helper_bin());
    command.arg("request").env("HOME", temp.path().join("home"));
    let output = output_with_stdin(command, &request.to_string());

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["type"], "filesystem-authorization");
    assert_eq!(value["decision"], "allow");
    assert_eq!(value["reason"], "allowed by stored filesystem approval");
    assert_eq!(value["suggestedAllow"], serde_json::Value::Null);

    let events = command_with_state(&temp)
        .args(["events", "--root"])
        .arg(temp.path())
        .arg("--json")
        .output()
        .unwrap();
    assert!(events.status.success());
    let value: serde_json::Value = serde_json::from_slice(&events.stdout).unwrap();
    assert!(value.as_array().unwrap().iter().any(|event| {
        event["eventType"] == "approval"
            && event["subject"] == "/opt/sdk"
            && event["decision"] == "allowed"
    }));
}

#[test]
fn helper_authorizes_filesystem_access_with_policy_snapshot() {
    require_fence();
    let temp = tempfile::tempdir().unwrap();
    let project = project_context(&temp);
    let project_file = temp.path().join("src.txt");
    fs::write(&project_file, "hello").unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let config = CondomConfig::load(temp.path(), None).unwrap();
    let snapshot = write_run_policy_snapshot(&temp, &config, &["tool".into()]);

    let request = serde_json::json!({
        "type": "authorize-filesystem",
        "protocolVersion": HELPER_PROTOCOL_VERSION,
        "projectRoot": project.root,
        "projectId": project.id,
        "stateRoot": temp.path().join("state"),
        "mode": "run",
        "command": ["tool"],
        "kind": "fs-read",
        "path": project_file,
        "policySnapshotId": snapshot.id,
        "promptEnvironment": {}
    });
    let mut command = Command::new(helper_bin());
    command.arg("request").env("HOME", temp.path().join("home"));
    let output = output_with_stdin(command, &request.to_string());

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["type"], "filesystem-authorization");
    assert_eq!(value["decision"], "allow");
    assert!(value["reason"]
        .as_str()
        .unwrap()
        .contains("policy snapshot pattern"));
    assert_eq!(value["suggestedAllow"], serde_json::Value::Null);
}

#[test]
fn helper_authorizes_filesystem_access_with_external_prompt() {
    let temp = tempfile::tempdir().unwrap();
    let project = project_context(&temp);
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let prompt_output = temp.path().join("helper-prompt-output");

    let request = serde_json::json!({
        "type": "authorize-filesystem",
        "protocolVersion": HELPER_PROTOCOL_VERSION,
        "projectRoot": project.root,
        "projectId": project.id,
        "stateRoot": temp.path().join("state"),
        "mode": "run",
        "command": ["tool"],
        "kind": "fs-write",
        "path": "/opt/cache",
        "promptEnvironment": fake_quiet_approval_prompt_environment(&temp, "aa", &prompt_output)
    });
    let request_path = temp.path().join("helper-request.json");
    fs::write(&request_path, request.to_string()).unwrap();
    let shell_command = format!(
        "HOME={} {} request < {}",
        shell_quote(&temp.path().join("home").display().to_string()),
        shell_quote(helper_bin()),
        shell_quote(&request_path.display().to_string())
    );
    let output =
        output_script_command_with_tty_delay(&shell_command, "", Duration::from_millis(250));

    assert!(
        output.status.success(),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let tty_output = String::from_utf8_lossy(&output.stdout);
    assert!(!tty_output.contains("condom blocked filesystem access"));
    assert!(!tty_output.contains("--message"));
    let prompt_output = fs::read_to_string(prompt_output).unwrap();
    assert!(prompt_output.contains("--request-json"));
    assert!(prompt_output.contains("condom blocked filesystem access"));
    let value = json_value_from_tty_output(&output);
    assert_eq!(value["type"], "filesystem-authorization");
    assert_eq!(value["decision"], "allow");
    assert_eq!(
        value["reason"],
        "allowed for app/project by filesystem prompt"
    );

    let list = command_with_state(&temp)
        .args(["allow", "--root"])
        .arg(temp.path())
        .args(["ls", "--json"])
        .output()
        .unwrap();
    assert!(
        list.status.success(),
        "{}",
        String::from_utf8_lossy(&list.stderr)
    );
    let approvals: serde_json::Value = serde_json::from_slice(&list.stdout).unwrap();
    assert_eq!(approvals.as_array().unwrap().len(), 1);
    assert_eq!(approvals[0]["kind"], "fs-write");
    assert_eq!(approvals[0]["subject"], "/opt/cache");
    assert_eq!(approvals[0]["scope"], "app-project");
    assert_eq!(approvals[0]["app"], "tool");

    let events = command_with_state(&temp)
        .args(["events", "--root"])
        .arg(temp.path())
        .arg("--json")
        .output()
        .unwrap();
    assert!(events.status.success());
    let value: serde_json::Value = serde_json::from_slice(&events.stdout).unwrap();
    assert!(value.as_array().unwrap().iter().any(|event| {
        event["eventType"] == "prompt"
            && event["subject"] == "/opt/cache"
            && event["decision"] == "accepted"
    }));
}

#[test]
fn approvals_round_trip_as_json() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let add = command_with_state(&temp)
        .args(["allow", "--root"])
        .arg(temp.path())
        .args([
            "add",
            "net-domain",
            "registry.example.test",
            "--scope",
            "project",
        ])
        .output()
        .unwrap();
    assert!(
        add.status.success(),
        "{}",
        String::from_utf8_lossy(&add.stderr)
    );

    let list = command_with_state(&temp)
        .args(["allow", "--root"])
        .arg(temp.path())
        .args(["ls", "--json"])
        .output()
        .unwrap();
    assert!(
        list.status.success(),
        "{}",
        String::from_utf8_lossy(&list.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&list.stdout).unwrap();
    assert_eq!(value.as_array().unwrap().len(), 1);
    assert_eq!(value[0]["subject"], "registry.example.test");
    assert_eq!(value[0]["scope"], "project");
}

#[test]
fn doctor_json_reports_missing_network_enforcement_setup() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let output = command_with_state(&temp)
        .args(["doctor", "--root"])
        .arg(temp.path())
        .arg("--json")
        .output()
        .unwrap();
    assert_eq!(
        output.status.code(),
        Some(1),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    let enforcement = value
        .as_array()
        .unwrap()
        .iter()
        .find(|check| check["name"] == "network-enforcement")
        .expect("missing network-enforcement doctor check");
    assert_eq!(enforcement["status"], "fail");
    assert!(enforcement["message"]
        .as_str()
        .unwrap()
        .contains("transparent proxy enforcement"));
    assert!(enforcement["message"]
        .as_str()
        .unwrap()
        .contains("unavailable"));
}

#[test]
fn doctor_json_reports_missing_filesystem_approval_prompt() {
    let temp = tempfile::tempdir().unwrap();
    let mut command = command_with_state(&temp);
    remove_prompt_environment(&mut command);

    let output = command
        .args(["doctor", "--root"])
        .arg(temp.path())
        .arg("--json")
        .output()
        .unwrap();
    assert_eq!(
        output.status.code(),
        Some(1),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    let prompt = value
        .as_array()
        .unwrap()
        .iter()
        .find(|check| check["name"] == "filesystem-approval-prompt")
        .expect("missing filesystem approval prompt doctor check");
    assert_eq!(prompt["status"], "fail");
    assert!(prompt["message"]
        .as_str()
        .unwrap()
        .contains("desktop display is not configured"));
    let gui = value
        .as_array()
        .unwrap()
        .iter()
        .find(|check| check["name"] == "filesystem-approval-gui")
        .expect("missing filesystem approval gui doctor check");
    assert_eq!(gui["status"], "warn");
    assert!(gui["message"]
        .as_str()
        .unwrap()
        .contains("terminal approval fallback is required"));
}

#[test]
fn doctor_text_exits_nonzero_on_failed_check() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let output = command_with_state(&temp)
        .args(["doctor", "--root"])
        .arg(temp.path())
        .output()
        .unwrap();
    assert_eq!(
        output.status.code(),
        Some(1),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("network-enforcement"));
    assert!(stdout.contains("Fail"));
}

#[test]
fn run_fails_before_direct_tcp_when_network_enforcement_is_missing() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let output = command_with_state(&temp)
        .args(["run", "--root"])
        .arg(temp.path())
        .args([
            "--",
            "curl",
            "--connect-timeout",
            "2",
            "--fail",
            "--silent",
            "--show-error",
            "--noproxy",
            "*",
            "--proxy",
            "",
            "http://127.0.0.1:1/package",
        ])
        .output()
        .unwrap();

    assert_network_enforcement_unavailable(&output);
    assert!(policy_snapshots(&temp).is_empty());
}

#[test]
fn doctor_json_reports_compatible_helper() {
    let temp = tempfile::tempdir().unwrap();
    let helper_capabilities = helper_probe_capability_names();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let output = command_with_state(&temp)
        .env_remove("CONDOM_INTERNAL_DISABLE_HELPER_REENTRY")
        .env("CONDOM_HELPER", helper_bin())
        .args(["doctor", "--root"])
        .arg(temp.path())
        .arg("--json")
        .output()
        .unwrap();
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(
        output.status.success(),
        !doctor_json_has_failed_check(&value),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let helper = value
        .as_array()
        .unwrap()
        .iter()
        .find(|check| check["name"] == "nixos-root-helper")
        .unwrap();
    assert_eq!(helper["status"], "pass");
    assert!(helper["message"]
        .as_str()
        .unwrap()
        .contains("compatible condom-helper"));
    let capabilities = value
        .as_array()
        .unwrap()
        .iter()
        .find(|check| check["name"] == "nixos-root-helper-capabilities")
        .unwrap();
    if has_required_helper_capabilities(&helper_capabilities) {
        assert_eq!(capabilities["status"], "pass");
        assert!(capabilities["message"]
            .as_str()
            .unwrap()
            .contains("advertises required supervisor capabilities"));
    } else {
        assert_eq!(capabilities["status"], "fail");
        let message = capabilities["message"].as_str().unwrap();
        assert!(message.contains("missing supervisor capabilities"));
        for capability in REQUIRED_HELPER_CAPABILITIES {
            if !helper_capabilities
                .iter()
                .any(|available| available == capability)
            {
                assert!(message.contains(capability));
            }
        }
    }
    let mediation = value
        .as_array()
        .unwrap()
        .iter()
        .find(|check| check["name"] == "filesystem-approval-mediation")
        .unwrap();
    assert_eq!(mediation["status"], "pass");
}

#[test]
fn doctor_json_reports_network_enforcement_when_helper_advertises_it() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let mut command = command_with_state(&temp);
    command.env_remove("CONDOM_INTERNAL_DISABLE_HELPER_REENTRY");
    command.env("CONDOM_HELPER", helper_bin());
    add_fake_tproxy_tools(&mut command, &temp);
    let output = command
        .args(["doctor", "--root"])
        .arg(temp.path())
        .arg("--json")
        .output()
        .unwrap();
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(
        output.status.success(),
        !doctor_json_has_failed_check(&value),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let enforcement = value
        .as_array()
        .unwrap()
        .iter()
        .find(|check| check["name"] == "network-enforcement")
        .expect("missing network-enforcement doctor check");
    assert_eq!(enforcement["status"], "pass");
    assert!(enforcement["message"]
        .as_str()
        .unwrap()
        .contains("transparent proxy enforcement is active"));
}

#[test]
fn doctor_json_reports_compatible_helper_socket() {
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());
    let socket = temp.path().join("helper.sock");
    let listener = UnixListener::bind(&socket).unwrap();
    listener.set_nonblocking(true).unwrap();
    let (auth_tx, auth_rx) = mpsc::channel();
    let (done_tx, done_rx) = mpsc::channel();
    let handle = thread::spawn(move || {
        let accept_request = |listener: &UnixListener, timeout: Duration| {
            let deadline = Instant::now() + timeout;
            loop {
                match listener.accept() {
                    Ok((mut stream, _addr)) => {
                        let mut request = String::new();
                        stream.read_to_string(&mut request).unwrap();
                        return Some((stream, request));
                    }
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        if Instant::now() >= deadline {
                            return None;
                        }
                        thread::sleep(Duration::from_millis(10));
                    }
                    Err(error) => panic!("failed to accept helper socket request: {error}"),
                }
            }
        };

        let (mut stream, request) = accept_request(&listener, Duration::from_secs(5))
            .expect("timed out waiting for helper socket probe request");
        assert!(request.contains(r#""type":"probe""#));
        write!(
            stream,
            "{}",
            serde_json::json!({
                "type": "ready",
                "protocolVersion": HELPER_PROTOCOL_VERSION,
                "helperVersion": "socket-test",
                "capabilities": []
            })
        )
        .unwrap();
        drop(stream);

        let mut saw_authorize = false;
        loop {
            match listener.accept() {
                Ok((mut stream, _addr)) => {
                    let mut request = String::new();
                    stream.read_to_string(&mut request).unwrap();
                    assert!(request.contains(r#""type":"authorize-filesystem""#));
                    saw_authorize = true;
                    write!(
                        stream,
                        "{}",
                        serde_json::json!({
                            "type": "filesystem-authorization",
                            "decision": "allow",
                            "reason": "doctor helper socket test approval",
                            "cacheable": true,
                            "suggestedAllow": null,
                            "cacheEntries": []
                        })
                    )
                    .unwrap();
                    drop(stream);
                }
                Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                    if done_rx.try_recv().is_ok() {
                        break;
                    }
                    thread::sleep(Duration::from_millis(10));
                }
                Err(error) => panic!("failed to accept helper socket request: {error}"),
            }
        }
        auth_tx.send(saw_authorize).unwrap();
    });

    let output = command_with_state(&temp)
        .env_remove("CONDOM_INTERNAL_DISABLE_HELPER_REENTRY")
        .env("CONDOM_HELPER_SOCKET", &socket)
        .args(["doctor", "--root"])
        .arg(temp.path())
        .arg("--json")
        .output()
        .unwrap();
    let _ = done_tx.send(());
    let saw_authorize = auth_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    handle.join().unwrap();
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(
        output.status.success(),
        !doctor_json_has_failed_check(&value),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let helper = value
        .as_array()
        .unwrap()
        .iter()
        .find(|check| check["name"] == "nixos-root-helper")
        .unwrap();
    assert_eq!(helper["status"], "pass");
    assert!(helper["message"]
        .as_str()
        .unwrap()
        .contains("compatible condom-helper socket-test"));
    let mediation = value
        .as_array()
        .unwrap()
        .iter()
        .find(|check| check["name"] == "filesystem-approval-mediation")
        .unwrap();
    assert!(saw_authorize);
    assert_eq!(mediation["status"], "pass");
}

#[test]
fn doctor_json_reports_configured_capture_backend() {
    require_fuse_device();
    let temp = tempfile::tempdir().unwrap();
    assert!(command_with_state(&temp)
        .args(["init", "--root"])
        .arg(temp.path())
        .output()
        .unwrap()
        .status
        .success());

    let fake_backend = temp.path().join("fuse-overlayfs");
    fs::write(&fake_backend, "#!/bin/sh\nexit 0\n").unwrap();
    let mut permissions = fs::metadata(&fake_backend).unwrap().permissions();
    permissions.set_mode(0o755);
    fs::set_permissions(&fake_backend, permissions).unwrap();

    let output = command_with_state(&temp)
        .env("CONDOM_FUSE_OVERLAYFS", &fake_backend)
        .args(["doctor", "--root"])
        .arg(temp.path())
        .arg("--json")
        .output()
        .unwrap();
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(
        output.status.success(),
        !doctor_json_has_failed_check(&value),
        "status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let capture = value
        .as_array()
        .unwrap()
        .iter()
        .find(|check| check["name"] == "capture-backend")
        .unwrap();
    assert_eq!(capture["status"], "pass");
    assert!(capture["message"]
        .as_str()
        .unwrap()
        .contains("review uses it for transparent captured writes"));
}
