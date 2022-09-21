{ config, pkgs, options, ... }:

{
  # nixpkgs.config.pulseudio = true;

  sound.enable = true;
  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
    # extraModules = [ pkgs.pulseaudio-modules-bt ];
    support32Bit = true;
    extraConfig = ''
      load-module module-bluetooth-policy auto_switch=0
    '';
  };
}
