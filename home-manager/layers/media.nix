{ pkgs, ... }:

with pkgs; {
  home.packages = [
    #
    ffmpeg-full
    mpv
    pitivi
    qimgv
  ] ++ (if (system == "x86_64-linux") then
    [
      # davinci-resolve
    ]
  else
    [ ]);
}

