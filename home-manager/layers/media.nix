{ pkgs, ... }:

with pkgs; {
  home.packages = [
    #
    ffmpeg-full
    mpv
    qimgv
  ] ++ (if (system == "x86_64-linux") then
    [
      # davinci-resolve
    ]
  else
    [ ]);
}

