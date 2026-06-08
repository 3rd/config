{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zls
  ];
}
