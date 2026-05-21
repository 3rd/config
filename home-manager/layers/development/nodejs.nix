{ pkgs, pkgs-stable, ... }:

let
  nodejs = pkgs.nodejs_24;
in
{

  home.packages = with pkgs; [
    #
    nodejs
    electron
    pkgs-stable.quick-lint-js
    # bun
  ];

  home = {
    sessionVariables = {
      NODE_OPTIONS = "";
      ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    };
  };
}
