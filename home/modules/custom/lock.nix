{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      # lock = super.writeScriptBin "lock" ''
      #   #!${pkgs.bash}/bin/bash
      #
      #   IMAGE=/tmp/i3lock.png
      #   BLURTYPE="0x6" # 2.90s
      #   ${pkgs.scrot}/bin/scrot "$IMAGE"
      #
      #   # ${pkgs.imagemagick}/bin/convert $IMAGE -blur $BLURTYPE $IMAGE
      #   ${pkgs.i3lock}/bin/i3lock -i $IMAGE
      #   ${pkgs.coreutils}/bin/rm $IMAGE
      #   ${pkgs.i3}/bin/i3 mode default
      # '';
      lock = super.writeScriptBin "lock" ''
        #!${pkgs.bash}/bin/bash

        SCREEN_RESOLUTION="$(${pkgs.xorg.xdpyinfo}/bin/xdpyinfo | ${pkgs.gnugrep}/bin/grep dimensions | cut -d' ' -f7)"
        BGCOLOR="000000"
        ${pkgs.imagemagick}/bin/convert ~/brain/config/home/lock.png -gravity Center -background $BGCOLOR -extent "$SCREEN_RESOLUTION" RGB:- | ${pkgs.i3lock}/bin/i3lock --raw "$SCREEN_RESOLUTION":rgb -c $BGCOLOR -i /dev/stdin

        # ${pkgs.i3lock}/bin/i3lock -t -i ~/brain/config/home/lock.png
        ${pkgs.i3}/bin/i3 mode default
      '';
    })
  ];

  home.packages = with pkgs; [ lock i3lock scrot xss-lock ];

  # lock on suspend
  xsession.windowManager.i3.config.startup = [{
    always = true;
    command =
      "--no-startup-id ${pkgs.xss-lock}/bin/xss-lock -l -- ${pkgs.lock}/bin/lock";
  }];
}
