{
  programs.zathura = {
    enable = true;
    options = {
      adjust-open = "best-fit";
      pages-per-row = 1;
      scroll-page-aware = "true";
      smooth-scroll = "true";
      scroll-step = 50;
      guioptions = "";
      scroll-full-overlap = "0.01";
      selection-clipboard = "clipboard";

      recolor = "false";
      recolor-lightcolor = "#000000";
      recolor-darkcolor = "#E0E0E0";
      recolor-reverse-video = "true";
      recolor-keephue = "true";

      statusbar-fg = "#B0B0B0";
      statusbar-bg = "#202020";
      inputbar-bg = "#151515";
      inputbar-fg = "#FFFFFF";
      notification-error-bg = "#AC4142";
      notification-error-fg = "#151515";
      notification-warning-bg = "#AC4142";
      notification-warning-fg = "#151515";
      highlight-color = "#F4BF75";
      highlight-active-color = "#6A9FB5";
      completion-highlight-fg = "#151515";
      completion-highlight-bg = "#90A959";
      completion-bg = "#303030";
      completion-fg = "#E0E0E0";
      notification-bg = "#90A959";
      notification-fg = "#151515";
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

