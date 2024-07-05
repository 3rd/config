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
    wireplumber = {
      enable = true;
      extraConfig = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
          "bluez5.enable-hw-volume" = true;
          "bluez5.roles" = [
            # "hsp_hs"
            # "hsp_ag"
            "hfp_hf"
            "hfp_ag"
          ];
          "bluez5.auto-connect" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
          "bluez5.profile" = "a2dp-sink";
          "bluez5.autoswitch-profile" = false;
        };
      };
    };
    # jack.enable = true;
  };
}
