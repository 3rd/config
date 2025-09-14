{ config, pkgs, pkgs-stable, ... }:

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
      GOPATH = "${config.home.homeDirectory}/go";
      GOBIN = "${config.home.homeDirectory}/go/bin";
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
