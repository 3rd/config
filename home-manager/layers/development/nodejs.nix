{ pkgs, pkgs-stable, ... }:

let
  nodejs = pkgs.nodejs_24;
in
{

  home.packages = with pkgs; [
    #
    nodejs
    electron
    dockerfile-language-server
    pkgs-stable.quick-lint-js
    tailwindcss-language-server
    typescript-language-server
    vscode-js-debug
    vscode-langservers-extracted
    yaml-language-server
    # bun
  ];

  home = {
    sessionVariables = {
      NODE_OPTIONS = "";
      ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    };
  };
}
