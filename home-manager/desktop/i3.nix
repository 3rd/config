{
  config,
  lib,
  pkgs,
  pkgs-stable,
  ...
}:

let
  browserExe = config.programs.chromium.finalPackage.meta.mainProgram or "chromium";
  modifier = "Mod3";
  alt = "Mod1";
  monLeft = "DP-0";
  monCenter = "DP-2";
  monRight = "HDMI-0";
  desktopOsdExe = lib.getExe config.desktop.osd.package;
  desktopMenu = pkgs.writeShellApplication {
    name = "desktop-menu";
    runtimeInputs = [
      config.programs.rofi.package
      pkgs.gnugrep
    ];
    text = builtins.readFile ./desktop-menu.sh;
  };
  desktopMenuExe = lib.getExe desktopMenu;
  polybarMsgExe = lib.getExe' config.services.polybar.package "polybar-msg";
  columnLabels = [
    "main"
    "dev"
    "work"
    "comm"
    "extra"
  ];
  bands = [
    {
      prefix = 0;
      mark = "";
    }
    {
      prefix = 1;
      mark = "▴";
    }
    {
      prefix = 2;
      mark = "▾";
    }
  ];
  sysNumber = 9;
  sysLabel = "sys";
  bandStateFile = "/tmp/workspace-grid-band";
  wsName = num: icon: label: "${toString num}: ${icon} ${label}";
  gridWorkspaces = lib.concatMap (
    band:
    lib.imap1 (column: label: {
      num = band.prefix * 10 + column;
      label = "${band.mark}${label}";
    }) columnLabels
  ) bands;
  allWorkspaces = gridWorkspaces ++ [
    {
      num = sysNumber;
      label = sysLabel;
    }
  ];
  iconLeft = "◧";
  iconCenter = "▣";
  iconRight = "◨";
  monitors = [
    { output = monLeft; icon = iconLeft; }
    { output = monCenter; icon = iconCenter; }
    { output = monRight; icon = iconRight; }
  ];
  workspaceOutputConfig = lib.concatMapStrings (
    ws:
    lib.concatMapStrings (
      mon: "workspace \"${wsName ws.num mon.icon ws.label}\" output ${mon.output}\n"
    ) monitors
  ) allWorkspaces;
  labelCaseEntries = lib.concatMapStrings (
    ws: "${toString ws.num}) echo \"${ws.label}\" ;;\n    "
  ) allWorkspaces;
  markCaseEntries = lib.concatMapStrings (
    band: "${toString band.prefix}) mark=\"${band.mark}\" ;;\n    "
  ) bands;
in
{
  imports = [
    ./common.nix
    ./desktop-osd.nix
    ../colors.nix
    ./xresources.nix
    ../services/polybar
    ../services/xfce4-notifyd.nix
    ../services/fastcompmgr.nix
    ../services/xmousepasteblock.nix
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
      alt-tab-scratchpad = super.writeScriptBin "alt-tab-scratchpad" ''
        #!${pkgs.bash}/bin/bash

        set -eu

        MARK="alt-tab"
        I3_MSG="${pkgs.i3}/bin/i3-msg"
        JQ="${pkgs.jq}/bin/jq"
        ACTION="''${1:-toggle}"

        tree_json="$("$I3_MSG" -t get_tree)"

        focused_id="$(printf '%s\n' "$tree_json" | "$JQ" -r '[.. | objects | select(.focused == true and (.window? != null)) | .id][0] // empty')"
        marked_id="$(printf '%s\n' "$tree_json" | "$JQ" -r --arg mark "$MARK" '[.. | objects | select(((.marks // []) | index($mark)) != null and (.window? != null)) | .id][0] // empty')"
        marked_visible="$(printf '%s\n' "$tree_json" | "$JQ" -r --arg mark "$MARK" '[.. | objects | select(((.marks // []) | index($mark)) != null and (.window? != null)) | .visible][0] // false')"

        eject_marked() {
          [ -n "$marked_id" ] || return 0

          current_workspace="$(
            "$I3_MSG" -t get_outputs | "$JQ" -r '
              [.[] | select(.active == true and .focused == true) | .current_workspace][0]
              // empty
            '
          )"

          if [ -z "$current_workspace" ]; then
            current_workspace="$("$I3_MSG" -t get_workspaces | "$JQ" -r '[.[] | select(.focused == true) | .name][0] // empty')"
          fi

          [ -n "$current_workspace" ] || return 0
          "$I3_MSG" "[con_id=$marked_id] move container to workspace \"$current_workspace\"; [con_id=$marked_id] floating disable; [con_id=$marked_id] unmark $MARK" >/dev/null
        }

        toggle() {
          [ -n "$marked_id" ] || exit 0

          if [ "$marked_visible" = "true" ]; then
            "$I3_MSG" "[con_mark=\"^$MARK$\"] scratchpad show" >/dev/null
            exit 0
          fi

          "$I3_MSG" "[con_mark=\"^$MARK$\"] scratchpad show; [con_mark=\"^$MARK$\"] move position center" >/dev/null
        }

        store() {
          [ -n "$focused_id" ] || exit 0

          if [ "$focused_id" = "$marked_id" ]; then
            eject_marked
            exit 0
          fi

          eject_marked

          "$I3_MSG" "[con_id=$focused_id] mark --replace $MARK; [con_id=$focused_id] move scratchpad" >/dev/null
        }

        case "$ACTION" in
          store) store ;;
          toggle) toggle ;;
          *) exit 1 ;;
        esac
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
      workspace-grid = super.writeScriptBin "workspace-grid" ''
        #!${pkgs.bash}/bin/bash

        set -eu

        I3_MSG="${pkgs.i3}/bin/i3-msg"
        JQ="${pkgs.jq}/bin/jq"
        ACTION="''${1:-}"

        label_for() {
          case "$1" in
            ${labelCaseEntries}esac
        }

        ws() {
          echo "$1: $2 $(label_for "$1")"
        }

        switch_all() {
          if [ "$1" -ne ${toString sysNumber} ]; then
            echo "$(($1 / 10))" > "${bandStateFile}"
          fi
          "$I3_MSG" "workspace \"$(ws "$1" "${iconLeft}")\"; workspace \"$(ws "$1" "${iconRight}")\"; workspace \"$(ws "$1" "${iconCenter}")\"" >/dev/null
        }

        move_to() {
          "$I3_MSG" "move container to workspace \"$(ws "$1" "$focused_icon")\"" >/dev/null
        }

        apply() {
          case "$ACTION" in
            move-*) move_to "$1" ;;
            *) switch_all "$1" ;;
          esac
        }

        workspaces_json="$("$I3_MSG" -t get_workspaces)"
        focused_num="$(printf '%s' "$workspaces_json" | "$JQ" -r '[.[] | select(.focused == true) | .num][0] // 1')"
        focused_icon="$(printf '%s' "$workspaces_json" | "$JQ" -r '([.[] | select(.focused == true) | .name][0] // "") | split(" ")[1] // ""')"
        [ -n "$focused_icon" ] || focused_icon="${iconCenter}"
        band=$((focused_num / 10))
        column=$((focused_num % 10))
        on_sys=0
        if [ "$focused_num" -eq ${toString sysNumber} ]; then
          on_sys=1
          if [ -r "${bandStateFile}" ]; then
            band="$(< "${bandStateFile}")"
          fi
          case "$band" in
            0 | 1 | 2) ;;
            *) band=0 ;;
          esac
        fi

        case "$ACTION" in
          switch)
            switch_all "$((band * 10 + ''${2:?}))"
            ;;
          move)
            "$I3_MSG" "move container to workspace \"$(ws "$((band * 10 + ''${2:?}))" "${iconCenter}")\"" >/dev/null
            ;;
          up | down | move-up | move-down)
            direction="''${ACTION#move-}"
            if [ "$on_sys" -eq 1 ]; then
              case "$ACTION" in
                move-*) exit 0 ;;
              esac
              case "$direction:$band" in
                up:0) band=1 ;;
                up:2) band=0 ;;
                down:0) band=2 ;;
                down:1) band=0 ;;
                *) exit 0 ;;
              esac
              echo "$band" > "${bandStateFile}"
              "$I3_MSG" -t send_tick workspace-grid-band >/dev/null
              exit 0
            fi
            if [ "$column" -lt 1 ] || [ "$column" -gt 5 ]; then
              exit 0
            fi
            case "$direction:$band" in
              up:0) band=1 ;;
              up:2) band=0 ;;
              down:0) band=2 ;;
              down:1) band=0 ;;
              *) exit 0 ;;
            esac
            apply "$((band * 10 + column))"
            ;;
          left | move-left)
            if [ "$on_sys" -eq 1 ]; then
              apply "$((band * 10 + 5))"
              exit 0
            fi
            if [ "$column" -lt 2 ] || [ "$column" -gt 5 ]; then
              exit 0
            fi
            apply "$((band * 10 + column - 1))"
            ;;
          right | move-right)
            if [ "$on_sys" -eq 1 ] || [ "$column" -lt 1 ]; then
              exit 0
            fi
            if [ "$column" -eq 5 ]; then
              apply "${toString sysNumber}"
              exit 0
            fi
            apply "$((band * 10 + column + 1))"
            ;;
          sys)
            switch_all "${toString sysNumber}"
            ;;
          *) exit 1 ;;
        esac
      '';
      workspace-band-status = super.writeScriptBin "workspace-band-status" ''
        #!${pkgs.bash}/bin/bash

        set -eu

        I3_MSG="${pkgs.i3}/bin/i3-msg"
        JQ="${pkgs.jq}/bin/jq"
        WORKSPACE_GRID="${lib.getExe' self.workspace-grid "workspace-grid"}"

        labels=(${lib.concatMapStringsSep " " (label: "\"${label}\"") columnLabels})

        render() {
          local workspaces_json focused_num focused_icon urgent_nums urgent_num hidden_urgent band mark mark_color icon_color mode out col label num cell

          workspaces_json="$("$I3_MSG" -t get_workspaces)"
          focused_num="$(printf '%s' "$workspaces_json" | "$JQ" -r '[.[] | select(.focused == true) | .num][0] // 1')"
          focused_icon="$(printf '%s' "$workspaces_json" | "$JQ" -r '([.[] | select(.focused == true) | .name][0] // "") | split(" ")[1] // ""')"
          urgent_nums="$(printf '%s' "$workspaces_json" | "$JQ" -r '[.[] | select(.urgent == true) | .num | tostring] | join(" ")')"
          band=$((focused_num / 10))
          if [ "$focused_num" -eq ${toString sysNumber} ]; then
            if [ -r "${bandStateFile}" ]; then
              band="$(< "${bandStateFile}")"
            fi
            case "$band" in
              0 | 1 | 2) ;;
              *) band=0 ;;
            esac
          fi

          mark=""
          case "$band" in
            ${markCaseEntries}esac
          mark_color="${config.colors.gray-lighter}"
          if [ -z "$mark" ]; then
            # invisible placeholder; ▴ matches the ▴/▾ advance width in DejaVu Sans exactly
            mark="▴"
            mark_color="${config.colors.panel-background}"
          fi

          # a red icon signals an urgent workspace in a band that is not displayed
          hidden_urgent=0
          for urgent_num in $urgent_nums; do
            if [ "$urgent_num" -ne ${toString sysNumber} ] && [ $((urgent_num / 10)) -ne "$band" ]; then
              hidden_urgent=1
            fi
          done
          icon_color="${config.colors.gray-lighter}"
          if [ "$hidden_urgent" -eq 1 ]; then
            icon_color="${config.colors.red-light}"
          fi

          out="%{F$mark_color} $mark %{F-}%{F$icon_color}$focused_icon %{F-}%{F${config.colors.foreground}}"
          col=1
          for label in "''${labels[@]}"; do
            num=$((band * 10 + col))
            cell="  $label  "
            if [ "$num" -eq "$focused_num" ]; then
              cell="%{B${config.colors.gray-dark}}$cell%{B-}"
            elif [[ " $urgent_nums " == *" $num "* ]]; then
              cell="%{B${config.colors.red-medium}}$cell%{B-}"
            fi
            out+="%{A1:$WORKSPACE_GRID switch $col:}$cell%{A}"
            col=$((col + 1))
          done

          cell="  ${sysLabel}  "
          if [ "$focused_num" -eq ${toString sysNumber} ]; then
            cell="%{B${config.colors.gray-dark}}$cell%{B-}"
          elif [[ " $urgent_nums " == *" ${toString sysNumber} "* ]]; then
            cell="%{B${config.colors.red-medium}}$cell%{B-}"
          fi
          out+="%{A1:$WORKSPACE_GRID sys:}$cell%{A}"

          mode="$("$I3_MSG" -t get_binding_state | "$JQ" -r '.name')"
          if [ "$mode" != "default" ]; then
            out+=" %{B${config.colors.red-dark}}  $mode  %{B-}"
          fi

          printf '%s%%{F-}\n' "$out"
        }

        render
        "$I3_MSG" -t subscribe -m '["workspace","mode","tick"]' | while read -r _; do
          render
        done
      '';
    })
  ];

  home.packages =
    with pkgs;
    [
      lock
      i3lock
      scrot
      feh
      alt-tab-scratchpad
      screen-cycle
      workspace-grid
      desktopMenu
    ]
    ++ (with pkgs-stable; [ xss-lock ]);

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
        patches = (oldAttrs.patches or [ ]) ++ [
          ./i3-ignore-empty-swallow-on-restart.patch
        ];
        doCheck = false;
      });
      config = {
        bars = [ ];
        fonts = {
          names = [ "DejaVu Sans" ];
          size = 9.0;
        };
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
            background = gray-darker;
            border = gray-darkish;
            childBorder = gray-darkish;
            indicator = gray-medium;
            text = gray-lightest;
          };
          unfocused = {
            background = gray-darkest;
            border = gray-darker;
            childBorder = gray-darker;
            indicator = gray-darkish;
            text = gray-lighter;
          };
          urgent = {
            background = red-darkest;
            border = red-light;
            childBorder = red-dark;
            indicator = red-medium;
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
          "${modifier}+b" = "exec --no-startup-id ${polybarMsgExe} cmd toggle";
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
          "XF86AudioRaiseVolume" = "exec --no-startup-id ${desktopOsdExe} volume up";
          "XF86AudioLowerVolume" = "exec --no-startup-id ${desktopOsdExe} volume down";
          "XF86AudioMute" = "exec --no-startup-id ${desktopOsdExe} volume toggle";
          "XF86AudioMicMute" = "exec --no-startup-id ${desktopOsdExe} microphone toggle";
          "XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
          "XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
          "XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
          "XF86MonBrightnessUp" = "exec --no-startup-id ${desktopOsdExe} brightness up";
          "XF86MonBrightnessDown" = "exec --no-startup-id ${desktopOsdExe} brightness down";
          "XF86KbdBrightnessUp" = "exec --no-startup-id ${desktopOsdExe} keyboard-brightness up";
          "XF86KbdBrightnessDown" = "exec --no-startup-id ${desktopOsdExe} keyboard-brightness down";
          # modes
          "${modifier}+r" = "mode resize";
          "${modifier}+x" = "mode power";
          # launchers
          "${modifier}+Return" = "exec ${pkgs.kitty}/bin/kitty";
          "${modifier}+shift+Return" = "exec ulimit -n 999999 && ${browserExe}";
          "${modifier}+p" = "exec ${pkgs.copyq}/bin/copyq show";
          "Print" = "exec ${pkgs-stable.flameshot}/bin/flameshot gui";
          "${alt}+Tab" = "exec --no-startup-id alt-tab-scratchpad toggle";
          "ctrl+${alt}+Tab" = "exec --no-startup-id alt-tab-scratchpad store";
          "${modifier}+space" = "exec --no-startup-id ${desktopMenuExe}";
          "${alt}+space" = "exec ${pkgs.rofi}/bin/rofi -show drun";
          "ctrl+${alt}+space" = "exec ${pkgs.rofi}/bin/rofi -show window";
        };
        floating = {
          inherit modifier;
          border = 2;
          criteria = [
            { class = "Handy"; }
            { class = "Thunar"; }
            { class = "opensnitch-ui"; }
            { class = "org.gnome.FileRoller"; }
            { instance = "copyq"; }
            { instance = "pavucontrol"; }
            { instance = "yad"; }
            { window_role = "pop-up"; }
            { window_role = "task_dialog"; }
            { window_type = "dialog"; }
            { window_type = "utility"; }
          ];
        };
        startup = [
          {
            always = true;
            command = "--no-startup-id ${pkgs-stable.xss-lock}/bin/xss-lock -l -- ${pkgs.lock}/bin/lock";
          }
          { command = "--no-startup-id ${pkgs.copyq}/bin/copyq"; }
          {
            command = "--no-startup-id ${pkgs-stable.flameshot}/bin/flameshot";
          }
          {
            always = true;
            command = "--no-startup-id ${pkgs.xmodmap}/bin/xmodmap ~/brain/config/dotfiles/xmodmap";
          }
          {
            always = true;
            command = "--no-startup-id ${pkgs.xset}/bin/xset -dpms";
          }
          {
            always = true;
            command = "--no-startup-id ${pkgs.xset}/bin/xset r rate 200 50";
          }
          {
            always = true;
            command = "--no-startup-id ${pkgs.xset}/bin/xset s off";
          }
          {
            always = true;
            command = "--no-startup-id ${pkgs.xset}/bin/xset m 0 0";
          }
          {
            always = true;
            command = "--no-startup-id ${pkgs.systemd}/bin/systemctl --user restart polybar";
          }
          {
            always = true;
            command = "--no-startup-id ${pkgs.feh}/bin/feh --bg-fill ~/.config/wallpaper";
            # "--no-startup-id ${pkgs.feh}/bin/feh --bg-fill ~/brain/config/assets/wallpaper";
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
        for_window [class="^Handy$"] border none
        for_window [window_type="notification"] border none
        for_window [instance="^condom-approval$"] floating enable, move position center
        for_window [class="^Gnome-screenshot$"] floating enable

        bindcode ${modifier}+110 exec thunar --window
        bindcode ${modifier}+118 exec ulimit -n 999999 && ${browserExe}
        bindcode ${modifier}+115 exec ulimit -n 999999 && ${browserExe}

        # workspaces: 3 bands x 5 columns per monitor, plus one global sys workspace
        ${workspaceOutputConfig}
        bindsym ${modifier}+1 exec --no-startup-id workspace-grid switch 1
        bindsym ${modifier}+2 exec --no-startup-id workspace-grid switch 2
        bindsym ${modifier}+3 exec --no-startup-id workspace-grid switch 3
        bindsym ${modifier}+4 exec --no-startup-id workspace-grid switch 4
        bindsym ${modifier}+5 exec --no-startup-id workspace-grid switch 5
        bindsym ${modifier}+0 workspace "${wsName sysNumber iconLeft sysLabel}"; workspace "${wsName sysNumber iconRight sysLabel}"; workspace "${wsName sysNumber iconCenter sysLabel}"

        # grid navigation
        bindsym ${modifier}+Up exec --no-startup-id workspace-grid up
        bindsym ${modifier}+Down exec --no-startup-id workspace-grid down
        bindsym ${modifier}+Left exec --no-startup-id workspace-grid left
        bindsym ${modifier}+Right exec --no-startup-id workspace-grid right
        bindsym ${modifier}+Shift+Up exec --no-startup-id workspace-grid move-up
        bindsym ${modifier}+Shift+Down exec --no-startup-id workspace-grid move-down
        bindsym ${modifier}+Shift+Left exec --no-startup-id workspace-grid move-left
        bindsym ${modifier}+Shift+Right exec --no-startup-id workspace-grid move-right

        # move to workspace
        bindsym ${modifier}+Shift+1 exec --no-startup-id workspace-grid move 1
        bindsym ${modifier}+Shift+2 exec --no-startup-id workspace-grid move 2
        bindsym ${modifier}+Shift+3 exec --no-startup-id workspace-grid move 3
        bindsym ${modifier}+Shift+4 exec --no-startup-id workspace-grid move 4
        bindsym ${modifier}+Shift+5 exec --no-startup-id workspace-grid move 5
        bindsym ${modifier}+Shift+0 move container to workspace "${wsName sysNumber iconCenter sysLabel}"

        # default to the first workspace
        exec --no-startup-id workspace-grid switch 1

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
  '';

  systemd.user.services = {
    setxkbmap.Service.ExecStart = lib.mkForce "${pkgs.coreutils}/bin/true";
    polybar.Install.WantedBy = lib.mkForce [ ];
  };
}
