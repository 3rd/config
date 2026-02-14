{ config, pkgs, options, ... }:

{
  environment.systemPackages = with pkgs; [
    #
    libinput
    xclip
    xsel
    wmctrl
    xdotool
    xdpyinfo
    xev
    xhost
    xkill
    xmodmap
    xwininfo
  ];

  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
      synaptics.enable = false;
    };
    libinput = {
      enable = true;
      mouse.accelProfile = "flat";
      touchpad = {
        clickMethod = "clickfinger";
        disableWhileTyping = true;
        tapping = true;
        additionalOptions = ''
          Option "PalmDetection" "on"
        '';
      };
    };
  };
}

