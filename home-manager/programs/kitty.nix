{
  config,
  pkgs,
  pkgs-master,
  lib,
  ...
}:

{
  imports = [ ../colors.nix ];

  home.sessionVariables.TERMINAL = "${pkgs.kitty}/bin/kitty";

  xdg.configFile."kitty/shaders/theme-stars.pipeline".text = ''
    var uint STAR_COLOR 0x${lib.removePrefix "#" config.colors.gray-lightest}
    var uint WARM_STAR_COLOR 0x${lib.removePrefix "#" config.colors.yellow-lightest}
    var uint COOL_STAR_COLOR 0x${lib.removePrefix "#" config.colors.blue-lightest}

    startgroup
        animation_stop never
        animation_step 33
        shaders theme-stars
    endgroup
  '';
  xdg.configFile."kitty/shaders/theme-stars.slang".text = ''
    #language slang 2026

    import kitty_custom_shader_types;

    static const uint STAR_COLOR = 0;
    static const uint WARM_STAR_COLOR = 0;
    static const uint COOL_STAR_COLOR = 0;
    static const uint DRIFT_PERIOD_SECONDS = 4096;
    static const float STAR_CELL_SIZE_PIXELS = 64.0;
    static const float2 STAR_VELOCITY_PIXELS_PER_SECOND = float2(2.0, 1.0);

    // PCG hash adapted from kitty's northern-lights shader, Copyright (C) 2026 Sami Farin, GPLv3.
    float3
    hashStarCell(uint2 cell) {
        uint3 state = uint3(cell.x * 0x5851F42Du + cell.y * 0x27D4EB2Fu + 0x9E3779B9u,
                            cell.y * 0x5851F42Du + cell.x * 0x165667B1u + 0x85EBCA6Bu,
                            cell.x * 0x27D4EB2Fu + cell.y * 0x165667B1u + 0xC2B2AE35u);
        state = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;

        return float3((state >> 22u) ^ state) / 4294967295.0;
    }

    float3
    toLinearRgb(uint color) {
        float3 srgb = float3((color >> 16) & 255, (color >> 8) & 255, color & 255) / 255.0;

        return lerp(srgb / 12.92, pow((srgb + 0.055) / 1.055, float3(2.4)), step(float3(0.04045), srgb));
    }

    float3
    toSrgbBytes(float3 color) {
        float3 srgb = lerp(color * 12.92, 1.055 * pow(color, float3(1.0 / 2.4)) - 0.055, step(float3(0.0031308), color));

        return round(saturate(srgb) * 255.0);
    }

    bool
    hasBackgroundColor(float3 color, float3 background) {
        return all(toSrgbBytes(color) == toSrgbBytes(background));
    }

    float4
    sampleStarLayer(float2 pixelPosition, float elapsedSeconds, uint layer) {
        float depth = float(layer + 1u);
        float2 fieldPosition = pixelPosition - STAR_VELOCITY_PIXELS_PER_SECOND * elapsedSeconds * depth;
        float2 cellPosition = floor(fieldPosition / STAR_CELL_SIZE_PIXELS);

        // The drift must cross a whole number of cells per period so wrapping the clock preserves the star pattern.
        float2 cellPeriod = STAR_VELOCITY_PIXELS_PER_SECOND * float(DRIFT_PERIOD_SECONDS) / STAR_CELL_SIZE_PIXELS;
        uint2 cell = uint2(cellPosition - floor(cellPosition / cellPeriod) * cellPeriod);
        cell += uint2(173u, 97u) * layer;
        float3 seed = hashStarCell(cell);
        if (seed.z < 0.45 + 0.35 * float(layer)) return float4(0.0);

        float3 appearance = hashStarCell(cell + uint2(97u, 173u));
        float2 starPosition = (0.2 + 0.6 * seed.xy) * STAR_CELL_SIZE_PIXELS;
        float2 localPosition = frac(fieldPosition / STAR_CELL_SIZE_PIXELS) * STAR_CELL_SIZE_PIXELS;
        float radius = lerp(0.45, 0.75, appearance.z) + 0.4 * float(layer);
        float starAmount = 1.0 - smoothstep(radius - 0.6, radius + 0.6, length(localPosition - starPosition));
        if (starAmount <= 0.0) return float4(0.0);

        float3 starColor = toLinearRgb(STAR_COLOR);
        if (appearance.x < 0.15) {
            starColor = lerp(starColor, toLinearRgb(WARM_STAR_COLOR), 0.45);
        } else if (appearance.x > 0.85) {
            starColor = lerp(starColor, toLinearRgb(COOL_STAR_COLOR), 0.4);
        }

        float phase = frac(elapsedSeconds / 8.0) * 6.2831853;
        float twinkle = 0.65 + 0.2 * sin(phase * (1.0 + floor(appearance.y * 3.0)) + seed.x * 6.2831853)
                             + 0.15 * sin(phase * 4.0 + seed.y * 6.2831853);
        float alpha = 0.55 * starAmount * twinkle * (0.65 + 0.3 * float(layer));

        return float4(starColor * alpha, alpha);
    }

    public float4
    fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
        float4 terminalColor = t.backbuffer.Sample(t.pos);
        if (!hasBackgroundColor(terminalColor.rgb, d.background.rgb)) return terminalColor;

        float2 pixelPosition = t.pos * float2(d.viewport_size_pixels);
        float elapsedSeconds = d.wrapped_time(DRIFT_PERIOD_SECONDS);
        float4 distantStars = sampleStarLayer(pixelPosition, elapsedSeconds, 0u);
        float4 nearbyStars = sampleStarLayer(pixelPosition, elapsedSeconds, 1u);
        float4 stars = nearbyStars + distantStars * (1.0 - nearbyStars.a);
        if (stars.a <= 0.0) return terminalColor;

        // Keep stars clear of antialiased glyph edges, which already contain the flat background color.
        float2 pixelSize = 1.0 / float2(d.viewport_size_pixels);
        for (int y = -2; y <= 2; y++) {
            for (int x = -2; x <= 2; x++) {
                float3 neighbor = t.backbuffer.Sample(t.pos + float2(x, y) * pixelSize).rgb;
                if (!hasBackgroundColor(neighbor, d.background.rgb)) return terminalColor;
            }
        }

        return float4(terminalColor.rgb * (1.0 - stars.a) + stars.rgb, terminalColor.a);
    }
  '';

  programs.kitty = {
    enable = true;
    package = pkgs.kitty;
    settings = with config.colors; {
      # general
      # workaround: kitty 0.47.1 recursively watches /nix/store on NixOS/Home Manager.
      auto_reload_config = "-1";
      clear_all_shortcuts = "yes";
      clipboard_control = "write-clipboard write-primary no-append";
      close_on_child_death = "yes";
      cursor_blink_interval = "0";
      cursor_shape = "beam";
      custom_shaders = "theme-stars cursor-trail-pixiedust";
      draw_minimal_borders = "yes";
      enable_audio_bell = "no";
      hide_window_decorations = "no";
      inactive_text_alpha = "1";
      input_delay = "0";
      kitty_mod = "ctrl+shift";
      momentum_scroll = "0";
      mouse_hide_wait = "-1";
      placement_strategy = "top-left";
      repaint_delay = "3";
      scrollback_lines = "100000";
      shell_integration = "no-cursor";
      sync_to_monitor = "yes";
      touch_scroll_multiplier = "2.0";
      tab_bar_edge = "bottom";
      tab_bar_style = "separator";
      tab_separator = "┇";
      tab_title_template = "{index}";
      visual_bell_duration = "0.2";
      wheel_scroll_multiplier = "5.0";
      window_alert_on_bell = "no";
      window_border_width = "0";
      window_margin_width = "0";
      window_padding_width = "0 0 0 0";

      cursor_trail = "5";
      cursor_trail_decay = "0.1 0.4";
      cursor_trail_start_threshold = "3";

      # https://github.com/kovidgoyal/kitty/issues/797
      confirm_os_window_close = "0";

      # background
      # background_opacity = "0.98";
      background_opacity = "1.0";
      # dynamic_background_opacity = "yes";
      dynamic_background_opacity = "no";
      # background_tint = "0.5";
      transparent_background_colors = "${background}@1.0 ${gray-darker}@1.0 ${gray-dark}@1.0 ${gray-darkish}@1.0 ${magenta-darkest}@1.0 ${red-darkest}@1.0 ${blue-darkest}@1.0 ${green-darkest}@1.0"; # max 8

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
      palette_generate = "legacy";

      # text rendering
      # https://github.com/kovidgoyal/kitty/issues/6209
      # https://github.com/kovidgoyal/kitty/pull/6218
      # text_composition_strategy = "legacy";
      # text_composition_strategy = "1 0"; # gamma, multiplicative contrast
      # text_composition_strategy = "1.0 8";
      text_composition_strategy = "1.0 2";
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

      font_family = lib.mkDefault "MonoLisa";
      # font_size = lib.mkDefault "9";
      # font_size = lib.mkDefault "9.4";
      font_size = lib.mkDefault "10.1";

      # font_family = lib.mkDefault "Berkeley Mono";
      # font_size = lib.mkDefault "9.4";
      # font_size = lib.mkDefault "9.9";
      # font_size = lib.mkDefault "10";
      # font_size = lib.mkDefault "9.9";
      # font_size = lib.mkDefault "10.4";
      # font_size = lib.mkDefault "10.5";
      # font_size = lib.mkDefault "10";

      # font_family = lib.mkDefault "Berkeley Mono Variable";
      # font_size = lib.mkDefault "9.9";

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
      "ctrl+shift+0" = "change_font_size all 9.1";
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
      # "shift+enter" = "send_text all \\x1b[13;2u";
    };
    extraConfig = ''
      mouse_map ctrl+shift+left release grabbed,ungrabbed mouse_click_url
      mouse_map left click ungrabbed mouse_click_url_or_select
      map shift+enter send_text all \x1b\r

      # <c-i>
      map ctrl+i send_text all \x1b[105;5u

      # https://www.monolisa.dev/faq#how-to-enable-stylistic-sets-for-the-kitty-terminal
      font_features MonoLisa-Regular +zero +ss04
      font_features MonoLisa-Bold +zero +ss04
      font_features MonoLisa-RegularItalic +zero
      font_features MonoLisa-BoldItalic +zero

      # berkeley
      # modify_font cell_width 100%
      # modify_font cell_height 116%
      # modify_font cell_width 102%
    '';
  };
}
