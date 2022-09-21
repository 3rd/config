{ config, pkgs, ... }:
let stable = import <nixos-stable> { };
in
{
  imports = [ ./options/colors.nix ];
  programs.zathura = with config.colors; {
    enable = true;
    package = stable.zathura;
    options = {
      # settings
      adjust-open = "best-fit";
      page-padding = 1;
      pages-per-row = 1;
      render-loading = false;
      sandbox = "none";
      scroll-full-overlap = "1.0e-2";
      scroll-page-aware = true;
      scroll-step = 100;
      selection-clipboard = "clipboard";
      statusbar-h-padding = 0;
      statusbar-v-padding = 0;
      window-title-basename = true;
      # colors
      default-bg = "#${background}";
      default-fg = "#${foreground}";
      recolor-darkcolor = "#${background}";
      recolor-lightcolor = "#${foreground}";
      statusbar-bg = "#${color0}";
      statusbar-fg = "#${color15}";
      completion-bg = "#${color8}";
      completion-fg = "#${color15}";
      completion-highlight-bg = "#${color15}";
      completion-highlight-fg = "#${color7}";
      highlight-active-color = "#${color5}";
      highlight-color = "#${color11}";
      inputbar-bg = "#${color8}";
      inputbar-fg = "#${foreground}";
      notification-bg = "#${color4}";
      notification-fg = "#${foreground}";
      notification-error-bg = "#${color1}";
      notification-error-fg = "#${foreground}";
      notification-warning-bg = "#${color3}";
      notification-warning-fg = "#${foreground}";
    };
    extraConfig = ''
      map r reload
      map f toggle_fullscreen
      map d scroll full-down
      map u scroll full-up
      map D toggle_page_mode
      map R rotate
      map + zoom in
      map - zoom out
      map i recolor
      map p print
      map q quit
    '';
  };
}
