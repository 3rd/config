{ pkgs, ... }:

{
  home.packages = with pkgs; [
    rust-petname
    tealdeer # https://github.com/dbrgn/tealdeer
    rlwrap
    tree-sitter
  ];
}
