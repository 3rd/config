{ config, pkgs, options, ... }:

{
  environment.systemPackages = with pkgs; [
    #
    libinput
    xclip
    xsel
    wmctrl
    xdotool
    xfce.tumbler
    xorg.xdpyinfo
    xorg.xev
    xorg.xhost
    xorg.xkill
    xorg.xmodmap
  ];

  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
    };
    libinput = {
      enable = true;
      mouse.accelProfile = "flat";
      touchpad = {
        disableWhileTyping = true;
        tapping = false;
        additionalOptions = ''
          Option "PalmDetection" "on"
        '';
      };
    };
  };
}

