{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url =
        # "https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz";
        "https://github.com/nix-community/neovim-nightly-overlay/archive/1f54e89757bd951470a9dcc8d83474e363f130c5.tar.gz";
    }))
  ];

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    extraLuaPackages = ps: [ ps.magick ];
    extraPackages = with pkgs; [ imagemagick gcc ];
    withNodeJs = true;
  };

  home.packages = with pkgs; [ neovide ];
}
