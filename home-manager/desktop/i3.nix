{ config, lib, pkgs, ... }:

let
  modifier = "Mod3";
  alt = "Mod1";
  mon1 = "DP-4";
  mon2 = "DP-0";
  workspaces = {
    one = "main";
    two = "dev";
    three = "work";
    four = "comm";
    five = "extra";
    last = "sys";
  };
in {
  imports = [
    ./common.nix
    ../colors.nix
    ../xresources.nix
    ../services/polybar
    ../services/dunst.nix
    ../services/picom.nix
  ];

  nixpkgs.overlays = [
    (self: super: {
      lock = super.writeScriptBin "lock" ''
        #!${pkgs.bash}/bin/bash

        # IMAGE=/tmp/i3lock.png
        # BLURTYPE="0x6" # 2.90s
        # ${pkgs.scrot}/bin/scrot "$IMAGE"
        # ${pkgs.imagemagick}/bin/convert $IMAGE -blur $BLURTYPE $IMAGE
        # ${pkgs.i3lock}/bin/i3lock -i $IMAGE
        # ${pkgs.coreutils}/bin/rm $IMAGE
        # ${pkgs.i3}/bin/i3 mode default

        IMAGE=/home/rabbit/brain/config/dotfiles/lock.png
        SIZE=$(xdpyinfo | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/' | head -n1)
        ${pkgs.imagemagick}/bin/convert -resize "$SIZE^" -extent "$SIZE" -gravity center "$IMAGE" /tmp/lock.png
        ${pkgs.i3lock}/bin/i3lock -i /tmp/lock.png
        ${pkgs.i3}/bin/i3 mode default
      '';
    })
  ];

  home.packages = with pkgs; [ lock i3lock scrot xss-lock feh ];

  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";
    windowManager.i3 = {
      enable = true;
      # package = pkgs.i3-gaps; # https://github.com/NixOS/nixpkgs/commit/7d4e95ba7527fa7bd5b1f8a1707b7e3ee2bbe82d
      config = {
        bars = [ ];
        colors = with config.colors; {
          focused = {
            background = gray-dark;
            border = gray-lighter;
            childBorder = gray-medium;
            indicator = gray-medium;
            text = gray-lightest;
          };
          focusedInactive = {
            background = gray-dark;
            border = gray-light;
            childBorder = gray-dark;
            indicator = gray-dark;
            text = gray-lightest;
          };
          unfocused = {
            background = gray-dark;
            border = gray-light;
            childBorder = gray-dark;
            indicator = gray-dark;
            text = gray-lightest;
          };
          urgent = {
            background = red-dark;
            border = red-light;
            childBorder = red-dark;
            indicator = red-dark;
            text = red-lightest;
          };
        };
        modes = {
          resize = {
            h = "resize shrink width 10 px or 10 ppt";
            j = "resize grow height 10 px or 10 ppt";
            k = "resize shrink height 10 px or 10 ppt";
            l = "resize grow width 10 px or 10 ppt";
            Return = "mode default";
            Escape = "mode default";
            "${modifier}+r" = "mode default";
          };
          power = {
            x = "exec i3-msg exit";
            r = "exec systemctl reboot";
            h = "exec systemctl hibernate";
            s = "exec systemctl poweroff";
            l = "exec lock";
            Return = "mode default";
            Escape = "mode default";
            "${modifier}+x" = "mode default";
          };
        };
        # bindsym ${modifier}+x mode "@ e(x)it (r)eboot (s)hutdown (h)ibernate (l)ock"
        keybindings = {
          # core
          "${modifier}+shift+r" = "restart";
          "${modifier}+q" = "kill";
          "${modifier}+f" = "fullscreen toggle";
          "${modifier}+v" = "split h";
          "${modifier}+s" = "split v";
          "${modifier}+Tab" = "workspace back_and_forth";
          "${modifier}+o" = "floating toggle";
          "${modifier}+shift+o" = "floating toggle; sticky toggle";
          "${modifier}+h" = "focus left";
          "${modifier}+j" = "focus down";
          "${modifier}+k" = "focus up";
          "${modifier}+l" = "focus right";
          "${modifier}+shift+h" = "move left";
          "${modifier}+shift+j" = "move down";
          "${modifier}+shift+k" = "move up";
          "${modifier}+shift+l" = "move right";
          # media
          "XF86AudioRaiseVolume" =
            "exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ false, exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%";
          "XF86AudioLowerVolume" =
            "exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ false, exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%";
          "XF86AudioMute" =
            "exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
          "XF86AudioMicMute" =
            "exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle";
          "XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
          "XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
          "XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
          "XF86MonBrightnessUp" =
            "exec ${pkgs.brightnessctl}/bin/brightnessctl set +5% && notify-send Brightness $(brightnessctl get) -h string:x-canonical-private-synchronous:brightness_percentage --app-name System";
          "XF86MonBrightnessDown" =
            "exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%- && notify-send Brightness $(brightnessctl get) -h string:x-canonical-private-synchronous:brightness_percentage --app-name System";
          "XF86KbdBrightnessUp" =
            "exec ${pkgs.brightnessctl}/bin/brightnessctl --device=smc::kbd_backlight' set +25%";
          "XF86KbdBrightnessDown" =
            "exec ${pkgs.brightnessctl}/bin/brightnessctl --device='smc::kbd_backlight' set 25%-";
          # modes
          "${modifier}+r" = "mode resize";
          "${modifier}+x" = "mode power";
          # launchers
          "${modifier}+Return" = "exec ${pkgs.kitty}/bin/kitty";
          "${modifier}+shift+Return" = ''
            exec ulimit -n 999999 && /bin/sh -c "$BROWSER --disable-backgrounding-occluded-windows"'';
          # "F4" = "exec ${pkgs.kitty}/bin/kitty";;
          "${modifier}+p" = "exec ${pkgs.copyq}/bin/copyq show";
          "Print" = "exec ${pkgs.flameshot}/bin/flameshot gui";
          "${alt}+space" = "exec ${pkgs.rofi}/bin/rofi -show drun -dpi 120";
        };
        floating = {
          inherit modifier;
          border = 2;
          criteria = [
            { class = "Pcmanfm"; }
            { instance = "copyq"; }
            { instance = "pavucontrol"; }
            { instance = "yad"; }
          ];
        };
        startup = [
          {
            always = true;
            command =
              "--no-startup-id ${pkgs.xss-lock}/bin/xss-lock -l -- ${pkgs.lock}/bin/lock";
          }
          { command = "--no-startup-id ${pkgs.copyq}/bin/copyq"; }
          { command = "--no-startup-id ${pkgs.flameshot}/bin/flameshot"; }
          {
            always = true;
            command =
              "--no-startup-id ${pkgs.xorg.xmodmap}/bin/xmodmap ~/brain/config/dotfiles/xmodmap";
          }
          {
            always = true;
            command = "--no-startup-id ${pkgs.xorg.xset}/bin/xset -dpms";
          }
          {
            always = true;
            command =
              "--no-startup-id ${pkgs.xorg.xset}/bin/xset r rate 200 50";
          }
          {
            always = true;
            command = "--no-startup-id ${pkgs.xorg.xset}/bin/xset s off";
          }
          {
            always = true;
            command = "--no-startup-id ${pkgs.xorg.xset}/bin/xset m 0 0";
          }
          {
            always = true;
            command =
              "--no-startup-id ${pkgs.systemd}/bin/systemctl --user restart polybar";
          }
          {
            always = true;
            command =
              "--no-startup-id ${pkgs.feh}/bin/feh --bg-fill ~/brain/config/assets/wallpaper";
            # "--no-startup-id ${pkgs.feh}/bin/feh --bg-fill --no-fehbg --randomize ~/brain/config/assets/wallpapers";
            # ''--no-startup-id ${pkgs.hsetroot}/bin/hsetroot -solid "${config.colors.gray-darker}"'';
          }
        ];
      };
      extraConfig = ''
        # settings
        workspace_auto_back_and_forth yes
        workspace_layout default
        default_orientation horizontal
        focus_follows_mouse no
        focus_on_window_activation none
        hide_edge_borders both
        gaps inner 4
        gaps outer 0

        default_border pixel 2
        default_floating_border pixel 2
        for_window [class="^.*"] border pixel 2

        bindcode ${modifier}+110 exec ${pkgs.pcmanfm}/bin/pcmanfm
        bindcode ${modifier}+118 exec ulimit -n 999999 && /bin/sh -c "$BROWSER --disable-backgrounding-occluded-windows"

        # workspaces
        workspace "1: ◨ ${workspaces.one}" output ${mon1}
        workspace "1: ◧ ${workspaces.one}" output ${mon2}
        workspace "2: ◨ ${workspaces.two}" output ${mon1}
        workspace "2: ◧ ${workspaces.two}" output ${mon2}
        workspace "3: ◨ ${workspaces.three}" output ${mon1}
        workspace "3: ◧ ${workspaces.three}" output ${mon2}
        workspace "4: ◨ ${workspaces.four}" output ${mon1}
        workspace "4: ◧ ${workspaces.four}" output ${mon2}
        workspace "5: ◨ ${workspaces.five}" output ${mon1}
        workspace "5: ◧ ${workspaces.five}" output ${mon2}
        workspace "9: ◨ ${workspaces.last}" output ${mon1}
        workspace "9: ◧ ${workspaces.last}" output ${mon2}
        bindsym ${modifier}+1 workspace "1: ◨ ${workspaces.one}", workspace "1: ◧ ${workspaces.one}"
        bindsym ${modifier}+2 workspace "2: ◨ ${workspaces.two}", workspace "2: ◧ ${workspaces.two}"
        bindsym ${modifier}+3 workspace "3: ◨ ${workspaces.three}", workspace "3: ◧ ${workspaces.three}"
        bindsym ${modifier}+4 workspace "4: ◨ ${workspaces.four}", workspace "4: ◧ ${workspaces.four}"
        bindsym ${modifier}+5 workspace "5: ◨ ${workspaces.five}", workspace "5: ◧ ${workspaces.five}"
        bindsym ${modifier}+0 workspace "9: ◨ ${workspaces.last}", workspace "9: ◧ ${workspaces.last}"
        bindsym ${modifier}+Shift+1 move container to workspace "1: ◧ ${workspaces.one}"
        bindsym ${modifier}+Shift+2 move container to workspace "2: ◧ ${workspaces.two}"
        bindsym ${modifier}+Shift+3 move container to workspace "3: ◧ ${workspaces.three}"
        bindsym ${modifier}+Shift+4 move container to workspace "4: ◧ ${workspaces.four}"
        bindsym ${modifier}+Shift+5 move container to workspace "5: ◧ ${workspaces.five}"
        bindsym ${modifier}+Shift+0 move container to workspace "9: ◧ ${workspaces.last}"

        # default to the first workspace
        exec i3-msg 'workspace "1: ◧ ${workspaces.one}"'

        # resize (mouse)
        bindsym --whole-window --border ${modifier}+shift+button4 resize grow height 5 px or 5 ppt
        bindsym --whole-window --border ${modifier}+shift+button5 resize shrink height 5 px or 5 ppt
        bindsym --whole-window --border ${modifier}+button4 resize grow width 5 px or 5 ppt
        bindsym --whole-window --border ${modifier}+button5 resize shrink width 5 px or 5 ppt

        # core
        bindsym ${modifier}+t exec ~/.config/bin/task-add
        bindsym ${modifier}+c exec ~/brain/config/core/wiki-consume
      '';
    };
    preferStatusNotifierItems = true;
    numlock.enable = true;
  };

  xsession.profileExtra = ''
    systemctl --user import-environment
    eval $(${pkgs.gnome.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets,ssh,pkcs11)
    export SSH_AUTH_SOCK
  '';

  systemd.user.services = {
    setxkbmap.Service.ExecStart = lib.mkForce "${pkgs.coreutils}/bin/true";
  };
}
