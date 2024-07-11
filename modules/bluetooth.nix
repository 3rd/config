{ config, pkgs, options, ... }:

{

  environment.systemPackages = with pkgs; [ bluetuith ];
  hardware.bluetooth = {
    enable = true;
    package = pkgs.bluez;
    powerOnBoot = true;
    settings = {
      General = {
        ControllerMode = "bredr";
        FastConnectable = true;
        Experimental = true;
        KernelExperimental = true;
      };
      # LE = { EnableAdvMonInterleaveScan = 1; };
    };
  };
  services.blueman.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTRS{idProduct}=="0029", ATTR{authorized}="0"
  '';
}

