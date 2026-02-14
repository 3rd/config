{ lib, pkgs, ... }:

{
  imports = [
    ./workstation.nix
    ../modules/syncthing.private.nix
    ../modules/tailscale.private.nix
    ../modules/security.private.nix
  ];

  environment.systemPackages = with pkgs; [ ];

  services.avahi.enable = true;
}
