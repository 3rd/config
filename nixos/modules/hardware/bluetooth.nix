{ config, pkgs, options, ... }:

{
  hardware.bluetooth = {
    enable = true;
    package = pkgs.bluez;
    settings = { General = { Enable = "Source,Sink,Media,Socket"; }; };
  };
  services.blueman.enable = true;
}
