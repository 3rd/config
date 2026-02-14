{ pkgs, pkgs-stable, config, ... }:

let
  fhsEnv = pkgs.buildFHSEnv (pkgs.appimageTools.defaultFhsEnvArgs // {
    name = "fhs";
    profile = "export FHS=1";
    runScript = ''fish -c "$@"'';
  });
  fhsBin = "${fhsEnv}/bin/fhs";
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
  webWrapperDesktopItem = { name, url }:
    pkgs.makeDesktopItem {
      name = name;
      desktopName = name;
      exec = ''google-chrome-stable --app="'' + url + ''" %U'';
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

  excalidrawDesktopItem = webWrapperDesktopItem {
    name = "excalidraw";
    url = "https://app.excalidraw.com";
  };

in {
  home.packages = [
    #
    appLaunchScript
    cursorDesktopItem
    handyDesktopItem
    excalidrawDesktopItem
  ];
}
