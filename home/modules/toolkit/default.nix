{ config, pkgs, ... }:

{
  home.packages = with pkgs;
    [
      lemmeknow # https://github.com/swanandx/lemmeknow
    ];
}
