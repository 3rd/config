{ pkgs, ... }:

{
  home.packages = with pkgs; [ cargo rustc ];

  home.sessionPath = [ "$HOME/.cargo/bin" ];

  programs.fish = {
    shellInit = ''
      set -x PATH $HOME/.cargo/bin $PATH
    '';
  };
}
