{
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    changeDirWidget = {
      command = "fd --color always --hidden --follow --exclude .git --type d";
      options = [ "--ansi --preview 'eza --color always --tree {} | head -500'" ];
    };
    fileWidget = {
      command = "fd --color always --type f --hidden --follow --exclude .git";
      options = [
        "--ansi --preview-window=right:60% --preview 'bat --style=plain --color=always --line-range :500 {}'"
      ];
    };
  };
}
