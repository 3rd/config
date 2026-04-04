{ config, lib, pkgs, ... }:
let
  cfg = config.core.monitoring;
  host = config.networking.hostName;
  prometheusPort = cfg.ports.prometheus;
  exporterPort = 9109;
  monitoringTools = pkgs.callPackage ./tools.nix { };
in
lib.mkIf cfg.enable {
  services.prometheus = {
    enable = true;
    extraFlags = [ "--log.level=warn" ];
    listenAddress = "127.0.0.1";
    port = prometheusPort;
    retentionTime = "${toString cfg.retention.prometheusDays}d";
    globalConfig = {
      scrape_interval = "${toString cfg.collectors.processMetrics.sampleIntervalSeconds}s";
      scrape_timeout = "${toString cfg.collectors.processMetrics.sampleIntervalSeconds}s";
    };
    scrapeConfigs = [
      {
        job_name = "core-monitoring-process";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString exporterPort}" ];
            labels =
              {
                host = host;
                host_class = cfg.hostClass;
              }
              // cfg.labels;
          }
        ];
      }
    ];
  };

  systemd.services.core-monitoring-process-metrics-exporter = {
    description = "Export top process metrics for Prometheus";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      User = "root";
      Group = "root";
      Restart = "always";
      RestartSec = "2s";
      TimeoutStopSec = "5s";
      ExecStart = "${lib.getExe monitoringTools} process-metrics-exporter";
    };
    environment = {
      CORE_MONITORING_EXPORTER_PORT = toString exporterPort;
      CORE_MONITORING_SAMPLE_INTERVAL = toString cfg.collectors.processMetrics.sampleIntervalSeconds;
      CORE_MONITORING_TOP_N = toString cfg.collectors.processMetrics.topN;
    };
  };
}
