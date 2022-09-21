{ pkgs, ... }:

{
  programs.exa.enable = true;

  programs.fish.shellAliases = {
    l = "exa -l --group-directories-first";
    la = "exa -alBhg --group-directories-first --time-style long-iso";
    tree = "exa --tree --icons";
  };
}
