{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.xfce4-notifyd ];
  systemd.packages = [ pkgs.xfce4-notifyd ];
}
