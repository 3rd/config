{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    du-dust # https://github.com/bootandy/dust
    dua # https://github.com/Byron/dua-cli
    fclones # https://github.com/pkolaczk/fclones
    lfs # https://github.com/Canop/lfs
    rm-improved # https://github.com/nivekuil/rip
    xcp # https://github.com/tarka/xcp
  ];

  home.sessionVariables = { GRAVEYARD = "$HOME/.local/share/graveyard"; };

  programs.fish.shellAliases = {
    cp = "xcp";
    rm = "rip";
  };
}
