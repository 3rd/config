{ pkgs, ... }:

{
  home.packages = with pkgs; [
    #
    shfmt
    shellcheck
  ];
}

