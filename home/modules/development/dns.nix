{ config, pkgs, ... }:

{
  home.packages = with pkgs;
    [
      dogdns # https://github.com/ogham/dog
    ];

  programs.fish.shellAliases = { dns = "dog"; };
}
