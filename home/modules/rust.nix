{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [ rustup ];

  home.sessionPath = [ "$HOME/.cargo/bin" ];

  programs.fish = {
    shellInit = ''
      set -x PATH $HOME/.cargo/bin $PATH
    '';
  };
}
