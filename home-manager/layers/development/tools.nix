{ pkgs, ... }:

{
  home.packages = with pkgs; [
    #
    sqlite
    vscodium
    rust-petname
    jq
    evemu
    ast-grep
    ncdu
  ];
}
