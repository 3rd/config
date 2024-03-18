{ pkgs, ... }:

{
  home.packages = with pkgs; [
    #
    yazi
    ranger
    pcmanfm
  ];
}

