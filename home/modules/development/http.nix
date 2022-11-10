{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    ht-rust # https://github.com/ducaale/xh
    miniserve # https://github.com/svenstaro/miniserve
  ];

  programs.fish.shellAliases = {
    http = "xh";
    serve = "miniserve";
  };
}
