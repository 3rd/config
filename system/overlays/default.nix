{ inputs, ... }: {
  additions = final: _prev: import ../pkgs { pkgs = final; };
  modifications = final: prev:
    {
      # example = prev.example.overrideAttrs (oldAttrs: rec {});
    };

  apple-silicon = inputs.apple-silicon.overlays.apple-silicon-overlay;
  neovim-nightly-overlay = inputs.neovim-nightly-overlay.overlays.default;
}
