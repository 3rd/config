{ config, pkgs, ... }:

{
  home.packages = with pkgs;
    [
      sd # https://github.com/chmln/sd
    ];
}
