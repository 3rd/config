{ config, lib, ... }:
let
  cfg = config.core.monitoring;
  dataDir = "/var/lib/core-monitoring/loki";
  mkLokiConfig = import ./lib/mk-loki-config.nix;
in lib.mkIf cfg.enable {
  services.loki = {
    enable = true;
    dataDir = dataDir;
    extraFlags = [ "-log.level=warn" ];
    configuration = mkLokiConfig {
      inherit cfg dataDir;
    };
  };

  systemd.services.loki.serviceConfig = {
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
    TimeoutStopSec = "15s";
    Nice = 10;
    IOSchedulingClass = "idle";
    IOSchedulingPriority = 7;
    CPUWeight = 10;
    IOWeight = 10;
  };
}
