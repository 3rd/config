{ config, pkgs, options, ... }:

{
  nixpkgs.config.joypixels.acceptLicense = true;
  fonts = {
    enableDefaultFonts = true;
    fontDir.enable = true;
    fontconfig = {
      enable = true;
      cache32Bit = true;
      defaultFonts = {
        monospace = [ "BMono" "DejaVu Sans Mono" ];
        sansSerif = [ "DejaVu Sans" "Noto Sans" ];
        serif = [ "Linux Libertine" "DejaVu Serif" "Noto Serif" ];
        emoji = [ "JoyPixels" "Noto Color Emoji" ];
      };
    };

    fonts = with pkgs; [
      corefonts
      joypixels
      fira
      fira-code
      fira-code-symbols
      font-awesome
      inconsolata
      jetbrains-mono
      libertine
      noto-fonts
      noto-fonts-emoji
      noto-fonts-extra
      symbola
      unifont
      # google-fonts
      (nerdfonts.override {
        fonts = [ "Mononoki" "FiraCode" "JetBrainsMono" "Hack" ];
      })
    ];
  };
}
