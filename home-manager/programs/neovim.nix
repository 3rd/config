{ pkgs, ... }:

{
  home.packages = with pkgs; [ proximity-sort ];

  programs.neovim = {
    enable = true;
    extraLuaPackages = ps: [ ps.magick ];
    extraPackages = with pkgs; [ imagemagick gcc ];
    withNodeJs = true;
  };

  programs.fish.shellAliases = { v = "nvim"; };
}

