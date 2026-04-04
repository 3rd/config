{ config, lib, pkgs, ... }:
let
  cfg = config.core.monitoring;
in lib.mkIf cfg.enable {
  environment.systemPackages = with pkgs; [
    bcc
    bpftrace
    geoip
    geoipWithDatabase
    jq
    nethogs
    ripgrep
  ];
}
