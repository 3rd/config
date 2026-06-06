{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nil
    statix
    nixfmt
  ];
}
