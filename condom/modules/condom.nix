{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.condom;
  tproxy = cfg.transparentProxy;
  condomBinary = if cfg.package != null then lib.getExe cfg.package else cfg.binaryPath;
  helperBinary =
    if cfg.package != null then lib.getExe' cfg.package "condom-helper" else cfg.helperBinaryPath;
  hasCondomBinary = condomBinary != null;
  hasHelperBinary = helperBinary != null;
  tcpPorts = lib.concatMapStringsSep ", " toString tproxy.tcpPorts;
  tcpPortsEnv = lib.concatMapStringsSep "," toString tproxy.tcpPorts;
  helperRuntimeCapabilities = [
    "CAP_CHOWN"
    "CAP_DAC_OVERRIDE"
    "CAP_SETGID"
    "CAP_SETUID"
    "CAP_NET_ADMIN"
  ];
in
{
  options.programs.condom = {
    enable = lib.mkEnableOption "condom wrapper";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Optional package that provides the condom and condom-helper binaries.";
    };

    installPackage = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install the configured condom package into systemPackages.";
    };

    binaryPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to an externally installed condom binary used when package is null.";
    };

    helperBinaryPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to an externally installed condom-helper binary used when package is null.";
    };

    installSandboxTools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install runtime sandbox tools used by condom run and review.";
    };

    helperGroup = lib.mkOption {
      type = lib.types.str;
      default = "condom";
      description = "Group intended to own access to the helper request socket.";
    };

    helperSocket = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable a systemd socket for condom-helper request activation when a helper binary is configured.";
      };

      path = lib.mkOption {
        type = lib.types.str;
        default = "/run/condom/helper.sock";
        description = "Unix socket path for systemd-activated condom-helper requests.";
      };
    };

    captureBackendPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.fuse-overlayfs;
      description = "Package that provides fuse-overlayfs for transparent review capture.";
    };

    transparentProxy = {
      proxyPort = lib.mkOption {
        type = lib.types.port;
        default = 15080;
        description = "Local transparent proxy listener port used by the TPROXY rules.";
      };

      mark = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 49374;
        description = "Firewall mark assigned to packets redirected to the transparent proxy.";
      };

      routingTable = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 15080;
        description = "Policy routing table used to deliver marked packets locally.";
      };

      rulePriority = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 15080;
        description = "Priority for the condom-owned policy routing rule.";
      };

      interceptInterface = lib.mkOption {
        type = lib.types.str;
        default = "lo";
        description = "Ingress interface where the TPROXY nftables rule is allowed to intercept packets.";
      };

      tableName = lib.mkOption {
        type = lib.types.str;
        default = "condom-tproxy";
        description = "nftables table name owned by condom transparent proxy routing.";
      };

      tcpPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [
          80
          443
        ];
        description = "TCP destination ports intercepted by the transparent proxy rules.";
      };

    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.installPackage || cfg.package != null;
        message = "programs.condom.installPackage requires programs.condom.package.";
      }
      {
        assertion = hasCondomBinary;
        message = "programs.condom requires programs.condom.package or programs.condom.binaryPath for the transparent runtime wrapper.";
      }
      {
        assertion = tproxy.tcpPorts != [ ];
        message = "programs.condom.transparentProxy.tcpPorts must not be empty.";
      }
    ];

    users.groups.${cfg.helperGroup} = { };

    boot.kernelModules = [
      "nft_socket"
      "nft_tproxy"
      "nf_tproxy_ipv4"
    ];

    environment.systemPackages =
      lib.optionals (cfg.installPackage && cfg.package != null) [ cfg.package ]
      ++ lib.optionals cfg.installSandboxTools [
        pkgs.bubblewrap
        pkgs.fence
      ]
      ++ lib.optionals (cfg.captureBackendPackage != null) [ cfg.captureBackendPackage ]
      ++ [
        pkgs.iproute2
        pkgs.nftables
      ];

    environment.sessionVariables = {
      CONDOM_TPROXY_ROUTING = "1";
      CONDOM_TPROXY_PORT = toString tproxy.proxyPort;
      CONDOM_TPROXY_MARK = toString tproxy.mark;
      CONDOM_TPROXY_TABLE = toString tproxy.routingTable;
      CONDOM_TPROXY_TABLE_NAME = tproxy.tableName;
      CONDOM_TPROXY_INTERFACE = tproxy.interceptInterface;
      CONDOM_TPROXY_TCP_PORTS = tcpPortsEnv;
    };

    security.wrappers."condom-tproxy" = lib.mkIf hasCondomBinary {
      owner = "root";
      group = cfg.helperGroup;
      capabilities = "cap_net_admin+ep";
      source = condomBinary;
    };

    networking.nftables.enable = true;

    networking.nftables.tables = {
      ${tproxy.tableName} = {
        family = "ip";
        content = ''
          chain divert {
            type filter hook prerouting priority -150; policy accept;
            iifname "${tproxy.interceptInterface}" meta l4proto tcp socket transparent 1 meta mark set ${toString tproxy.mark} accept
            iifname "${tproxy.interceptInterface}" tcp dport { ${tcpPorts} } tproxy to :${toString tproxy.proxyPort} meta mark set ${toString tproxy.mark} accept
          }
        '';
      };
    };

    systemd.services.condom = {
      description = "Condom runtime enforcement";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "nftables.service"
      ]
      ++ lib.optionals (cfg.helperSocket.enable && hasHelperBinary) [ "condom-helper.socket" ];
      after = [
        "network-pre.target"
        "nftables.service"
      ];
      before = lib.optionals (cfg.helperSocket.enable && hasHelperBinary) [ "condom-helper.socket" ];
      path = [ pkgs.iproute2 ];
      script = ''
        while ip rule del pref ${toString tproxy.rulePriority} fwmark ${toString tproxy.mark} table ${toString tproxy.routingTable} 2>/dev/null; do :; done
        ip rule add pref ${toString tproxy.rulePriority} fwmark ${toString tproxy.mark} table ${toString tproxy.routingTable}
        ip route replace local 0.0.0.0/0 dev lo table ${toString tproxy.routingTable}
      '';
      preStop = ''
        while ip rule del pref ${toString tproxy.rulePriority} fwmark ${toString tproxy.mark} table ${toString tproxy.routingTable} 2>/dev/null; do :; done
        ip route del local 0.0.0.0/0 dev lo table ${toString tproxy.routingTable} 2>/dev/null || true
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
        AmbientCapabilities = [ "CAP_NET_ADMIN" ];
      };
    };

    systemd.sockets.condom-helper = lib.mkIf (cfg.helperSocket.enable && hasHelperBinary) {
      partOf = [ "condom.service" ];
      socketConfig = {
        ListenStream = cfg.helperSocket.path;
        Accept = true;
        SocketUser = "root";
        SocketGroup = cfg.helperGroup;
        SocketMode = "0660";
        DirectoryMode = "0755";
        RemoveOnStop = true;
      };
    };

    systemd.services."condom-helper@" = lib.mkIf (cfg.helperSocket.enable && hasHelperBinary) {
      description = "Condom helper request";
      requires = [ "condom.service" ];
      after = [ "condom.service" ];
      partOf = [ "condom.service" ];
      path =
        lib.optionals cfg.installSandboxTools [
          pkgs.bubblewrap
          pkgs.fence
        ]
        ++ lib.optionals (cfg.captureBackendPackage != null) [ cfg.captureBackendPackage ]
        ++ [
          pkgs.iproute2
          pkgs.nftables
        ];
      serviceConfig = {
        Type = "exec";
        ExecStart = "${helperBinary} socket-request";
        Environment = [
          "CONDOM_TPROXY_ROUTING=1"
          "CONDOM_TPROXY_PORT=${toString tproxy.proxyPort}"
          "CONDOM_TPROXY_MARK=${toString tproxy.mark}"
          "CONDOM_TPROXY_TABLE=${toString tproxy.routingTable}"
          "CONDOM_TPROXY_TABLE_NAME=${tproxy.tableName}"
          "CONDOM_TPROXY_INTERFACE=${tproxy.interceptInterface}"
          "CONDOM_TPROXY_TCP_PORTS=${tcpPortsEnv}"
        ];
        StandardInput = "socket";
        StandardOutput = "socket";
        User = "root";
        Group = cfg.helperGroup;
        CapabilityBoundingSet = helperRuntimeCapabilities;
        Restart = "no";
        TimeoutStartSec = "30s";
        TimeoutStopSec = "10s";
        KillMode = "mixed";
        UMask = "0007";
        NoNewPrivileges = false;
        LockPersonality = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
      };
    };
  };
}
