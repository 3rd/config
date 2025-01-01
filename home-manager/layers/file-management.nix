{ pkgs, pkgs-stable, ... }:

{
  home.packages = with pkgs;
    [
      #
      ranger
    ] ++ [
      #
      pkgs-stable.yazi
      pkgs-stable.pcmanfm
    ];
}

