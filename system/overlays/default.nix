{ inputs, ... }:
{
  additions = final: _prev: import ../pkgs { inherit inputs; pkgs = final; };
  modifications = final: prev: {
    kitty = prev.kitty.overrideAttrs (finalAttrs: oldAttrs: {
      version = "0.50.0";
      src = final.fetchFromGitHub {
        inherit (oldAttrs.src) owner repo;
        tag = "v${finalAttrs.version}";
        hash = "sha256-CSSjL931OLZ9wwz9E3rAfMcm+TpczVJzJh9MPfuKmVU=";
      };

      goModules =
        (final.buildGo126Module {
          pname = "kitty-go-modules";
          inherit (finalAttrs) src version;
          vendorHash = "sha256-Oo5ehjdq4HcTxZcKi/rwz8dDZYGxdSS8cqIkbdLBrb8=";
        }).goModules;

      meta = oldAttrs.meta // {
        changelog = [
          "https://sw.kovidgoyal.net/kitty/changelog/"
          "https://github.com/kovidgoyal/kitty/blob/v${finalAttrs.version}/docs/changelog.rst"
        ];
      };
    });

    opensnitch = prev.opensnitch.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [ ./opensnitch-ebpf-map-count.patch ];
    });
    opensnitch-ui = prev.opensnitch-ui.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [
        ./opensnitch-context-menu-screen.patch
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
