{ pkgs, ... }:

{
  home.packages = with pkgs; [
    #
    vscodium
    rust-petname
  ];
}
