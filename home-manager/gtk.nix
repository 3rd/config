{ config, pkgs, ... }:

{
  gtk = {
    enable = true;
    # font = {
    #   package = pkgs.open-sans;
    #   name = "Open Sans";
    #   size = 12;
    # };
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
