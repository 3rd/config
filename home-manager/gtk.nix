{ pkgs, ... }:

{
  gtk = {
    enable = true;
    font.name = "DejaVuSans Nerd Font, 10";
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
