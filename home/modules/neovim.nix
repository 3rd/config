{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url =
        "https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz";
      # "https://github.com/nix-community/neovim-nightly-overlay/archive/d68c4f9302b2a7fb5c9dedc3cfa3ac9bd33fb0c6.tar.gz";

    }))
  ];
  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    extraLuaPackages = ps: [ ps.magick ];
  };
}
