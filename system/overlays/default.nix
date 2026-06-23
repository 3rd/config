{ inputs, ... }:
{
  additions = final: _prev: import ../pkgs { inherit inputs; pkgs = final; };
  modifications = final: prev: {
    opensnitch-ui = prev.opensnitch-ui.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [
        ./opensnitch-ignore-generic-desktop-launchers.patch
      ];
    });
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
