{ pkgs, ... }:

let
  scripts = {
    tmux-workspace = pkgs.writeShellScriptBin "tmux-workspace"
      (builtins.readFile ./tmux-workspace.sh);
  };
in {

  # https://github.com/nix-community/home-manager/blob/master/modules/programs/tmux.nix
  # programs.tmux = { enable = true; };
  # xdg.configFile."tmux/tmux.conf".source = ./tmux.conf;

  home.packages = with pkgs; [ tmux tmuxp scripts.tmux-workspace ];
  programs.fish.shellAliases = { t = "tmux-workspace"; };
}
