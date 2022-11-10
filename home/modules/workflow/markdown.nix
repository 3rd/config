{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    inlyne # https://github.com/trimental/inlyne
    mdbook # https://github.com/rust-lang/mdBook
    mdcat # https://github.com/lunaryorn/mdcat
  ];
}
