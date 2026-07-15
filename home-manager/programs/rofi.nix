{
  config,
  pkgs,
  pkgs-stable,
  ...
}:

let
  colors = config.colors;
  inherit (config.lib.formats.rasi) mkLiteral;
in

{
  imports = [ ../colors.nix ];

  programs.rofi = {
    enable = true;
    font = "DejaVu Sans 14";
    location = "center";
    theme = {
      "*" = {
        accent = mkLiteral colors.accent;
        active-background = mkLiteral colors.gray-dark;
        background = mkLiteral colors.gray-dark;
        divider = mkLiteral colors.gray-medium;
        foreground = mkLiteral colors.foreground;
        secondary = mkLiteral colors.selection-foreground;
        selected-background = mkLiteral colors.gray-medium;
        urgent-background = mkLiteral colors.red-darkest;
        urgent-foreground = mkLiteral colors.red-lightest;
        urgent-selected-background = mkLiteral colors.red-darker;
      };

      window = {
        background-color = mkLiteral "@background";
        border = mkLiteral "3px";
        border-color = mkLiteral "@divider";
        padding = mkLiteral "8px";
      };

      mainbox = {
        background-color = mkLiteral "@background";
        spacing = 0;
      };

      inputbar = {
        background-color = mkLiteral "@background";
        border = mkLiteral "0px 0px 1px 0px";
        border-color = mkLiteral "@divider";
        children = map mkLiteral [
          "prompt"
          "textbox-prompt-colon"
          "entry"
          "case-indicator"
        ];
        padding = mkLiteral "8px";
        spacing = mkLiteral "8px";
        text-color = mkLiteral "@foreground";
      };

      prompt = {
        background-color = mkLiteral "@background";
        text-color = mkLiteral "@secondary";
      };

      "textbox-prompt-colon" = {
        background-color = mkLiteral "@background";
        expand = false;
        str = ":";
        text-color = mkLiteral "@secondary";
      };

      entry = {
        background-color = mkLiteral "@background";
        text-color = mkLiteral "@foreground";
      };

      "case-indicator" = {
        background-color = mkLiteral "@background";
        text-color = mkLiteral "@secondary";
      };

      listview = {
        background-color = mkLiteral "@background";
        border = 0;
        fixed-height = true;
        lines = 13;
        padding = mkLiteral "4px 0px 0px 0px";
        scrollbar = true;
        spacing = mkLiteral "2px";
      };

      element = {
        background-color = mkLiteral "@background";
        border = 0;
        padding = mkLiteral "6px 8px";
        spacing = mkLiteral "8px";
        text-color = mkLiteral "@foreground";
      };

      "element-icon" = {
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "inherit";
      };

      "element-text" = {
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "inherit";
      };

      "element.normal.normal" = {
        background-color = mkLiteral "@background";
        text-color = mkLiteral "@foreground";
      };

      "element.alternate.normal" = {
        background-color = mkLiteral "@background";
        text-color = mkLiteral "@foreground";
      };

      "element.normal.active" = {
        background-color = mkLiteral "@active-background";
        text-color = mkLiteral "@foreground";
      };

      "element.alternate.active" = {
        background-color = mkLiteral "@active-background";
        text-color = mkLiteral "@foreground";
      };

      "element.normal.urgent" = {
        background-color = mkLiteral "@urgent-background";
        text-color = mkLiteral "@urgent-foreground";
      };

      "element.alternate.urgent" = {
        background-color = mkLiteral "@urgent-background";
        text-color = mkLiteral "@urgent-foreground";
      };

      "element.selected.normal" = {
        background-color = mkLiteral "@selected-background";
        text-color = mkLiteral "@foreground";
      };

      "element.selected.active" = {
        background-color = mkLiteral "@selected-background";
        text-color = mkLiteral "@foreground";
      };

      "element.selected.urgent" = {
        background-color = mkLiteral "@urgent-selected-background";
        text-color = mkLiteral "@urgent-foreground";
      };

      scrollbar = {
        background-color = mkLiteral "@active-background";
        border = 0;
        handle-color = mkLiteral "@secondary";
        handle-width = mkLiteral "6px";
        padding = 0;
        width = mkLiteral "6px";
      };

      message = {
        background-color = mkLiteral "@background";
        border = mkLiteral "1px 0px 0px 0px";
        border-color = mkLiteral "@divider";
        padding = mkLiteral "8px";
      };

      textbox = {
        background-color = mkLiteral "@background";
        text-color = mkLiteral "@foreground";
      };

      "error-message" = {
        background-color = mkLiteral "@urgent-background";
        padding = mkLiteral "8px";
        text-color = mkLiteral "@urgent-foreground";
      };

      "mode-switcher" = {
        background-color = mkLiteral "@background";
        border = mkLiteral "1px 0px 0px 0px";
        border-color = mkLiteral "@divider";
        spacing = mkLiteral "2px";
      };

      button = {
        background-color = mkLiteral "@background";
        border = mkLiteral "0px 0px 2px 0px";
        border-color = mkLiteral "@background";
        padding = mkLiteral "6px 8px";
        text-color = mkLiteral "@secondary";
      };

      "button.selected" = {
        background-color = mkLiteral "@selected-background";
        border-color = mkLiteral "@accent";
        text-color = mkLiteral "@foreground";
      };
    };
    package =
      with pkgs-stable;
      rofi.override {
        plugins = [
          rofi-calc
          rofi-file-browser
        ];
      };
  };
}
