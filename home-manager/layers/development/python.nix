{ lib, pkgs, ... }:

{

  home.packages = with pkgs; [
    #
    conda
    uv
  ];

}

