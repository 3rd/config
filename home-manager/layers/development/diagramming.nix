{ pkgs, ... }:

{
  home.packages = with pkgs; [
    plantuml
    d2
  ];
}
