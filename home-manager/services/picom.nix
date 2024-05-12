{ lib, config, ... }:

{
  services.picom = {
    enable = true;
    backend = lib.mkDefault "glx";
    vSync = true;
    settings = {
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

      use-damage = true;
      transparent-clipping = false;

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
          opacity = 0.9;
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

  xsession.windowManager.i3.config.window.commands = [{
    command = "border pixel 0";
    criteria.class = ".*";
  }];
}
