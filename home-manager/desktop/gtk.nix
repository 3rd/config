{ config, pkgs, ... }:

{
  gtk = {
    enable = true;
    colorScheme = "dark";
    gtk4.theme = config.gtk.theme;
    iconTheme = {
      name = "Arc";
      package = pkgs.arc-icon-theme;
    };
    theme = {
      name = "Arc-Dark";
      package = pkgs.arc-theme;
    };
  };
}
