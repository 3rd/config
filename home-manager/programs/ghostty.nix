{ config, inputs, pkgs, pkgs-master, lib, ... }:

{
  imports = [ ../colors.nix ];

  programs.ghostty.enable = true;
  programs.ghostty.package = inputs.ghostty.packages.${pkgs.system}.default;
}

