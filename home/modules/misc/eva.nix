{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ eva ];

  programs.fish.shellAliases = { calc = "eva"; };
}
