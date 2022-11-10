{ config, pkgs, ... }:

{
  home.packages = with pkgs;
    [
      xsv # https://github.com/BurntSushi/xsv
    ];
}
