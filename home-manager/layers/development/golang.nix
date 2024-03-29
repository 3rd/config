{ pkgs, ... }:

{
  home.packages = with pkgs; [ gotools golangci-lint ];

  programs.go = {
    enable = true;
    goPath = "go";
    goBin = "go/bin";
    # package = pkgs.go_1_21;
  };

  home.sessionPath = [ "$HOME/go/bin" ];

  programs.fish = {
    shellInit = ''
      set -x PATH $HOME/go/bin $PATH
    '';
  };
}
