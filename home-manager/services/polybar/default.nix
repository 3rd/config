{ config, pkgs, lib, ... }:

{
  imports = [ ../../colors.nix ];

  home.file = {
    ".config/polybar/bluetooth.sh" = {
      executable = true;
      source = ./bluetooth.sh;
    };
    ".config/polybar/task.sh" = {
      executable = true;
      source = ./task.sh;
    };
    ".config/polybar/vpn.sh" = {
      executable = true;
      source = ./vpn.sh;
    };
    ".config/polybar/core.sh" = {
      executable = true;
      source = ./core.sh;
    };
    ".config/polybar/bci.sh" = {
      executable = true;
      source = ./bci.sh;
    };
  };

  services.polybar = {
    enable = true;
    package = pkgs.polybar.override {
      # i3GapsSupport = true;
      i3Support = true;
      mpdSupport = true;
      pulseSupport = true;
    };
    script = ''
      polybar top -r &
    '';
    config = with config.colors; {
      "bar/common" = {
        background = gray-darkest;
        font-0 = lib.mkDefault "Fira Sans Mono:size=12;3";
        font-1 = lib.mkDefault "Symbols Nerd Font:size=12;3";
        font-2 = lib.mkDefault "Symbols Nerd Font:size=12;3";
      };
      "bar/top" = {
        "inherit" = "bar/common";
        modules-left = "i3";
        modules-center = "task";
        modules-right =
          "bci vpn battery sep pulseaudio bluetooth cpu cpu_temp sep mem sep fs sep clock";
        height = 28;
        fixed-center = true;
        tray-background = gray-darkest;
        tray-position = "right";
        tray-scale = "1.0";
      };
      "module/blank" = {
        type = "custom/text";
        content = " ";
      };
      "module/sep" = {
        type = "custom/text";
        content = " ";
        content-background = gray-darkest;
      };
      "module/<" = {
        type = "custom/text";
        content = "";
        content-background = background;
        content-foreground = gray-darkest;
        content-font = 3;
      };
      "module/<<" = {
        "inherit" = "module/<";
        content-background = gray-darkest;
        content-foreground = gray-darker;
      };
      "module/<<<" = {
        "inherit" = "module/<";
        content-background = gray-darker;
        content-foreground = gray-dark;
      };
      "module/>" = {
        type = "custom/text";
        content = "";
        content-background = background;
        content-foreground = gray-darkest;
        content-font = 3;
      };
      "module/>>" = {
        "inherit" = "module/>";
        content-background = gray-darkest;
        content-foreground = gray-darker;
      };
      "module/>>>" = {
        "inherit" = "module/>";
        content-background = gray-darker;
        content-foreground = gray-dark;
      };
      "module/i3" = {
        type = "internal/i3";
        enable-click = true;
        enable-scroll = true;
        format = "<label-state> <label-mode>";
        fuzzy-match = true;
        index-sort = true;
        label-focused = "%icon% %name%";
        label-focused-background = gray-dark;
        label-focused-foreground = foreground;
        label-focused-padding = 2;
        label-mode = "%mode%";
        label-mode-background = red-dark;
        label-mode-foreground = foreground;
        label-mode-padding = 2;
        label-unfocused = "%icon% %name%";
        label-unfocused-background = gray-darkest;
        label-unfocused-foreground = gray-light;
        label-unfocused-padding = 2;
        label-urgent = "%icon% %name%";
        label-urgent-background = red-medium;
        label-urgent-foreground = foreground;
        label-urgent-padding = 2;
        label-visible-padding = 2;
        pin-workspaces = true;
        reverse-scroll = false;
        strip-wsnumbers = true;
        wrapping-scroll = false;
      };
      "module/battery" = {
        type = "internal/battery";
        adapter = lib.mkDefault "ADP0";
        battery = lib.mkDefault "BAT0";
        full-at = 100;
        animation-charging-0 = "";
        animation-charging-1 = "";
        animation-charging-2 = "";
        animation-charging-3 = "";
        animation-charging-4 = "";
        animation-charging-framerate = 320;
        format-charging = "<animation-charging> <label-charging>";
        format-charging-foreground = gray-medium;
        format-discharging = "<ramp-capacity> <label-discharging>";
        format-discharging-foreground = foreground;
        format-charging-padding = 2;
        format-discharging-padding = 2;
        format-padding = 1;
        label-charging = "%percentage%% (%time%)";
        label-discharging = "%percentage%% (%time%)";
        label-full = "";
        ramp-capacity-0 = "";
        ramp-capacity-1 = "";
        ramp-capacity-2 = "";
        ramp-capacity-3 = "";
        ramp-capacity-4 = "";
      };
      "module/cpu" = {
        type = "internal/cpu";
        format-background = gray-darkest;
        format-foreground = gray-light;
        format-prefix = " ";
        format-prefix-foreground = gray-lighter;
        format-padding = 1;
        interval = 1;
        label = "%percentage:2%%";
      };
      "module/cpu_temp" = {
        type = "internal/temperature";
        interval = 1;
        hwmon-path = "/sys/devices/platform/it87.2656/hwmon/hwmon2/temp1_input";
        label = "%temperature-c%";
        format-background = gray-darkest;
        format-foreground = gray-light;
      };
      "module/mem" = {
        type = "internal/memory";
        format = "<label>";
        format-background = gray-darkest;
        format-foreground = gray-light;
        format-prefix = "󰍛 ";
        format-prefix-foreground = gray-lighter;
        format-padding = 1;
        interval = 1;
        label = "%percentage_used:2%%";
      };
      "module/fs" = {
        type = "internal/fs";
        mount-0 = "/";
        interval = 60;
        format-mounted-background = gray-darkest;
        format-mounted-foreground = gray-light;
        label-mounted = "%mountpoint% %percentage_used%%";
        label-unmounted = "";
      };
      "module/pulseaudio" = {
        type = "internal/pulseaudio";
        click-right = "/run/current-system/sw/bin/pavucontrol &";
        format-volume = "󰖀 <label-volume>";
        format-volume-background = gray-darkest;
        format-volume-foreground = gray-lighter;
        format-volume-padding = 1;
        label-muted-background = gray-darkest;
        label-muted-foreground = red-light;
        label-muted-padding = 1;
        label-muted = "󰖁";
      };
      "module/bluetooth" = {
        type = "custom/script";
        exec = "/home/rabbit/.config/polybar/bluetooth.sh";
        click-left = "exec /run/current-system/sw/bin/blueman-manager";
        # click-right = "";
        format-background = gray-darkest;
        format-foreground = gray-lighter;
        format-padding = 2;
        interval = 2;
      };
      "module/clock" = {
        type = "internal/date";
        date = "%Y.%m.%d";
        time = "%H:%M:%S";
        label = "%time%";
        interval = 1;
        format-background = gray-darkest;
        format-foreground = foreground;
        format-padding = 1;
      };
      "module/vpn" = {
        type = "custom/script";
        exec = "/home/rabbit/.config/polybar/vpn.sh";
        interval = 1;
        format-background = red-darker;
        format-foreground = foreground;
        format-padding = 2;
      };
      # "module/core" = {
      #   type = "custom/script";
      #   exec = "/home/rabbit/.config/polybar/core.sh";
      #   interval = 1;
      #   format-background = gray-darkest;
      #   format-foreground = foreground;
      #   format-padding = 2;
      # };
      "module/task" = {
        type = "custom/script";
        exec =
          "WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki /home/rabbit/.config/polybar/task.sh";
        format-background = gray-dark;
        format-foreground = foreground;
        format-padding = 2;
        interval = 10;
      };
      "module/bci" = {
        type = "custom/script";
        exec = "/home/rabbit/.config/polybar/bci.sh";
        interval = 1;
        format-background = gray-darker;
        format-foreground = gray-light;
        format-padding = 2;
      };
    };
  };
}
