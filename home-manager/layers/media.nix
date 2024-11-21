{ pkgs, pkgs-stable, ... }:

{
  home.packages = [
    #
    pkgs.mpv
    pkgs-stable.ffmpeg-full
    # qimgv
  ] ++ (if (pkgs.system == "x86_64-linux") then
    [
      # davinci-resolve
    ]
  else
    [ ]);
}

