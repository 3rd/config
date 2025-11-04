{ lib, pkgs, ... }:

{

  home.packages = with pkgs; [
    #
    conda
    uv
    (python3.withPackages (python-pkgs: with python-pkgs; [ pandas requests ]))
  ];

}

