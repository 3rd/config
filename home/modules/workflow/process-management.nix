{ config, pkgs, ... }:

{
  home.packages = with pkgs;
    [
      procs # https://github.com/dalance/procs
    ];
}
