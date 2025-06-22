{ lib, ... }:

with lib; {
  options.colors = let
    mkColorOption = name: {
      inherit name;
      value = mkOption {
        type = types.strMatching "#[a-fA-F0-9]{6}";
        description = "Color ${name}.";
      };
    };
  in listToAttrs (map mkColorOption [
    "background"
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
  ]);
}
