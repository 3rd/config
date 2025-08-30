{ config, lib, pkgs, pkgs-stable, ... }:

let
  modifier = "Mod3";
  alt = "Mod1";
  monLeft = "DP-0";
  monCenter = "DP-2";
  monRight = "HDMI-0";
  workspaces = {
    one = "main";
    two = "dev";
    three = "work";
    four = "comm";
    five = "extra";
    last = "sys";
  };
  iconLeft = "◧";
  iconCenter = "▣";
  iconRight = "◨";
in {
  imports = [
    ./common.nix
    ../colors.nix
    ../xresources.nix
    ../services/polybar
    # ../services/dunst.nix
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
      screen-cycle = super.writeScriptBin "screen-cycle" ''
        #!${pkgs.bash}/bin/bash

        TIMESTAMP_FILE="/tmp/screen_cycle_last_press"
        THRESHOLD=1
        CURRENT_TIME=$(date +%s)

        # Check if timestamp file exists and read last press time
        if [ -f "$TIMESTAMP_FILE" ]; then
          LAST_PRESS=$(cat "$TIMESTAMP_FILE")
          TIME_DIFF=$((CURRENT_TIME - LAST_PRESS))

          if [ $TIME_DIFF -le $THRESHOLD ]; then
            WORKSPACE_INFO=$(i3-msg -t get_workspaces | ${pkgs.jq}/bin/jq -r '.[] | select(.focused==true).name')
            WS_NUM=$(echo "$WORKSPACE_INFO" | cut -d':' -f1)
            CURRENT_ICON=$(echo "$WORKSPACE_INFO" | cut -d' ' -f2)
            WS_NAME=$(echo "$WORKSPACE_INFO" | cut -d' ' -f3)
            if [ "$CURRENT_ICON" = "◨" ]; then
                TARGET_ICON="▣"
            elif [ "$CURRENT_ICON" = "▣" ]; then
                TARGET_ICON="◧"
            else
                TARGET_ICON="◨"
            fi
            i3-msg workspace "$WS_NUM: $TARGET_ICON $WS_NAME"
          else
            i3-msg workspace back_and_forth
          fi
        else
          i3-msg workspace back_and_forth
        fi

        echo "$CURRENT_TIME" > "$TIMESTAMP_FILE"
      '';
    })
  ];

  home.packages = with pkgs; [
    lock
    i3lock
    scrot
    xss-lock
    feh
    screen-cycle
    xmousepasteblock
  ];

  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";
    windowManager.i3 = {
      enable = true;
      package = pkgs.i3.overrideAttrs (oldAttrs: {
        src = pkgs.fetchFromGitHub {
          owner = "i3";
          repo = "i3";
          rev = "cfa4cf16bea809c7c715a86c428757e577c85254";
          sha256 = "sha256-Kvygsx0r2SGaAttSWLY/pk71oWf5VdUrB1dF8UwWwGI=";
        };
      });
      config = {
        bars = [ ];
        gaps = {
          inner = lib.mkDefault 4;
          outer = lib.mkDefault 0;
        };
        colors = with config.colors; {
          focused = {
            background = gray-dark;
            border = gray-darkish;
            childBorder = gray-darkish;
            indicator = gray-medium;
            text = gray-lightest;
          };
          focusedInactive = {
            background = gray-dark;
            border = gray-darkish;
            childBorder = gray-darkish;
            indicator = gray-dark;
            text = gray-lightest;
          };
          unfocused = {
            background = gray-dark;
            border = gray-dark;
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
          "XF86Tools" = "restart";
          "${modifier}+q" = "kill";
          "${modifier}+f" = "fullscreen toggle";
          "${modifier}+v" = "split h";
          "${modifier}+s" = "split v";
          # "${modifier}+Tab" = "workspace back_and_forth";
          "${modifier}+Tab" = "exec --no-startup-id screen-cycle";
          "${modifier}+o" = "floating toggle";
          "${modifier}+shift+o" = "sticky toggle";
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
          "${modifier}+shift+Return" =
            ''exec ulimit -n 999999 && /bin/sh -c "$BROWSER"'';
          "${modifier}+p" = "exec ${pkgs-stable.copyq}/bin/copyq show";
          "Print" = "exec ${pkgs-stable.flameshot}/bin/flameshot gui";
          "${alt}+space" = "exec ${pkgs.rofi}/bin/rofi -show drun -dpi 120";
          "ctrl+${alt}+space" =
            "exec ${pkgs.rofi}/bin/rofi -show window -dpi 120";
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
          { command = "--no-startup-id ${pkgs-stable.copyq}/bin/copyq"; }
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
              "--no-startup-id ${pkgs.feh}/bin/feh --bg-fill ~/.config/wallpaper";
            # "--no-startup-id ${pkgs.feh}/bin/feh --bg-fill ~/brain/config/assets/wallpaper";
          }
          {
            always = true;
            command =
              "--no-startup-id ${pkgs.xmousepasteblock}/bin/xmousepasteblock";
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

        default_border pixel 2
        default_floating_border pixel 2
        for_window [class="^.*"] border pixel 2

        bindcode ${modifier}+110 exec ${pkgs-stable.pcmanfm}/bin/pcmanfm
        bindcode ${modifier}+118 exec ulimit -n 999999 && /bin/sh -c "$BROWSER"
        bindcode ${modifier}+115 exec ulimit -n 999999 && /bin/sh -c "$BROWSER"

        # workspaces
        workspace "1: ${iconLeft} ${workspaces.one}" output ${monLeft}
        workspace "2: ${iconLeft} ${workspaces.two}" output ${monLeft}
        workspace "3: ${iconLeft} ${workspaces.three}" output ${monLeft}
        workspace "4: ${iconLeft} ${workspaces.four}" output ${monLeft}
        workspace "5: ${iconLeft} ${workspaces.five}" output ${monLeft}
        workspace "9: ${iconLeft} ${workspaces.last}" output ${monLeft}

        workspace "1: ${iconCenter} ${workspaces.one}" output ${monCenter}
        workspace "2: ${iconCenter} ${workspaces.two}" output ${monCenter}
        workspace "3: ${iconCenter} ${workspaces.three}" output ${monCenter}
        workspace "4: ${iconCenter} ${workspaces.four}" output ${monCenter}
        workspace "5: ${iconCenter} ${workspaces.five}" output ${monCenter}
        workspace "9: ${iconCenter} ${workspaces.last}" output ${monCenter}

        workspace "1: ${iconRight} ${workspaces.one}" output ${monRight}
        workspace "2: ${iconRight} ${workspaces.two}" output ${monRight}
        workspace "3: ${iconRight} ${workspaces.three}" output ${monRight}
        workspace "4: ${iconRight} ${workspaces.four}" output ${monRight}
        workspace "5: ${iconRight} ${workspaces.five}" output ${monRight}
        workspace "9: ${iconRight} ${workspaces.last}" output ${monRight}

        bindsym ${modifier}+1 workspace "1: ${iconLeft} ${workspaces.one}"; workspace "1: ${iconRight} ${workspaces.one}"; workspace "1: ${iconCenter} ${workspaces.one}"
        bindsym ${modifier}+2 workspace "2: ${iconLeft} ${workspaces.two}"; workspace "2: ${iconRight} ${workspaces.two}"; workspace "2: ${iconCenter} ${workspaces.two}"
        bindsym ${modifier}+3 workspace "3: ${iconLeft} ${workspaces.three}"; workspace "3: ${iconRight} ${workspaces.three}"; workspace "3: ${iconCenter} ${workspaces.three}"
        bindsym ${modifier}+4 workspace "4: ${iconLeft} ${workspaces.four}"; workspace "4: ${iconRight} ${workspaces.four}"; workspace "4: ${iconCenter} ${workspaces.four}"
        bindsym ${modifier}+5 workspace "5: ${iconLeft} ${workspaces.five}"; workspace "5: ${iconRight} ${workspaces.five}"; workspace "5: ${iconCenter} ${workspaces.five}"
        bindsym ${modifier}+0 workspace "9: ${iconLeft} ${workspaces.last}"; workspace "9: ${iconRight} ${workspaces.last}"; workspace "9: ${iconCenter} ${workspaces.last}"

        # move to workspace
        bindsym ${modifier}+Shift+1 move container to workspace "1: ${iconCenter} ${workspaces.one}"
        bindsym ${modifier}+Shift+2 move container to workspace "2: ${iconCenter} ${workspaces.two}"
        bindsym ${modifier}+Shift+3 move container to workspace "3: ${iconCenter} ${workspaces.three}"
        bindsym ${modifier}+Shift+4 move container to workspace "4: ${iconCenter} ${workspaces.four}"
        bindsym ${modifier}+Shift+5 move container to workspace "5: ${iconCenter} ${workspaces.five}"
        bindsym ${modifier}+Shift+0 move container to workspace "9: ${iconCenter} ${workspaces.last}"

        # default to the first workspace
        exec i3-msg 'workspace "1: ${iconLeft} ${workspaces.one}"; workspace "1: ${iconRight} ${workspaces.one}"; workspace "1: ${iconCenter} ${workspaces.one}"'

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
    eval $(${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets,pkcs11)
  '';

  systemd.user.services = {
    setxkbmap.Service.ExecStart = lib.mkForce "${pkgs.coreutils}/bin/true";
  };
}
