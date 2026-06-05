{ inputs, ... }:
{
  additions = final: _prev: import ../pkgs { inherit inputs; pkgs = final; };
  modifications = final: prev: {
    open-webui = prev.open-webui.overrideAttrs (oldAttrs:
      let
        frontend = oldAttrs.passthru.frontend.overrideAttrs (frontendOld: {
          npmFlags = final.lib.filter (flag: flag != "--legacy-peer-deps") (
            frontendOld.npmFlags or [ "--force" ]
          );
        });
      in
      {
        makeWrapperArgs = [ "--set FRONTEND_BUILD_DIR ${frontend}/share/open-webui" ];
        passthru = oldAttrs.passthru // { inherit frontend; };
      }
    );
  };
  neovim-nightly-overlay = inputs.neovim-nightly-overlay.overlays.default;
}
