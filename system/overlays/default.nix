{ inputs, ... }:
{
  additions = final: _prev: import ../pkgs { inherit inputs; pkgs = final; };
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {});
  };
  neovim-nightly-overlay = inputs.neovim-nightly-overlay.overlays.default;
}
