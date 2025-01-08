{ pkgs, ... }:

{
  home.packages = with pkgs; [ proximity-sort ];

  programs.neovim = {
    enable = true;
    extraLuaPackages = ps:
      with ps; [
        #
        magick
        busted
        luafilesystem
      ];
    extraPackages = with pkgs; [ imagemagick gcc ];
    withNodeJs = true;
  };

  programs.fish.shellAliases = { v = "nvim"; };
}

