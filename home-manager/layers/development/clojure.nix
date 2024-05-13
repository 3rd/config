{ lib, pkgs, ... }:

{

  home.packages = with pkgs;
    [
      #
      babashka
    ];

}

