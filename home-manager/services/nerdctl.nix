{ config, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
  runtimeDir = "$XDG_RUNTIME_DIR";
  systemdRuntimeDir = "%t";
  containerdNamespace = "default";
  containerdAddress = "unix://${runtimeDir}/containerd/containerd.sock";
  buildkitAddress = "unix://${runtimeDir}/buildkit-${containerdNamespace}/buildkitd.sock";
  buildkitSystemdAddress = "unix://${systemdRuntimeDir}/buildkit-${containerdNamespace}/buildkitd.sock";
  xdgConfigHome = "${homeDir}/.config";
  xdgDataHome = "${homeDir}/.local/share";
  containerdRootlessConfig = ''
    version = 3
    disabled_plugins = ["io.containerd.nri.v1.nri"]
  '';
  containerdRootless = pkgs.writeShellApplication {
    name = "containerd-rootless";
    runtimeInputs = [
      pkgs.bash
      pkgs.containerd
      pkgs.coreutils
      pkgs.iproute2
      pkgs.iptables
      pkgs.rootlesskit
      pkgs.runc
      pkgs.slirp4netns
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      # nixos exposes the working setuid uid/gid mapping helpers via wrappers
      export PATH="/run/wrappers/bin:$PATH"

      if ! [ -w "$HOME" ]; then
        echo "HOME needs to be set and writable" >&2
        exit 1
      fi

      : "''${XDG_CONFIG_HOME:=${xdgConfigHome}}"
      : "''${XDG_DATA_HOME:=${xdgDataHome}}"
      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        echo "XDG_RUNTIME_DIR needs to be set for rootless containerd" >&2
        exit 1
      fi

      if ! [ -w "$XDG_RUNTIME_DIR" ]; then
        echo "XDG_RUNTIME_DIR needs to be writable for rootless containerd" >&2
        exit 1
      fi

      if [ -z "''${_CONTAINERD_ROOTLESS_CHILD:-}" ]; then
        exec rootlesskit \
          --state-dir="$XDG_RUNTIME_DIR/containerd-rootless" \
          --net=slirp4netns \
          --mtu=65520 \
          --slirp4netns-sandbox=auto \
          --slirp4netns-seccomp=auto \
          --disable-host-loopback \
          --port-driver=builtin \
          --copy-up=/etc \
          --copy-up=/run \
          --copy-up=/var/lib \
          --propagation=rslave \
          env _CONTAINERD_ROOTLESS_CHILD=1 "$0"
      fi

      rm -f /run/xtables.lock

      realpath_etc_ssl="$(realpath /etc/ssl)"
      rm -rf /etc/ssl
      mkdir -p /etc/ssl
      mount --rbind "$realpath_etc_ssl" /etc/ssl

      for mount_spec in \
        "$XDG_RUNTIME_DIR/containerd:/run/containerd" \
        "$XDG_DATA_HOME/containerd:/var/lib/containerd" \
        "$XDG_DATA_HOME/cni:/var/lib/cni" \
        "$XDG_CONFIG_HOME/containerd:/etc/containerd" \
        "$XDG_CONFIG_HOME/cni:/etc/cni"
      do
        mount_source="''${mount_spec%%:*}"
        mount_target="''${mount_spec#*:}"

        rm -rf "$mount_target"
        mkdir -p "$mount_source" "$mount_target"
        mount --bind "$mount_source" "$mount_target"
      done

      exec containerd
    '';
  };
  containerdNsenter = pkgs.writeShellApplication {
    name = "containerd-nsenter";
    runtimeInputs = [ pkgs.util-linux ];
    text = ''
      set -euo pipefail

      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        echo "XDG_RUNTIME_DIR needs to be set for containerd-nsenter" >&2
        exit 1
      fi

      pid=$(<"$XDG_RUNTIME_DIR/containerd-rootless/child_pid")
      exec nsenter \
        --no-fork \
        --preserve-credentials \
        --mount \
        --net \
        --user \
        --target "$pid" \
        -- "$@"
    '';
  };
in
{
  home.sessionVariables = {
    CONTAINERD_ADDRESS = containerdAddress;
    CONTAINERD_NAMESPACE = containerdNamespace;
    BUILDKIT_HOST = buildkitAddress;
  };

  xdg.configFile."containerd/config.toml".text = containerdRootlessConfig;

  systemd.user.services.containerd = {
    Unit = {
      Description = "containerd - container runtime (Rootless)";
      Wants = [ "buildkitd.service" ];
      ConditionUser = "!root";
      StartLimitBurst = 16;
      StartLimitIntervalSec = 120;
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "notify";
      Delegate = true;
      Restart = "always";
      RestartSec = 10;
      ExecStart = "${containerdRootless}/bin/containerd-rootless";
      ExecReload = "${pkgs.procps}/bin/kill -s HUP $MAINPID";
      StateDirectory = "containerd";
      RuntimeDirectory = "containerd";
      RuntimeDirectoryPreserve = true;
      KillMode = "process";
      NotifyAccess = "all";
      LimitNOFILE = "infinity";
      LimitNPROC = "infinity";
      LimitCORE = "infinity";
      TasksMax = "infinity";
      OOMScoreAdjust = -999;
    };
  };

  systemd.user.services.buildkitd = {
    Unit = {
      Description = "BuildKit (Rootless)";
      PartOf = [ "containerd.service" ];
      After = [ "containerd.service" ];
      Requires = [ "containerd.service" ];
    };
    Install.WantedBy = [ "containerd.service" ];
    Service = {
      Type = "simple";
      Restart = "always";
      RestartSec = 2;
      KillMode = "mixed";
      NotifyAccess = "all";
      StateDirectory = "buildkitd";
      RuntimeDirectory = "buildkitd";
      RuntimeDirectoryPreserve = true;
      ExecReload = "${pkgs.procps}/bin/kill -s HUP $MAINPID";
      ExecStart = ''
        ${containerdNsenter}/bin/containerd-nsenter \
          ${pkgs.buildkit}/bin/buildkitd \
          --oci-worker=false \
          --containerd-worker=true \
          --containerd-worker-rootless=true \
          --addr ${buildkitSystemdAddress} \
          --root ${xdgDataHome}/buildkit-${containerdNamespace} \
          --containerd-worker-namespace=${containerdNamespace} \
          --containerd-worker-net=host
      '';
    };
  };
}
