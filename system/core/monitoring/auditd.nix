{ config, lib, ... }:
let
  cfg = config.core.monitoring;
  auditPackage = config.security.auditd.package;
  auditPluginNames = builtins.attrNames config.security.auditd.plugins;
  mkAuditRules = import ./lib/mk-audit-rules.nix { inherit lib; };
in lib.mkIf cfg.enable {
  security.audit = {
    enable = true;
    failureMode = "printk";
    backlogLimit = 65536;
    rateLimit = 0;
    rules = mkAuditRules {
      watchPaths = cfg.paths.watch;
      excludePaths = cfg.paths.exclude;
      enableFs = cfg.collectors.auditFs.enable;
      enableExec = cfg.audit.enableExec;
      enableConnect = cfg.audit.enableConnect;
      extraRules = cfg.audit.extraRules;
    };
  };

  security.auditd = {
    enable = true;
    settings = {
      log_format = "ENRICHED";
      write_logs = true;
      flush = "INCREMENTAL_ASYNC";
      freq = 100;
      name_format = "HOSTNAME";
      max_log_file = 64;
      max_log_file_action = "ROTATE";
      num_logs = cfg.retention.auditDays;
      # use absolute thresholds so large disks do not trip low-space warnings at normal utilization
      space_left = 2048;
      space_left_action = "SYSLOG";
      admin_space_left = 1024;
      admin_space_left_action = "SUSPEND";
      disk_full_action = "SUSPEND";
      disk_error_action = "SUSPEND";
    };

    # keep one lightweight dispatcher plugin active to avoid auditd's empty-dispatcher warning
    plugins = lib.mkForce {
      af_unix = {
        active = true;
        path = lib.getExe' auditPackage "audisp-af_unix";
        args = [
          "0640"
          "/run/audit/audispd_events"
          "string"
          (toString cfg.audit.dispatcherQueueDepth)
        ];
        format = "binary";
      };
    };
  };

  systemd.services.auditd.restartTriggers =
    [ config.environment.etc."audit/auditd.conf".source ]
    ++ map (
      pluginName: config.environment.etc."audit/plugins.d/${pluginName}.conf".source
    ) auditPluginNames;
}
