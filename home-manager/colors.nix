{ config, lib, ... }:

with lib;

{
  options.colors =
    let
      mkColorOption = name: {
        inherit name;
        value = mkOption {
          type = types.strMatching "#[a-fA-F0-9]{6}";
          description = "Color ${name}.";
        };
      };
    in
    listToAttrs (
      map mkColorOption [
        "background"
        "panel-background"
        "overlay-background"
        "overlay-active-background"
        "overlay-selected-background"
        "foreground"
        "cursor"
        "selection-background"
        "selection-foreground"

        "accent"
        "accent-dark"

        "gray-lightest"
        "gray-lighter"
        "gray-light"
        "gray-medium"
        "gray-darkish"
        "gray-dark"
        "gray-darker"
        "gray-darkest"

        "blue-lightest"
        "blue-lighter"
        "blue-light"
        "blue-medium"
        "blue-darkish"
        "blue-dark"
        "blue-darker"
        "blue-darkest"

        "cyan-lightest"
        "cyan-lighter"
        "cyan-light"
        "cyan-medium"
        "cyan-darkish"
        "cyan-dark"
        "cyan-darker"
        "cyan-darkest"

        "green-lightest"
        "green-lighter"
        "green-light"
        "green-medium"
        "green-darkish"
        "green-dark"
        "green-darker"
        "green-darkest"

        "indigo-lightest"
        "indigo-lighter"
        "indigo-light"
        "indigo-medium"
        "indigo-darkish"
        "indigo-dark"
        "indigo-darker"
        "indigo-darkest"

        "magenta-lightest"
        "magenta-lighter"
        "magenta-light"
        "magenta-medium"
        "magenta-darkish"
        "magenta-dark"
        "magenta-darker"
        "magenta-darkest"

        "orange-lightest"
        "orange-lighter"
        "orange-light"
        "orange-medium"
        "orange-darkish"
        "orange-dark"
        "orange-darker"
        "orange-darkest"

        "red-lightest"
        "red-lighter"
        "red-light"
        "red-medium"
        "red-darkish"
        "red-dark"
        "red-darker"
        "red-darkest"

        "yellow-lightest"
        "yellow-lighter"
        "yellow-light"
        "yellow-medium"
        "yellow-darkish"
        "yellow-dark"
        "yellow-darker"
        "yellow-darkest"

        "color0"
        "color1"
        "color2"
        "color3"
        "color4"
        "color5"
        "color6"
        "color7"
        "color8"
        "color9"
        "color10"
        "color11"
        "color12"
        "color13"
        "color14"
        "color15"
      ]
    );

  config = {
    colors = rec {
      background = "#202023";
      panel-background = "#252528";
      overlay-background = "#373639";
      overlay-active-background = "#403F43";
      overlay-selected-background = "#46434F";
      foreground = "#DEDEEC";
      cursor = color11;
      selection-background = "#323039";
      selection-foreground = "#F3F2F5";

      accent = color5;
      accent-dark = magenta-darkest;

      gray-lightest = "#A3A1AD";
      gray-lighter = "#928F9F";
      gray-light = "#807D8F";
      gray-medium = "#6C687D";
      gray-darkish = "#3B3945";
      gray-dark = selection-background;
      gray-darker = "#2C2A33";
      gray-darkest = background;

      blue-lightest = "#99DDFF";
      blue-lighter = "#86D7FF";
      blue-light = color12;
      blue-medium = color4;
      blue-darkish = "#33A2D7";
      blue-dark = "#348AB6";
      blue-darker = "#326D8F";
      blue-darkest = "#2E536B";

      cyan-lightest = "#9BF5ED";
      cyan-lighter = "#83F5EB";
      cyan-light = color14;
      cyan-medium = color6;
      cyan-darkish = "#32BEB5";
      cyan-dark = "#379F9A";
      cyan-darker = "#377D7A";
      cyan-darkest = "#345D5D";

      green-lightest = "#B0ECA1";
      green-lighter = "#9FEB8B";
      green-light = color10;
      green-medium = color2;
      green-darkish = "#65B94E";
      green-dark = "#5A9B49";
      green-darker = "#4D7B42";
      green-darkest = "#405B39";

      indigo-lightest = "#C7CCFC";
      indigo-lighter = "#BEC3FE";
      indigo-light = "#B6BBFF";
      indigo-medium = "#9B9AF9";
      indigo-darkish = "#8786D6";
      indigo-dark = "#7473B4";
      indigo-darker = "#5E5D8D";
      indigo-darkest = "#494869";

      magenta-lightest = "#E9BAFC";
      magenta-lighter = "#E7ADFE";
      magenta-light = color13;
      magenta-medium = color5;
      magenta-darkish = "#B264DB";
      magenta-dark = "#9659B8";
      magenta-darker = "#774B90";
      magenta-darkest = "#593D6B";

      orange-lightest = "#FDBE9F";
      orange-lighter = "#FEB38C";
      orange-light = "#FFA779";
      orange-medium = "#FC8D5A";
      orange-darkish = "#D87C53";
      orange-dark = "#B56B4D";
      orange-darker = "#8D5844";
      orange-darkest = "#68453B";

      red-lightest = "#FFA0A5";
      red-lighter = "#FF8E95";
      red-light = color9;
      red-medium = color1;
      red-darkish = "#DB525D";
      red-dark = "#B84B53";
      red-darker = "#904248";
      red-darkest = "#6A383D";

      yellow-lightest = "#FBDC96";
      yellow-lighter = "#FDD680";
      yellow-light = color11;
      yellow-medium = color3;
      yellow-darkish = "#D2A043";
      yellow-dark = "#AF8841";
      yellow-darker = "#896C3E";
      yellow-darkest = "#645238";

      color0 = gray-darker;
      color1 = "#FF5967";
      color2 = "#6CDB4D";
      color3 = "#F5B942";
      color4 = "#31BBF8";
      color5 = "#CE70FF";
      color6 = "#25DDD2";
      color7 = "#CAC8D0";
      color8 = gray-medium;
      color9 = "#FF7A85";
      color10 = "#8CED71";
      color11 = "#FFD166";
      color12 = "#70D2FF";
      color13 = "#E5A0FF";
      color14 = "#65F5EA";
      color15 = selection-foreground;
    };

    xdg.configFile."theme/colors.json".text = builtins.toJSON config.colors;
  };
}
