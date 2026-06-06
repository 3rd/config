{ lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    #
    basedpyright
    conda
    uv
    (python314.withPackages (
      python-pkgs: with python-pkgs; [
        pandas
        requests
      ]
    ))
  ];
}
