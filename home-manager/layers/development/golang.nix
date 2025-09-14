{ pkgs, pkgs-stable, ... }:

{
  home.packages = with pkgs;
    [
      #
      gotools
      golangci-lint
      gotest
      gopls
    ] ++ (if (system == "x86_64-linux") then
      [
        #
        pkgs-stable.jetbrains.goland
      ]
    else
      [ ]);

  programs.go = {
    enable = true;
    env = {
      GOBIN = "go/bin";
      GOPATH = "go";
    };
    # package = pkgs.go_1_21;
  };

  home.sessionPath = [ "$HOME/go/bin" ];

  programs.fish = {
    shellInit = ''
      set -x PATH $HOME/go/bin $PATH
    '';
  };
}
