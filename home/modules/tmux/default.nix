{ lib, pkgs, ... }:

let
  scripts = {
    tmux-workspace = pkgs.writeShellScriptBin "tmux-workspace"
      (builtins.readFile ./tmux-workspace.sh);
  };
in
{
  home.packages = with pkgs; [ scripts.tmux-workspace ];

  programs.tmux = {
    enable = true;
    package = pkgs.tmux.overrideAttrs (old: {
      src = pkgs.fetchFromGitHub {
        owner = "tmux";
        repo = "tmux";
        rev = "b0ff446727b0955dc3084d44b273497a74a85fe4";
        sha256 = "DFKo5yijq/jvGFGkr4EAX0rr3wVTzNdSG2JfNaEnRCU=";
      };
      patches = [
        (pkgs.fetchpatch {
          url =
            "https://github.com/tiagovla/tmux/commit/f4a851c9c1aca136ee85169ee9e52dc9e5576ac3.patch";
          sha256 = "1/WHJW4FTCzknm6BRSpsRnsxc1tWp5r/3N8BkqYrIZA=";
        })
      ];
    });
  };
  xdg.configFile."tmux/tmux.conf".source = ./tmux.conf;

  programs.fish.shellAliases = { t = "tmux-workspace"; };
}
