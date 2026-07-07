{
  config,
  pkgs,
  options,
  lib,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    alsa-utils
    audacity
    pavucontrol
    sox
  ];

  # https://github.com/NixOS/nixpkgs/issues/102547
  # https://nixos.wiki/wiki/PipeWire - https://github.com/NixOS/nixpkgs/issues/220967
  security.rtkit.enable = lib.mkDefault true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    pulse.enable = true;
    # stop chromium/electron webrtc agc from changing the mic device volume system-wide
    extraConfig.pipewire-pulse."99-block-source-volume" = {
      "pulse.rules" = [
        {
          matches = [
            { "application.name" = "~Chromium.*"; }
            { "application.name" = "~Google Chrome.*"; }
            { "application.process.binary" = "chrome"; }
            { "application.process.binary" = "chromium"; }
            { "application.process.binary" = "electron"; }
            { "application.process.binary" = "~\\.?[Dd]iscord.*"; }
          ];
          actions.quirks = [ "block-source-volume" ];
        }
      ];
    };
    wireplumber = {
      enable = true;
      extraConfig = {
        "10-bluez" = {
          "monitor.bluez.properties" = {
            "bluez5.roles" = [
              "a2dp_source"
              "a2dp_sink"
            ];
            "bluez5.codecs" = [
              "aac"
              "sbc_xq"
              "sbc"
            ];
            "bluez5.autoswitch-profile" = false;
          };
        };
      };
    };
  };
}
