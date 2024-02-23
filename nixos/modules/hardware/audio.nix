{ config, pkgs, options, ... }:

{
  sound.enable = true;
  # hardware.pulseaudio = {
  #   enable = true;
  #   package = pkgs.pulseaudioFull;
  #   support32Bit = true;
  #   extraConfig = ''
  #     load-module module-bluetooth-policy auto_switch=0
  #   '';
  # };

  # https://github.com/NixOS/nixpkgs/issues/102547
  # https://nixos.wiki/wiki/PipeWire - https://github.com/NixOS/nixpkgs/issues/220967
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    jack.enable = true;
  };
  environment.etc = {
    "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
      bluez_monitor.properties = {
        ["bluez5.enable-sbc-xq"] = true,
        ["bluez5.enable-msbc"] = true,
        ["bluez5.enable-hw-volume"] = true,
        ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
      }
    '';
    "pipewire/pipewire.conf.d/92-low-latency.conf".text = ''
      context.properties = {
        default.clock.rate = 48000
        default.clock.quantum = 32
        default.clock.min-quantum = 32
        default.clock.max-quantum = 32
      }
    '';
  };
  environment.systemPackages = with pkgs;
    [
      # for pactl, but superseded by pw-cli, pw-mon, pw-top, wpctl
      pulseaudioFull
    ];
}
