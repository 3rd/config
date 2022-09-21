{ config, pkgs, ... }:

{
  services.picom = {
    enable = true;
    package = pkgs.picom.overrideAttrs (o: {
      src = pkgs.fetchFromGitHub {
        repo = "picom";
        owner = "ibhagwan";
        rev = "c4107bb6cc17773fdc6c48bb2e475ef957513c7a";
        sha256 = "1hVFBGo4Ieke2T9PqMur1w4D0bz/L3FAvfujY9Zergw=";
      };
    });
    backend = "glx";
    vSync = false;
    opacityRule = [ "0:_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'" ];
    shadow = false;
    shadowExclude = [
      "bounding_shaped && !rounded_corners"
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
    extraOptions = ''
      mark-wmwin-focused = true;
      mark-ovredir-focused = true;
      detect-rounded-corners = true;
      detect-client-opacity = true;
      detect-transient = true;
      detect-client-leader = true;
      log-level = "info";
      log-file = "/tmp/picom.log";

      fading = false;
      fade-in-step = 0.03;
      fade-out-step = 0.03;
      fade-delta = 1;
      fade-exclude = [];

      blur: {
        method = "dual_kawase";
        strength = 6;
        background = false;
        background-frame = false;
        background-fixed = false;
        kern = "3x3box";
      }
      blur-background-exclude = [
        "_GTK_FRAME_EXTENTS@:c",
        "class_g = 'Polybar'",
      ];

      corner-radius = 10.0;
      rounded-corners-exclude = [
        "class_g = 'Polybar'",
      ];

      round-borders = 1;
      round-borders-exclude = [];
      round-borders-rule = [];
    '';
  };

  xsession.windowManager.i3.config.window.commands = [{
    command = "border pixel 0";
    criteria.class = ".*";
  }];
}
