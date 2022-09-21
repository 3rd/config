{ config, pkgs, options, ... }:

{
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
      };
    };
    fonts = with pkgs; [
      corefonts
      emojione
      fira
      fira-code
      fira-code-symbols
      font-awesome
      google-fonts
      inconsolata
      jetbrains-mono
      libertine
      noto-fonts
      noto-fonts-emoji
      noto-fonts-extra
      symbola
      unifont
      (nerdfonts.override {
        fonts = [ "Mononoki" "FiraCode" "JetBrainsMono" "Hack" ];
      })
    ];
  };
}
