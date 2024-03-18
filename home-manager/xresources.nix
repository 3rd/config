{ config, lib, ... }:

{
  imports = [ ./colors.nix ];

  xresources.properties = with config.colors; {
    # settings
    "Xft.dpi" = lib.mkDefault 124;
    "Xft.autohint" = false;
    "Xft.hinting" = true;
    "Xft.hintstyle" = "hintslight";
    "Xft.lcdfilter" = "lcddefault";
    "Xft.rgba" = "rgb";
    "Xft.antialias" = true;
    # colors
    "*background" = background;
    "*foreground" = foreground;
    "*color0" = color0;
    "*color1" = color1;
    "*color2" = color2;
    "*color3" = color3;
    "*color4" = color4;
    "*color5" = color5;
    "*color6" = color6;
    "*color7" = color7;
    "*color8" = color8;
    "*color9" = color9;
    "*color10" = color10;
    "*color11" = color11;
    "*color12" = color12;
    "*color13" = color13;
    "*color14" = color14;
    "*color15" = color15;
    # xterm - https://wiki.archlinux.org/title/Xterm
    # "XTerm*faceName" = "xft:monospace:size=10";
    "XTerm*faceSize" = 10;
    "XTerm*background" = background;
    "XTerm*foreground" = foreground;
    "XTerm*color0" = color0;
    "XTerm*color1" = color1;
    "XTerm*color2" = color2;
    "XTerm*color3" = color3;
    "XTerm*color4" = color4;
    "XTerm*color5" = color5;
    "XTerm*color6" = color6;
    "XTerm*color7" = color7;
    "XTerm*color8" = color8;
    "XTerm*color9" = color9;
    "XTerm*color10" = color10;
    "XTerm*color11" = color11;
    "XTerm*color12" = color12;
  };
}
