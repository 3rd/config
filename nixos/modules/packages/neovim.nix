{ config, pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      neovim-master = super.neovim-unwrapped.overrideAttrs (oldAttrs: {
        version = "master";
        src = super.fetchFromGitHub {
          owner = "neovim";
          repo = "neovim";
          # https://github.com/neovim/neovim/commit/d5db93b8aa7d7fa7e9a5aa548725a9f52ac8da89
          rev = "d5db93b8aa7d7fa7e9a5aa548725a9f52ac8da89";
          sha256 = "12BUr+B7Za2c5XoH6ROoWRbY3XzIWYpPh6gpzE+/Kmo=";
        };
        buildInputs = oldAttrs.buildInputs ++ [ super.tree-sitter ];
      });
    })
  ];
  environment.systemPackages = with pkgs; [ neovim-master ];
}
