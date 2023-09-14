# https://github.com/mitchellh/zig-overlay

# https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/editors/neovim/utils.nix#L27
{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url = "https://github.com/mitchellh/zig-overlay/archive/master.tar.gz";
    }))
  ];
  environment.systemPackages = with pkgs; [ zig ];
}
