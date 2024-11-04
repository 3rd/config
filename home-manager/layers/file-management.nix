{ pkgs, pkgs-stable, ... }:

{
  home.packages = with pkgs;
    [
      #
      ranger
      pcmanfm
    ] ++ [
      #
      pkgs-stable.yazi
    ];
}

