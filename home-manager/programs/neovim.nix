{ pkgs, ... }:

{
  home.packages = with pkgs; [ proximity-sort ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    extraLuaPackages = ps:
      with ps; [
        #
        magick
        busted
        # luafilesystem
      ];
    extraPackages = with pkgs; [ imagemagick gcc ];
    withNodeJs = true;
  };

  programs.fish.shellAliases = {
    v = "/home/rabbit/.nix-profile/bin/with-vendors nvim";
  };
}

