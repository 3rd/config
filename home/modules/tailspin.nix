{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ tailspin ];

  # programs.fish.shellAliases = { tail = "spin"; };
}

