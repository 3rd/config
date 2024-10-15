{ pkgs, ... }:

{
  xdg.desktopEntries = {
    excalidraw = {
      type = "Application";
      name = "Excalidraw";
      exec = ''sh -c "\\$BROWSER --app='https://app.excalidraw.com'"'';
      terminal = false;
    };
    ytmusic = {
      type = "Application";
      name = "YouTube Music";
      exec = ''sh -c "\\$BROWSER --app='https://music.youtube.com'"'';
      terminal = false;
    };
    figma = {
      type = "Application";
      name = "Figma";
      exec = ''sh -c "\\$BROWSER --app='https://figma.com'"'';
      terminal = false;
    };
    chef = {
      type = "Application";
      name = "CyberChef";
      exec = ''sh -c "\\$BROWSER --app='https://gchq.github.io/CyberChef'"'';
      terminal = false;
    };
  };
}

