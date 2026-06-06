{ pkgs, ... }:

{
  home.packages = with pkgs; [
    #
    bash-language-server
    shfmt
    shellcheck
  ];
}
