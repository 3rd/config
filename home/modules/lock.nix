{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      lock = super.writeScriptBin "lock" ''
        #!${pkgs.bash}/bin/bash

        IMAGE=/tmp/i3lock.png
        BLURTYPE="0x6" # 2.90s
        ${pkgs.scrot}/bin/scrot "$IMAGE"

        ${pkgs.imagemagick}/bin/convert $IMAGE -blur $BLURTYPE $IMAGE
        ${pkgs.i3lock}/bin/i3lock -i $IMAGE
        ${pkgs.coreutils}/bin/rm $IMAGE
      '';
    })
  ];

  home.packages = with pkgs; [ lock imagemagick i3lock scrot ];
}
