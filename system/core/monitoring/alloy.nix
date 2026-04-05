{ config, lib, ... }:
let
  cfg = config.core.monitoring;
  mkAlloyConfig = import ./lib/mk-alloy-config.nix { inherit lib; };
  host = config.networking.hostName;
in lib.mkIf cfg.enable {
  services.alloy = {
    enable = true;
    extraFlags = [
      "--server.http.listen-addr=127.0.0.1:${toString cfg.ports.alloyHttp}"
      "--storage.path=/var/lib/alloy"
      "--disable-reporting"
    ];
  };

  environment.etc."alloy/config.alloy".text = mkAlloyConfig {
    inherit cfg host;
    hostClass = cfg.hostClass;
  };

  systemd.services.alloy = {
    after = [
      "auditd.service"
      "loki.service"
    ];
    wants = [ "loki.service" ];
    reloadIfChanged = lib.mkForce false;
    reloadTriggers = lib.mkForce [ ];
    restartTriggers = [ config.environment.etc."alloy/config.alloy".source ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
      TimeoutStopSec = "15s";
      Nice = 10;
      IOSchedulingClass = "idle";
      IOSchedulingPriority = 7;
      CPUWeight = 10;
      IOWeight = 10;
    };
  };
}
