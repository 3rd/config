{
  config,
  pkgs,
  options,
  ...
}:

{

  environment.systemPackages = with pkgs; [ bluetuith ];
  hardware.bluetooth = {
    enable = true;
    package = pkgs.bluez;
    powerOnBoot = true;
    settings = {
      General = {
        ControllerMode = "dual";
        FastConnectable = true;
        Experimental = true;
        KernelExperimental = true;
      };
      LE = {
        EnableAdvMonInterleaveScan = 1;
      };
    };
  };
  services.blueman.enable = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="8087", ATTR{idProduct}=="0029", ATTR{authorized}="0"
  '';
}
