{ config, pkgs, ... }:

{
  # https://github.com/NixOS/nixpkgs/pull/305975
  # nixpkgs.config.joypixels.acceptLicense = true;
  fonts = {
    fontDir.enable = true;
    fontconfig = {
      enable = true;
      cache32Bit = true;
      antialias = true;
      subpixel = {
        lcdfilter = "default";
        rgba = "rgb";
      };
      hinting = {
        enable = true;
        autohint = false;
        style = "full";
      };
      defaultFonts = {
        monospace = [ "Berkeley Mono" "FiraCode Nerd Font Mono" ];
        sansSerif = [ "DejaVu Sans" "Noto Sans" "FiraCode Nerd Font Mono" ];
        serif = [
          "Linux Libertine"
          "DejaVu Serif"
          "Noto Serif"
          "FiraCode Nerd Font Mono"
        ];
        emoji = [
          # "JoyPixels"
          "Noto Color Emoji"
          "FiraCode Nerd Font Mono"
        ];
      };
      localConf = ''
        <fontconfig>
          <!-- because buying MonoLisa gets you no support -->
          <match target="scan">
              <test name="family">
                  <string>MonoLisa</string>
              </test>
              <edit name="spacing">
                  <int>100</int>
              </edit>
          </match>
          <match target="scan">
              <test name="family">
                  <string>Monaspace Neon</string>
              </test>
              <edit name="spacing">
                  <int>100</int>
              </edit>
          </match>
        </fontconfig>
      '';
    };

    packages = with pkgs; [
      # corefonts
      dejavu_fonts
      fira
      fira-code
      fira-code-symbols
      font-awesome
      inconsolata
      inter

      # joypixels
      noto-fonts
      noto-fonts-color-emoji
      symbola
      unifont
      nerd-fonts.fira-code
      nerd-fonts.symbols-only
    ];
  };
}
