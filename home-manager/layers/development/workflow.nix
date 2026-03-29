{ pkgs, ... }:

{
  home.packages = with pkgs; [
    just # https://github.com/casey/just
    watchexec # https://github.com/watchexec/watchexec
    sd # https://github.com/chmln/sd
    grex # https://github.com/pemistahl/grex
    execline
    delta
  ];
}
