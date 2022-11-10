{ config, pkgs, ... }:

{
  imports = [ ./eva.nix ];

  home.packages = with pkgs; [
    eva # https://github.com/nerdypepper/eva
    grex # https://github.com/pemistahl/grex
    htmlq # https://github.com/mgdm/htmlq
    macchina # https://github.com/macchina-cli/macchina
    monolith # https://github.com/y2z/monolith
    pastel # https://github.com/sharkdp/pastel
  ];
}
