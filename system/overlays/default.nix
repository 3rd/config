{ inputs, ... }:
{
  additions = final: _prev: import ../pkgs { inherit inputs; pkgs = final; };
  modifications = final: prev: {
    aggregateModules = modules: (prev.aggregateModules modules).overrideAttrs (oldAttrs: {
      # A replacement removes the stock modules.dep entry but leaves modules.order unchanged.
      postBuild = final.lib.replaceStrings
        [ ''sed "1,$(wc -l < modules.order)d; s/\.ko.*/.ko.cer/" modules.dep'' ]
        [ ''comm -23 <(sed 's/\.ko.*/.ko/' modules.dep | sort) <(sort modules.order) | sed "s/$/.cer/"'' ]
        oldAttrs.postBuild;
    });

    kernelPackagesExtensions = prev.kernelPackagesExtensions ++ [
      (kernel-final: kernel-prev:
        let
          inherit (kernel-final) kernel;
          kernelBuild = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
        in
        {
          it87 = kernel-prev.it87.overrideAttrs (oldAttrs: {
            makeFlags = oldAttrs.makeFlags ++ [
              "INSTALL_MOD_PATH=${placeholder "out"}"
            ];
            installFlags = [ "-C" kernelBuild "M=$(PWD)" ];
            installTargets = [ "modules_install" ];
            dontStrip = true;
          });

          sysdig = kernel-prev.sysdig.overrideAttrs (oldAttrs: {
            nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ final.buildPackages.removeReferencesTo ];
            stripExclude = (oldAttrs.stripExclude or [ ]) ++ [ "lib/modules/*" ];
            postInstall = ''
              installShellCompletion --bash "$out/etc/bash_completion.d/sysdig"
              rm "$out/etc/bash_completion.d/sysdig"
              rmdir "$out/etc/bash_completion.d" "$out/etc"

              # Reference cleanup must precede modules_install, which signs the module bytes.
              remove-references-to -t ${kernel.dev} driver/src/scap.ko
              make -C ${kernelBuild} \
                ${final.lib.escapeShellArgs kernel-final.kernelModuleMakeFlags} \
                M="$PWD/driver/src" INSTALL_MOD_PATH="$out" modules_install
            '';
          });
        }
      )
    ];

    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_python-final: python-prev: {
        primp = python-prev.primp.overridePythonAttrs (oldAttrs: {
          nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ final.pkg-config ];
          buildInputs = oldAttrs.buildInputs ++ [
            final.aws-lc
            final.zstd
          ];
        });

        chromadb = (python-prev.chromadb.override { protobuf = final.protobuf; }).overridePythonAttrs (oldAttrs: {
          buildInputs = oldAttrs.buildInputs ++ [
            final.rust-jemalloc-sys
            final.sqlite
          ];
        });
      })
    ];

    below = prev.below.overrideAttrs (oldAttrs: {
      buildInputs = oldAttrs.buildInputs ++ [ final.zstd ];
    });

    scooter = prev.scooter.overrideAttrs (oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ final.pkg-config ];
      buildInputs = oldAttrs.buildInputs ++ [ final.oniguruma ];
    });

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
        makeWrapperArgs = [ "--set" "FRONTEND_BUILD_DIR" "${frontend}/share/open-webui" ];
        passthru = oldAttrs.passthru // { inherit frontend; };
      }
    );
  };
  neovim-nightly-overlay = inputs.neovim-nightly-overlay.overlays.default;
}
