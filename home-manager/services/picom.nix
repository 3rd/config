{ pkgs, lib, config, ... }:

# https://picom.app/#_animations
# https://github.com/Sanatana-Linux/nixos-config/blob/main/home/shared/services/picom.nix
# https://forum.maboxlinux.org/t/picom-with-animations-config-for-mabox-try-it/2121/4
# https://www-gem.codeberg.page/picom/
# https://nuxsh.is-a.dev/blog/picom.html
# https://www.reddit.com/r/unixporn/comments/1kntk5b/oc_completely_custom_opening_and_closing/
# https://github.com/ikz87/GLWall
# https://github.com/ikz87/dots-2.0?tab=readme-ov-file
# https://github.com/ikz87/picom-shaders/tree/main/Animations

{
  services.picom = {
    enable = true;
    package = pkgs.picom-next;
    backend = lib.mkDefault "glx";
    vSync = false;
    settings = {
      glx-no-stencil = true;
      glx-no-rebind-pixmap = true;

      shadow-radius = 12;
      shadow-offset-x = -12;
      shadow-offset-y = -12;
      shadow-color = "#000000";
      no-fading-openclose = false;
      no-fading-destroyed-argb = true;
      frame-opacity = 1;
      inactive-opacity-override = false;
      inactive-dim = 0.0;

      focus-exclude = [
        #
        "class_g ?= 'rofi'"
        "class_g ?= 'slop'"
        "class_g ?= 'Steam'"
      ];

      blur = {
        method = "dual_kawase";
        strength = 5.0;
        deviation = 1.0;
        kernel = "11x11gaussian";
      };

      blur-background = false;
      blur-background-frame = true;
      blur-background-fixed = true;

      blur-background-exclude = [
        "class_g = 'slop'"
        "class_g = 'Firefox' && argb"
        "name = 'rofi - Global Search'"
        "_GTK_FRAME_EXTENTS@:c"
      ];

      use-damage = false;
      transparent-clipping = false;

      window-shader-fg = "default";

      # fade = true;
      # fadeSteps = [ 0.1 0.1 ];
      # fadeDelta = 10;
      # animations = [
      #   {
      #     triggers = [ "open" "show" ];
      #
      #     preset = "appear";
      #     duration = "1";
      #   }
      #   {
      #     triggers = [ "close" "hide" ];
      #
      #     preset = "disappear";
      #     duration = "1";
      #   }
      #   {
      #     triggers = [ "geometry" ];
      #     preset = "geometry-change";
      #     duration = "1";
      #   }
      # ];

      fading = true;
      fade-in-step = 0.1;
      fade-out-step = 0.1;
      fade-delta = 1;

      corner-radius = lib.mkDefault 8;
      rounded-corners-exclude = [
        "class_g = 'Polybar'"
        "window_type = 'dock'"
        "window_type = 'tooltip'"
      ];
      round-borders = lib.mkDefault 8;
      round-borders-exclude = [ ];

      log-level = "warn";
      log-file = "/tmp/picom.log";
      show-all-xerrors = true;

      wintypes = {
        tooltip = {
          fade = true;
          shadow = false;
          focus = false;
        };
        normal = { shadow = false; };
        dock = { shadow = false; };
        dnd = { shadow = false; };
        popup_menu = {
          shadow = true;
          focus = false;
          opacity = 1;
        };
        dropdown_menu = {
          shadow = false;
          focus = false;
        };
        above = { shadow = true; };
        splash = { shadow = false; };
        utility = {
          focus = false;
          shadow = false;
          blur-background = false;
        };
        notification = { shadow = false; };
        desktop = {
          shadow = false;
          blur-background = false;
        };
        menu = { focus = false; };
        dialog = { shadow = true; };
      };
    };

    opacityRules = [ "0:_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'" ];
    shadow = false;
    shadowExclude = [
      # "bounding_shaped && !rounded_corners"
      "window_type *= 'menu'"
      "window_type *= 'dropdown_menu'"
      "window_type *= 'popup_menu'"
      "window_type *= 'utility'"
      "class_g = 'i3-frame'"
      "class_g = 'Polybar'"
      "name = 'Polybar tray window'"
      "name = 'Notification'"
      "_GTK_FRAME_EXTENTS@:c"
    ];
  };

  # xsession.windowManager.i3.config.window.commands = [{
  #   command = "border pixel 0";
  #   criteria.class = ".*";
  # }];
}
