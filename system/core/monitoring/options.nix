{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption;
  types = lib.types;
in {
  options.core.monitoring = {
    enable = mkEnableOption "continuous host monitoring and local forensics tooling";

    ui.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to run the local Grafana UI for browsing logs.";
    };

    labels = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        host = "example-host";
        environment = "desktop";
      };
      description = "Extra stream labels added to forwarded logs.";
    };

    hostClass = mkOption {
      type = types.str;
      default = "host";
      example = "battlestation";
      description = "A stable class label attached to monitoring streams.";
    };

    paths = {
      watch = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "/etc"
          "/home/example-user/projects"
          "/home/example-user/.config"
        ];
        description = ''
          Absolute directory paths to audit for writes and attribute changes.
          Keep this list focused; broad parent directories can create a lot of noise.
        '';
      };

      exclude = mkOption {
        type = types.listOf types.str;
        default = [
          "/nix/store"
          "/tmp"
          "/run"
          "/proc"
          "/sys"
          "/dev"
          "/var/lib/docker"
          "/var/lib/containers"
          "/var/lib/libvirt"
        ];
        description = ''
          Absolute directory paths to exclude from broad write auditing.
          These are emitted as higher-priority audit exclusion rules.
          Normal-user home cache directories are appended automatically.
        '';
      };
    };

    retention = {
      journalDays = mkOption {
        type = types.ints.positive;
        default = 14;
        description = "Maximum hot retention for journald, in days.";
      };

      journalPersistentMaxUse = mkOption {
        type = types.str;
        default = "1G";
        description = "Upper size bound for persistent journal storage.";
      };

      journalRuntimeMaxUse = mkOption {
        type = types.str;
        default = "256M";
        description = "Upper size bound for runtime journal storage.";
      };

      auditDays = mkOption {
        type = types.ints.positive;
        default = 30;
        description = ''
          Approximate audit retention expressed as the number of rotated audit log files to keep.
        '';
      };

      lokiDays = mkOption {
        type = types.ints.positive;
        default = 14;
        description = "Loki retention window, in days.";
      };

      prometheusDays = mkOption {
        type = types.ints.positive;
        default = 14;
        description = "Prometheus retention window, in days.";
      };
    };

    ports = {
      grafana = mkOption {
        type = types.port;
        default = 12210;
        description = "Loopback HTTP port for Grafana.";
      };

      loki = mkOption {
        type = types.port;
        default = 12211;
        description = "Loopback HTTP port for Loki.";
      };

      prometheus = mkOption {
        type = types.port;
        default = 12212;
        description = "Loopback HTTP port for Prometheus.";
      };

      alloyHttp = mkOption {
        type = types.port;
        default = 12213;
        description = "Loopback debug/UI port for Alloy.";
      };
    };

    audit = {
      enableExec = mkOption {
        type = types.bool;
        default = true;
        description = "Capture execve and execveat audit events.";
      };

      enableConnect = mkOption {
        type = types.bool;
        default = true;
        description = "Capture outbound connect syscall audit events.";
      };

      extraRules = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "-a always,exit -F arch=b64 -S bind -k net_bind" ];
        description = "Extra raw audit rules appended after the generated rules.";
      };

      dispatcherQueueDepth = mkOption {
        type = types.ints.positive;
        default = 16384;
        description = ''
          Queue depth passed to audisp-af_unix for the live audit dispatcher socket.
          Raise this on noisy hosts so short audit bursts do not overflow the socket queue.
        '';
      };

      streamChannelCapacity = mkOption {
        type = types.ints.positive;
        default = 16384;
        description = ''
          In-process channel capacity for buffering live audit events before normalization.
          Raise this on noisy hosts so the exporter can absorb short bursts without dropping events.
        '';
      };
    };

    thresholds = {
      cpuPct = mkOption {
        type = types.ints.positive;
        default = 80;
        description = "Emit a cpu anomaly when a sampled process exceeds this CPU percentage.";
      };

      networkKibPerSecond = mkOption {
        type = types.ints.positive;
        default = 1024;
        description = "Emit a network anomaly when a sampled process exceeds this many KiB/s.";
      };

      connectBurst = mkOption {
        type = types.ints.positive;
        default = 50;
        description = "Emit a network anomaly when a process exceeds this many connect events in one export window.";
      };

      writeBurst = mkOption {
        type = types.ints.positive;
        default = 50;
        description = "Emit a filesystem anomaly when a process exceeds this many file events in one export window.";
      };

      newProcessLookbackDays = mkOption {
        type = types.ints.positive;
        default = 7;
        description = "How long to remember previously-seen executables for new-process anomalies.";
      };
    };

    collectors = {
      processMetrics = {
        sampleIntervalSeconds = mkOption {
          type = types.ints.positive;
          default = 15;
          description = "How often to sample per-process CPU, memory, and disk metrics for Prometheus.";
        };

        topN = mkOption {
          type = types.ints.positive;
          default = 5;
          description = "How many top processes to expose per process-metric dimension.";
        };
      };

      auditFs = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Normalize audit filesystem events into Grafana-friendly records.";
        };

        intervalMinutes = mkOption {
          type = types.ints.positive;
          default = 1;
          description = "How often to export normalized filesystem audit events.";
        };
      };

      auditExec = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Normalize exec audit events into Grafana-friendly records.";
        };

        intervalMinutes = mkOption {
          type = types.ints.positive;
          default = 1;
          description = "How often to export normalized exec audit events.";
        };
      };

      auditNet = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Normalize outbound connect audit events into Grafana-friendly records.";
        };

        intervalMinutes = mkOption {
          type = types.ints.positive;
          default = 1;
          description = "How often to export normalized network audit events.";
        };
      };

      networkUsage = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Sample per-process network rates into Grafana-friendly records.";
        };

        sampleSeconds = mkOption {
          type = types.ints.positive;
          default = 10;
          description = "How long to sample nethogs for each network-usage export.";
        };

        intervalMinutes = mkOption {
          type = types.ints.positive;
          default = 1;
          description = "How often to export per-process network usage samples.";
        };

        topN = mkOption {
          type = types.ints.positive;
          default = 10;
          description = "How many top network processes to keep per network-usage export.";
        };
      };
    };
  };
}
