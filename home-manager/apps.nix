{ pkgs, pkgs-stable, ... }:

let
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
    pattern="''${apps_dir}/''${app}*.AppImage"

    files=( ''${pattern} )
    if [ ''${#files[@]} -eq 0 ]; then
      echo "DEBUG: No AppImage files found matching: ''${pattern}" >&2
      exit 1
    fi
    echo "DEBUG: Found AppImage file(s): ''${files[*]}" >&2

    exec appimage-run ''${files[0]}
  '';
  webWrapperDesktopItem = { name, url }:
    pkgs.makeDesktopItem {
      name = name;
      desktopName = name;
      exec = ''google-chrome-stable --app="'' + url + ''" %U'';
      terminal = false;
    };

  heptabaseDesktopItem = pkgs.makeDesktopItem {
    name = "heptabase";
    desktopName = "Heptabase";
    exec = "${appLaunchScript}/bin/app-launch heptabase";
    terminal = false;
    # mimetype="x-scheme-handler/x-protocol";
  };

  cursorDesktopItem = pkgs.makeDesktopItem {
    name = "cursor";
    desktopName = "Cursor";
    exec = "${appLaunchScript}/bin/app-launch cursor";
    terminal = false;
  };

  tanaDesktopItem = webWrapperDesktopItem {
    name = "Tana";
    url = "https://app.tana.inc";
  };

in {
  home.packages = [
    #
    appLaunchScript
    heptabaseDesktopItem
    cursorDesktopItem
    tanaDesktopItem
  ];
}
