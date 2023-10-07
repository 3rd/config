{ config, pkgs, ... }:

let journalPath = "$HOME/brain/wiki/journal";
in {
  home.packages = with pkgs; [ yad ];

  home.sessionVariables = { };

  xsession.windowManager.i3.config.keybindings = {
    "Mod3+d" = "exec ~/.config/bin/workflow/journal-add";
  };

  programs.fish.shellAliases = { j = "nvim ${journalPath}"; };
}
