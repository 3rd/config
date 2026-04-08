{ pkgs, ... }:

{
  home.packages = with pkgs; [ proximity-sort ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [ imagemagick gcc ];
    withNodeJs = true;
    withPython3 = false;
    withRuby = false;
  };

  # prevent home-manager from generating init.lua
  xdg.configFile."nvim/init.lua".enable = false;

  programs.fish.shellAliases = {
    v = "/home/rabbit/.nix-profile/bin/with-vendors nvim";
  };
}
