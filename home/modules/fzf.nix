{ config, pkgs, ... }:

{
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    changeDirWidgetCommand =
      "fd --color always --hidden --follow --exclude .git --type d";
    changeDirWidgetOptions =
      [ "--ansi --preview 'eza --color always --tree {} | head -500'" ];
    fileWidgetCommand =
      "fd --color always --type f --hidden --follow --exclude .git";
    fileWidgetOptions = [
      "--ansi --preview-window=right:60% --preview 'bat --style=plain --color=always --line-range :500 {}'"
    ];
  };
}
