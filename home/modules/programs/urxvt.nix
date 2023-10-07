{ lib, ... }:

{
  programs.urxvt = {
    enable = true;
    scroll = { lines = 100000; };
    transparent = false;
    # shading = 90;
    fonts = lib.mkDefault [
      #
      "xft:MonoLisa:size=10.8"
      "xft:Unifont:size=10.8"
      "xft:FiraCode Nerd Font Mono:size=10.8"
      "xft:DejaVu Sans Mono:size=10.8"
    ];
    keybindings = {
      "Shift-Control-C" = "eval:selection_to_clipboard";
      "Shift-Control-V" = "eval:paste_clipboard";
    };

  };
}
