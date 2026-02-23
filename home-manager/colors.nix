{ lib, ... }:

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

  config.colors = {
    # background = "#1c1d22";
    # background = "#1E1F27";
    # background = "#1e1f29";
    # background = "#21222c";
    # background = "#23212c";
    background = "#201f25";
    # background = "#201e24";
    foreground = "#DCD9E4";
    cursor = "#f2b90d";
    selection-background = "#303233";
    selection-foreground = "#cacecd";

    accent = "#c20a5d";
    accent-dark = "#f1052f";

    gray-lightest = "#8D8A9C";
    gray-lighter = "#848095";
    gray-light = "#7C788D";
    gray-medium = "#4C495E";
    gray-darkish = "#3C394A";
    gray-dark = "#32313E";
    gray-darker = "#2D2A37";
    gray-darkest = "#23222C";

    blue-lightest = "#9cdcfc";
    blue-lighter = "#6acbfb";
    blue-light = "#38b9fa";
    blue-medium = "#06a8f9";
    blue-dark = "#0586c7";
    blue-darker = "#046595";
    blue-darkest = "#034363";

    cyan-lightest = "#9efafa";
    cyan-lighter = "#6ef7f7";
    cyan-light = "#3df5f5";
    cyan-medium = "#0df2f2";
    cyan-dark = "#0ac2c2";
    cyan-darker = "#089191";
    cyan-darkest = "#056161";

    green-lightest = "#ccf5a3";
    green-lighter = "#b3f075";
    green-light = "#99eb47";
    green-medium = "#80e619";
    green-dark = "#66b814";
    green-darker = "#4d8a0f";
    green-darkest = "#335c0a";

    indigo-lightest = "#9e9efa";
    indigo-lighter = "#6e6ef7";
    indigo-light = "#3d3df5";
    indigo-medium = "#0d0df2";
    indigo-dark = "#0a0ac2";
    indigo-darker = "#080891";
    indigo-darkest = "#050561";

    magenta-lightest = "#eb9efa";
    magenta-lighter = "#e06ef7";
    magenta-light = "#d63df5";
    magenta-medium = "#cc0df2";
    magenta-dark = "#a30ac2";
    magenta-darker = "#7a0891";
    magenta-darkest = "#520561";

    orange-lightest = "#fac49e";
    orange-lighter = "#f7a76e";
    orange-light = "#ff974d";
    orange-medium = "#f26c0d";
    orange-dark = "#c2570a";
    orange-darker = "#914108";
    orange-darkest = "#612b05";

    red-lightest = "#faad9e";
    red-lighter = "#f67055";
    red-light = "#f55c3d";
    red-medium = "#f2330d";
    red-dark = "#c2290a";
    red-darker = "#911f08";
    red-darkest = "#611405";

    yellow-lightest = "#fae39e";
    yellow-lighter = "#f7d56e";
    yellow-light = "#f5c73d";
    yellow-medium = "#f2b90d";
    yellow-dark = "#c2940a";
    yellow-darker = "#916f08";
    yellow-darkest = "#614a05";

    color0 = "#3D364E";
    color8 = "#504766";
    color1 = "#c2290a";
    color9 = "#f2330d";
    color2 = "#66b814";
    color10 = "#80e619";
    color3 = "#daa60b";
    color11 = "#f6ce55";
    color4 = "#06a8f9";
    color12 = "#38b9fa";
    color5 = "#e06ef7";
    color13 = "#eb9efa";
    color6 = "#0ac2c2";
    color14 = "#0df2f2";
    color7 = "#D1C9E2";
    color15 = "#E3DFEA";
  };
}
