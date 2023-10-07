{ pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    font = "Fira 14";
    location = "center";
    theme = "Arc-Dark";
    package = with pkgs;
      rofi.override { plugins = [ rofi-calc rofi-file-browser ]; };
  };
}
