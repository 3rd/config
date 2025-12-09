{ pkgs, pkgs-stable, ... }:

{
  home.packages = [
    #
    pkgs.mpv
    pkgs.espeak-ng
    pkgs-stable.ffmpeg-full
    # pkgs.qimgv
  ] ++ (if (pkgs.system == "x86_64-linux") then
    [
      # davinci-resolve
    ]
  else
    [ ]);
}

