{ pkgs, ... }:

{
  home.packages = with pkgs; [ proximity-sort ];

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    extraLuaPackages = ps: [ ps.magick ];
    extraPackages = with pkgs; [ imagemagick gcc ];
    withNodeJs = true;
  };

  programs.fish.shellAliases = { v = "nvim"; };
}

