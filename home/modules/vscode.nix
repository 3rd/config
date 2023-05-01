{ config, pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    userSettings = { "editor.tabSize" = 2; };
    # extensions = with pkgs.vscode-extensions; [ bbenoist.nix ];
  };
}
