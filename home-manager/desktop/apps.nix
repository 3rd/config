{
  lib,
  pkgs,
  config,
  ...
}:

let
  browserExe = lib.getExe config.programs.chromium.package;
  appLaunchScript = pkgs.writeScriptBin "app-launch" ''
    #! ${pkgs.bash}/bin/bash
    set -e
    set -x
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 <app-image-search-string>" >&2
      exit 1
    fi
    app="$1"
    apps_dir="$HOME/apps"

    shopt -s nocaseglob
    pattern="''${apps_dir}/''${app}*.AppImage"
    files=( ''${pattern} )

    if [ ''${#files[@]} -eq 1 ] && [ ! -f "''${files[0]}" ]; then
      echo "DEBUG: No AppImage files found matching: ''${pattern}" >&2
      exit 1
    fi

    echo "DEBUG: Found AppImage file(s): ''${files[*]}" >&2
    exec appimage-run ''${files[0]}
  '';
  webWrapperDesktopItem =
    {
      name,
      desktopName ? name,
      url,
    }:
    pkgs.makeDesktopItem {
      inherit name desktopName;
      exec = ''${browserExe} --app="'' + url + ''" %U'';
      terminal = false;
    };

  cursorDesktopItem = pkgs.makeDesktopItem {
    name = "cursor";
    desktopName = "Cursor";
    exec = "${appLaunchScript}/bin/app-launch cursor";
    terminal = false;
  };

  handyDesktopItem = pkgs.makeDesktopItem {
    name = "stt-handy";
    desktopName = "Handy - Speech to Text";
    exec = "${appLaunchScript}/bin/app-launch handy";
    terminal = false;
  };

  heptabaseDesktopItem = pkgs.makeDesktopItem {
    name = "heptabase";
    desktopName = "Heptabase";
    exec = "${appLaunchScript}/bin/app-launch heptabase";
    terminal = false;
  };

  excalidrawDesktopItem = webWrapperDesktopItem {
    name = "excalidraw";
    desktopName = "Excalidraw";
    url = "https://app.excalidraw.com";
  };

  ytmusicDesktopItem = webWrapperDesktopItem {
    name = "ytmusic";
    desktopName = "YouTube Music";
    url = "https://music.youtube.com";
  };

  figmaDesktopItem = webWrapperDesktopItem {
    name = "figma";
    desktopName = "Figma";
    url = "https://figma.com";
  };

  chefDesktopItem = webWrapperDesktopItem {
    name = "chef";
    desktopName = "CyberChef";
    url = "https://gchq.github.io/CyberChef";
  };

in
{
  home.packages = [
    appLaunchScript
    cursorDesktopItem
    handyDesktopItem
    excalidrawDesktopItem
    ytmusicDesktopItem
    figmaDesktopItem
    chefDesktopItem
    heptabaseDesktopItem
  ];
}
