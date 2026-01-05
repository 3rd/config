{ config, pkgs, ... }:

let journalPath = "$HOME/brain/wiki/journal";
in {
  home.packages = with pkgs; [ yad ];

  home.sessionVariables = { };

  xsession.windowManager.i3.config.keybindings = {
    "Mod3+d" = "exec --no-startup-id fish -c '~/.config/bin/journal-add'";
  };

  programs.fish.shellAliases = { j = "nvim ${journalPath}"; };
}
