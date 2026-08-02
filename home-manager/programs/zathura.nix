{ config, ... }:

{
  imports = [ ../colors.nix ];

  programs.zathura = {
    enable = true;
    options = with config.colors; {
      adjust-open = "best-fit";
      pages-per-row = 1;
      scroll-page-aware = "true";
      smooth-scroll = "true";
      scroll-step = 50;
      guioptions = "";
      scroll-full-overlap = "0.01";
      selection-clipboard = "clipboard";

      recolor = "false";
      recolor-lightcolor = background;
      recolor-darkcolor = foreground;
      recolor-reverse-video = "true";
      recolor-keephue = "true";

      statusbar-fg = gray-light;
      statusbar-bg = gray-darkest;
      inputbar-bg = gray-darker;
      inputbar-fg = foreground;
      notification-error-bg = red-darkest;
      notification-error-fg = red-lightest;
      notification-warning-bg = yellow-darkest;
      notification-warning-fg = yellow-lightest;
      highlight-color = yellow-light;
      highlight-active-color = blue-light;
      completion-highlight-fg = selection-foreground;
      completion-highlight-bg = gray-darkish;
      completion-bg = gray-darker;
      completion-fg = foreground;
      notification-bg = green-darkest;
      notification-fg = green-lightest;
    };
    mappings = {
      d = "scroll half-down";
      "[fullscreen] d" = "scroll half-down";
      s = "scroll half-up";
      "[fullscreen] s" = "scroll half-up";
      u = "scroll half-up";
      "[fullscreen] u" = "scroll half-up";
      f = "toggle_fullscreen";
      "[fullscreen] f" = "toggle_fullscreen";
      r = "rotate";
      R = "reload";
      i = "recolor";
      D = "toggle_page_mode";
    };
    extraConfig = "";
  };
}
