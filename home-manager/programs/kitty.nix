{ config, pkgs, pkgs-master, lib, ... }:

{
  imports = [ ../colors.nix ];

  home.sessionVariables.TERMINAL = "${pkgs-master.kitty}/bin/kitty";

  programs.kitty = {
    enable = true;
    package = pkgs-master.kitty;
    settings = with config.colors; {
      # general
      clear_all_shortcuts = "yes";
      clipboard_control = "write-clipboard write-primary no-append";
      close_on_child_death = "yes";
      cursor_blink_interval = "0";
      cursor_shape = "block";
      draw_minimal_borders = "yes";
      enable_audio_bell = "no";
      hide_window_decorations = "no";
      inactive_text_alpha = "1";
      input_delay = "0";
      kitty_mod = "ctrl+shift";
      mouse_hide_wait = "-1";
      placement_strategy = "top-left";
      repaint_delay = "3";
      scrollback_lines = "100000";
      shell_integration = "no-cursor";
      sync_to_monitor = "no";
      tab_bar_edge = "bottom";
      tab_bar_style = "separator";
      tab_separator = "┇";
      tab_title_template = "{index}";
      visual_bell_duration = "0.2";
      window_alert_on_bell = "no";
      window_border_width = "0";
      window_margin_width = "0";
      window_padding_width = "0 0 0 0";

      cursor_trail = "5";
      cursor_trail_decay = "0.1 0.4";
      cursor_trail_start_threshold = "3";

      # stupid https://github.com/kovidgoyal/kitty/issues/797
      confirm_os_window_close = "0";

      # background
      background_opacity = "0.98";
      dynamic_background_opacity = "yes";

      # theme
      cursor_text_color = "background";
      selection_background = selection-background;
      selection_foreground = selection-foreground;
      inherit background;
      inherit foreground;
      inherit cursor;
      inherit color0;
      inherit color1;
      inherit color2;
      inherit color3;
      inherit color4;
      inherit color5;
      inherit color6;
      inherit color7;
      inherit color8;
      inherit color9;
      inherit color10;
      inherit color11;
      inherit color12;
      inherit color13;
      inherit color14;
      inherit color15;

      # text rendering
      # https://github.com/kovidgoyal/kitty/issues/6209
      # https://github.com/kovidgoyal/kitty/pull/6218
      # text_composition_strategy = "legacy";
      text_composition_strategy = "1 0"; # gamma, multiplicative contrast
      disable_ligatures = "cursor";
      undercurl_style = "thin-sparse";
      # adjust_line_height = "100%";

      # fonts

      # font_family = lib.mkDefault "Bmono";
      # font_family = lib.mkDefault "Input Mono";
      # font_family = lib.mkDefault "Victor Mono"; # thin
      # font_family = lib.mkDefault "Hasklig"; # super pretty
      # font_family = lib.mkDefault "Atkinson Hyperlegible";

      # font_family = lib.mkDefault "Comic Code Ligatures";
      # font_size = lib.mkDefault "10.5";

      # font_family = lib.mkDefault "MonoLisa";
      # font_size = lib.mkDefault "9";
      # font_size = lib.mkDefault "9.4";

      font_family = lib.mkDefault "Berkeley Mono";
      # font_size = lib.mkDefault "9.4";
      font_size = lib.mkDefault "9.6";
      # font_size = lib.mkDefault "9.9";
      # font_size = lib.mkDefault "10.4";
      # font_size = lib.mkDefault "10.5";
      # font_size = lib.mkDefault "10";

      # font_family = lib.mkDefault "Maple Mono";
      # font_size = lib.mkDefault "8.7";
      # font_size = lib.mkDefault "10.3";

      # font_family = lib.mkDefault "Monaspace Neon";
      # font_size = lib.mkDefault "9.9";
    };
    keybindings = {
      "kitty_mod+c" = "copy_to_clipboard";
      "kitty_mod+v" = "paste_from_clipboard";
      "kitty_mod+t" = "new_tab";
      "kitty_mod+w" = "close_tab";
      "kitty_mod+o" = "move_tab_forward";
      "kitty_mod+i" = "move_tab_backward";
      "ctrl+1" = "goto_tab 1";
      "ctrl+2" = "goto_tab 2";
      "ctrl+3" = "goto_tab 3";
      "ctrl+4" = "goto_tab 4";
      "ctrl+5" = "goto_tab 5";
      "ctrl+6" = "goto_tab 6";
      "ctrl+7" = "goto_tab 7";
      # change font size
      "ctrl+shift+0" = "change_font_size all 8.6";
      "ctrl+shift+minus" = "change_font_size all -0.1";
      "ctrl+shift+equal" = "change_font_size all +0.1";
      "ctrl+shift+backspace" = "change_font_size all 0";
      # change opacity
      "ctrl+shift+[" = "set_background_opacity -0.01";
      "ctrl+shift+]" = "set_background_opacity +0.01";
      "ctrl+shift+\\" = "set_background_opacity 0.95";
      # "ctrl+i" = "send_text all \\x1b[105;5u"; # CSI u
      "ctrl+shift+h" = "send_text all \\x1b[72;6u";
      "ctrl+shift+j" = "send_text all \\x1b[74;6u";
      "ctrl+shift+k" = "send_text all \\x1b[75;6u";
      "ctrl+shift+l" = "send_text all \\x1b[76;6u";
      "ctrl+shift+p" = "send_text all \\x1b[80;6u";
      "ctrl+," = "send_text all \\x1b[44;5u";
      "ctrl+." = "send_text all \\x1b[46;5u";
      "ctrl+;" = "send_text all \\x1b[59;5u";
      "shift+enter" = "send_text all \\x1b[13;2u";
    };
    extraConfig = ''
      mouse_map ctrl+shift+left release grabbed,ungrabbed mouse_click_url
      mouse_map left click ungrabbed mouse_click_url_or_select

      # <c-i>
      map ctrl+i send_text all \x1b[105;5u

      # https://www.monolisa.dev/faq#how-to-enable-stylistic-sets-for-the-kitty-terminal
      font_features MonoLisa-Medium +zero +ss04 +ss07 +ss08 +ss09
      font_features MonoLisa-MediumItalic +zero +ss04 +ss07 +ss08 +ss09

      # berkeley
      modify_font cell_width 100%
    '';
  };
}

