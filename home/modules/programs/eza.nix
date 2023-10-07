{
  programs.eza.enable = true;

  programs.fish.shellAliases = {
    l = "eza -l --group-directories-first";
    la = "eza -alBhg --group-directories-first --time-style long-iso";
    tree = "eza --tree --icons";
  };
}
