{ pkgs, ... }:

{
  home.packages = with pkgs; [
    #
    tdesktop
    armcord
    ferdium
  ];
}
