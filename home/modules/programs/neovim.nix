{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url =
        "https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz";
      # "https://github.com/nix-community/neovim-nightly-overlay/archive/5240f631102f4aba8c498f07b3996355edbe62fa.tar.gz";
    }))
  ];

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    extraLuaPackages = ps: [ ps.magick ];
    withNodeJs = true;
  };
}
