{ config, pkgs, options, ... }:

{
  nixpkgs.config.joypixels.acceptLicense = true;
  fonts = {
    enableDefaultFonts = true;
    fontDir.enable = true;
    # https://wiki.archlinux.org/title/font_configuration
    fontconfig = {
      enable = true;
      cache32Bit = true;
      antialias = true;
      subpixel = {
        lcdfilter = "default"; # light
        rgba = "rgb";
      };
      hinting = {
        enable = true;
        autohint = false;
        style = "full"; # slight
      };
      defaultFonts = {
        # monospace = [ "MonoLisa" "Symbols Nerd Font Mono" ];
        monospace = [ "MonoLisa" "Fira Code Nerd Font Mono" ];
        sansSerif = [ "DejaVu Sans" "Noto Sans" "Fira Code Nerd Font Mono" ];
        serif = [
          "Linux Libertine"
          "DejaVu Serif"
          "Noto Serif"
          "Fira Code Nerd Font Mono"
        ];
        emoji = [ "JoyPixels" "Noto Color Emoji" "Fira Code Nerd Font Mono" ];
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
        </fontconfig>
      '';
    };

    fonts = with pkgs; [
      corefonts
      dejavu_fonts
      fira
      fira-code
      fira-code-symbols
      font-awesome
      inconsolata
      inter
      jetbrains-mono
      joypixels
      manrope
      noto-fonts
      noto-fonts-emoji
      noto-fonts-extra
      symbola
      unifont
      (nerdfonts.override { fonts = [ "FiraCode" "NerdFontsSymbolsOnly" ]; })
    ];
  };
}
