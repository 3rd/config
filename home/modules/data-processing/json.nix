{ config, pkgs, ... }:

{
  home.packages = with pkgs;
    [
      fx # https://github.com/antonmedv/fx
    ];
}
