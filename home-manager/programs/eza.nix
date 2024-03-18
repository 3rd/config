{ config, lib, pkgs, ... }:

{
  programs.eza = {
    enable = true;
    enableFishIntegration = false;
    enableNushellIntegration = false;
  };

  programs.fish.shellAliases = {
    l = "eza -l --group-directories-first";
    la = "eza -alBhg --group-directories-first --time-style long-iso";
    tree = "eza --tree --icons";
  };
}
