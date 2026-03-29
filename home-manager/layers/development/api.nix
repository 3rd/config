{ pkgs, pkgs-stable, ... }:

{
  home.packages =
    (with pkgs; [
      xh # https://github.com/ducaale/xh
      ngrok
      socat
    ])
    ++ (with pkgs-stable; [
      postman
    ]);

  programs.fish.shellAliases = {
    http = "xh";
  };
}
