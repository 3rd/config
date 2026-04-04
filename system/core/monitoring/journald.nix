{ config, lib, ... }:
let
  cfg = config.core.monitoring;
  retention = "${toString cfg.retention.journalDays}day";
in lib.mkIf cfg.enable {
  services.journald = {
    storage = "persistent";
    audit = "keep";
    extraConfig = ''
      SystemMaxUse=${cfg.retention.journalPersistentMaxUse}
      RuntimeMaxUse=${cfg.retention.journalRuntimeMaxUse}
      SystemKeepFree=1G
      MaxRetentionSec=${retention}
    '';
  };
}
