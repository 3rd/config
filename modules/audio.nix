{ config, pkgs, options, lib, ... }:

{
  environment.systemPackages = with pkgs; [ pulseaudioFull pavucontrol ];

  sound.enable = true;

  # https://github.com/NixOS/nixpkgs/issues/102547
  # https://nixos.wiki/wiki/PipeWire - https://github.com/NixOS/nixpkgs/issues/220967
  security.rtkit.enable = lib.mkDefault true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    jack.enable = true;
  };
}
