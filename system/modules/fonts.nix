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
          <!-- 2.017 ships with no fpgm/prep/cvt, so the bytecode interpreter
               has nothing to run and stems land off-grid at terminal sizes.
               hintfull was tried and distorts the outlines badly -->
          <match target="font">
              <test name="family">
                  <string>MonoLisa</string>
              </test>
              <edit name="autohint" mode="assign">
                  <bool>true</bool>
              </edit>
              <edit name="hintstyle" mode="assign">
                  <const>hintslight</const>
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
