{ config, pkgs, ... }:

let
  applicationBackground = config.colors.selection-background;
in
{
  imports = [ ../colors.nix ];

  dconf.settings."org/gnome/desktop/interface".toolkit-accessibility = true;

  gtk = {
    enable = true;
    colorScheme = "dark";
    font = {
      name = "DejaVu Sans";
      size = 9;
    };
    gtk3.extraCss = ''
      @define-color window_bg_color ${applicationBackground};
      @define-color view_bg_color ${applicationBackground};
      @define-color theme_bg_color ${applicationBackground};
      @define-color theme_base_color ${applicationBackground};
    '';
    gtk4 = {
      theme = config.gtk.theme;
      extraConfig."gtk-interface-color-scheme" = "dark";
      extraCss = ''
        @define-color window_bg_color ${applicationBackground};
        @define-color view_bg_color ${applicationBackground};
        @define-color theme_bg_color ${applicationBackground};
        @define-color theme_base_color ${applicationBackground};
      '';
    };
    iconTheme = {
      name = "Arc";
      package = pkgs.arc-icon-theme;
    };
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
  };
}
