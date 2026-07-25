{ config, pkgs, ... }:

{
  dconf.settings."org/gnome/desktop/interface".toolkit-accessibility = true;

  gtk = {
    enable = true;
    colorScheme = "dark";
    font = {
      name = "DejaVu Sans";
      size = 9;
    };
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
