{ config, lib, pkgs, ... }:
let
  cfg = config.core.monitoring;
  auditPackage = config.security.auditd.package;
  watchPathsJson = builtins.toJSON cfg.paths.watch;
  homeWatchPathsJson = builtins.toJSON (builtins.filter (path: lib.hasPrefix "/home/" path) cfg.paths.watch);
  dbipCountryDbPath = pkgs.dbip-country-lite.mmdb;
  mmdblookupBin = lib.getExe pkgs.libmaxminddb;
  ausearchBin = lib.getExe' auditPackage "ausearch";

  logDir = "/var/log/core-monitoring";
  stateDir = "/var/lib/core-monitoring";
  statePath = "${stateDir}/state";
  monitoringTools = pkgs.callPackage ./tools.nix { };

  networkUsageExport = pkgs.writeShellApplication {
    name = "core-monitoring-network-usage-export";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      iproute2
      nethogs
    ];
    text = ''
      set -euo pipefail

      log_dir=${lib.escapeShellArg logDir}
      raw_file=$(mktemp)
      err_file=$(mktemp)
      iface_file=$(mktemp)
      out_file="$log_dir/network-usage-$(date +%Y%m%d).ndjson"
      anomaly_file="$log_dir/anomaly-$(date +%Y%m%d).ndjson"

      cleanup() {
        rm -f "$raw_file" "$err_file" "$iface_file"
      }
      trap cleanup EXIT

      mkdir -p "$log_dir"

      {
        ip route show default 2>/dev/null
        ip -6 route show default 2>/dev/null
      } \
        | awk '/ dev / { for (i = 1; i <= NF; i++) if ($i == "dev" && (i + 1) <= NF) print $(i + 1) }' \
        | sort -u >"$iface_file"

      if [[ ! -s "$iface_file" ]]; then
        ip -o link show up 2>/dev/null \
          | awk -F': ' '$2 != "lo" { print $2 }' \
          | cut -d'@' -f1 \
          | sort -u >"$iface_file"
      fi

      mapfile -t interfaces <"$iface_file"
      if (( ''${#interfaces[@]} == 0 )); then
        exit 0
      fi

      # keep the second refresh so we sample after the requested delay instead of the startup snapshot
      if ! nethogs -t -c 2 -d ${toString cfg.collectors.networkUsage.sampleSeconds} "''${interfaces[@]}" >"$raw_file" 2>"$err_file"; then
        if [[ -s "$err_file" ]]; then
          cat "$err_file" >&2
        fi
        if [[ ! -s "$raw_file" ]]; then
          exit 1
        fi
      fi

      if [[ ! -s "$raw_file" ]]; then
        exit 0
      fi

      ${lib.getExe monitoringTools} network-usage "$raw_file" "$out_file" "$anomaly_file" ${toString cfg.collectors.networkUsage.sampleSeconds} ${toString cfg.collectors.networkUsage.topN} ${toString cfg.thresholds.networkKibPerSecond}
    '';
  };

  mkCollectorService =
    {
      enable,
      unitName,
      description,
      script,
      intervalMinutes,
      onBootSec ? "2m",
      after ? [ ],
      wants ? [ ],
      scheduleFromCompletion ? false,
    }:
    lib.mkIf enable {
      systemd.services.${unitName} = {
        inherit description after wants;
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Group = "root";
        };
        script = lib.getExe script;
      };

      systemd.timers.${unitName} = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnActiveSec = onBootSec;
          OnBootSec = onBootSec;
          OnUnitActiveSec = lib.mkIf (!scheduleFromCompletion) "${toString intervalMinutes}m";
          OnUnitInactiveSec = lib.mkIf scheduleFromCompletion "${toString intervalMinutes}m";
          Persistent = true;
          Unit = "${unitName}.service";
        };
      };
    };
in
lib.mkIf cfg.enable (
  lib.mkMerge [
    {
      systemd.tmpfiles.rules = [
        "d ${logDir} 0750 root root 30d"
        "d ${stateDir} 0750 root root -"
        "d ${statePath} 0700 root root -"
      ];

      systemd.services.core-monitoring-audit-stream-exporter = lib.mkIf (
        cfg.collectors.auditFs.enable || cfg.collectors.auditExec.enable || cfg.collectors.auditNet.enable
      ) {
        description = "Export normalized audit events into Grafana-friendly logs";
        wantedBy = [ "multi-user.target" ];
        after = [ "auditd.service" ];
        wants = [ "auditd.service" ];
        serviceConfig = {
          Type = "simple";
          User = "root";
          Group = "root";
          Restart = "always";
          RestartSec = "2s";
          TimeoutStopSec = "15s";
          ExecStart = "${lib.getExe monitoringTools} audit-stream-exporter ${lib.escapeShellArg logDir} ${lib.escapeShellArg statePath} ${toString cfg.thresholds.writeBurst} ${toString cfg.thresholds.connectBurst} ${toString cfg.thresholds.newProcessLookbackDays} ${toString (cfg.collectors.auditFs.intervalMinutes * 60)} ${toString (cfg.collectors.auditExec.intervalMinutes * 60)} ${toString (cfg.collectors.auditNet.intervalMinutes * 60)}";
        };
        environment = {
          CORE_MONITORING_WATCH_PATHS_JSON = watchPathsJson;
          CORE_MONITORING_HOME_WATCH_PATHS_JSON = homeWatchPathsJson;
          CORE_MONITORING_MMDBLOOKUP_BIN = mmdblookupBin;
          CORE_MONITORING_COUNTRY_DB = dbipCountryDbPath;
          CORE_MONITORING_AUSEARCH_BIN = ausearchBin;
        };
      };
    }
    (mkCollectorService {
      enable = cfg.collectors.networkUsage.enable;
      unitName = "core-monitoring-network-usage-export";
      description = "Export per-process network usage into Grafana-friendly logs";
      script = networkUsageExport;
      intervalMinutes = cfg.collectors.networkUsage.intervalMinutes;
      after = [ "network.target" ];
      wants = [ "network.target" ];
    })
  ]
)
