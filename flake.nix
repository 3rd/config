{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    llama-cpp.url = "github:ggml-org/llama.cpp";
    # https://github.com/NixOS/nixpkgs/issues/504370
    nixpkgs-keyring.url = "github:nixos/nixpkgs?rev=b40629efe5d6ec48dd1efba650c797ddbd39ace0";
    hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      # url = "github:nix-community/neovim-nightly-overlay?rev=fd381a5a19f553c2466dc437fb94fcf799d77e82";
      # url = "github:nix-community/neovim-nightly-overlay?rev=9fb5bc0eff86f8bad827f9f3d17d76789d28643b";
      # https://github.com/neovim/neovim/issues/36436
      # url = "github:nix-community/neovim-nightly-overlay?rev=37853aa4419e22dc2b7544e4238dd880af673bc8";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-chromium.url = "github:nixos/nixpkgs?rev=8dd2f1add978a4747a5962f2874b8ad20f86b01c";

    wired.url = "github:Toqozz/wired-notify";

    # apple-silicon = {
    #   url =
    #     "github:tpwrules/nixos-apple-silicon?rev=f51de44b1d720ac23e838db8e0cf13fadb7942b8";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # ghostty = {
    #   url = "github:ghostty-org/ghostty";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nixpkgs-master,
      nixpkgs-keyring,
      home-manager,
      wired,
      nixpkgs-chromium,
      hardware,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      spaceshipCudaConfig = {
        allowUnfree = true;
        cudaCapabilities = [ "12.0" ];
        cudaForwardCompat = false;
      };
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      disableHomeManagerNews = {
        config = {
          news.display = "silent";
          news.json = nixpkgs.lib.mkForce { };
          news.entries = nixpkgs.lib.mkForce [ ];
        };
      };
      fixTextualOverlay = final: prev: {
        python313 = prev.python313.override {
          packageOverrides = python-self: python-super: {
            textual = python-super.textual.overrideAttrs (oldAttrs: {
              meta = oldAttrs.meta // {
                broken = false;
              };
            });
          };
        };
        python3 = prev.python3.override {
          packageOverrides = python-self: python-super: {
            textual = python-super.textual.overrideAttrs (oldAttrs: {
              meta = oldAttrs.meta // {
                broken = false;
              };
            });
          };
        };
      };
      keyringPinOverlay = final: prev: {
        gnome-keyring = inputs.nixpkgs-keyring.legacyPackages.${prev.system}.gnome-keyring;
      };
      fixWiredOverlay = final: prev: {
        wired = prev.symlinkJoin {
          name = prev.wired.name;
          paths = [ prev.wired ];
          nativeBuildInputs = [ prev.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/wired \
              --prefix LD_LIBRARY_PATH : ${prev.lib.makeLibraryPath [ prev.libxkbcommon ]}
          '';
          meta = prev.wired.meta;
        };
      };
      mkNightlyNeovimPackage =
        system:
        let
          package = inputs.neovim-nightly-overlay.packages.${system}.default;
        in
        package.overrideAttrs (oldAttrs: {
          # home-manager's wrapper still hardcodes nvim.desktop
          postInstall = (oldAttrs.postInstall or "") + ''
            if [ -f "$out/share/applications/org.neovim.nvim.desktop" ] && [ ! -e "$out/share/applications/nvim.desktop" ]; then
              ln -s org.neovim.nvim.desktop "$out/share/applications/nvim.desktop"
            fi
          '';
        });
    in
    {
      overlays = import ./system/overlays { inherit inputs; };

      packages = forAllSystems (
        system:
        let
          pkgsForSystem = import nixpkgs {
            inherit system;
            overlays = [ outputs.overlays.additions ];
            config =
              if system == "x86_64-linux" then
                spaceshipCudaConfig
              else
                {
                  allowUnfree = true;
                };
          };
        in
        {
          inherit (pkgsForSystem) claudeDesktop qimgv;
          piper-libritts-r = pkgsForSystem.piperLibrittsR;
          kokoro-fastapi-cpu = pkgsForSystem.kokoroFastapiCpu;
          kokoro-fastapi-cuda = pkgsForSystem.kokoroFastapiCuda;
        }
      );

      nixosConfigurations = {
        spaceship = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs;
            pkgs-master = import nixpkgs-master {
              config = {
                allowUnfree = true;
              };
            };
            pkgs-stable = import nixpkgs-stable {
              config = {
                allowUnfree = true;
              };
            };
          };
          modules = [
            ./hosts/spaceship/configuration.nix
            {
              nixpkgs.overlays = [
                outputs.overlays.additions
                fixTextualOverlay
                keyringPinOverlay
              ];
            }
          ];
        };
        death = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs;
            pkgs-master = import nixpkgs-master {
              config = {
                allowUnfree = true;
              };
            };
            pkgs-stable = import nixpkgs-stable {
              config = {
                allowUnfree = true;
              };
            };
          };
          modules = [
            hardware.nixosModules.common-pc-laptop
            hardware.nixosModules.common-pc-ssd
            hardware.nixosModules.common-cpu-amd
            hardware.nixosModules.common-cpu-amd-pstate
            hardware.nixosModules.common-gpu-amd
            # hardware.nixosModules.common-gpu-nvidia
            ./hosts/death/configuration.nix
            {
              nixpkgs.overlays = [
                outputs.overlays.additions
                fixTextualOverlay
                keyringPinOverlay
              ];
            }
          ];
        };
      };

      homeConfigurations = {
        "rabbit@spaceship" =
          let
            system = "x86_64-linux";
          in
          home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              inherit system;
              config = spaceshipCudaConfig;
              overlays = [
                outputs.overlays.additions
                wired.overlays.default
                fixWiredOverlay
                fixTextualOverlay
                # inputs.ghostty.overlays.default
              ];
            };
            extraSpecialArgs = {
              inherit inputs outputs;
              pkgs-stable = import nixpkgs-stable {
                inherit system;
                config = {
                  allowUnfree = true;
                };
              };
              pkgs-master = import nixpkgs-master {
                inherit system;
                config = {
                  allowUnfree = true;
                };
              };
            };
            modules = [
              ./home-manager/roles/battlestation.nix
              ./hosts/spaceship/home.nix
              disableHomeManagerNews

              ({ pkgs, ... }: {
                home.packages = [
                  #
                  pkgs.qimgv
                ];
                services.wired = {
                  enable = true;
                  # config = ./wired.ron;
                };

                programs.neovim.package = mkNightlyNeovimPackage system;
              })

              wired.homeManagerModules.default
            ];
          };
        "rabbit@death" =
          let
            system = "x86_64-linux";
          in
          home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                outputs.overlays.additions
                wired.overlays.default
                fixWiredOverlay
              ];
            };
            extraSpecialArgs = {
              inherit inputs outputs;
              pkgs-stable = import nixpkgs-stable {
                inherit system;
                config = {
                  allowUnfree = true;
                };
              };
              pkgs-master = import nixpkgs-master {
                inherit system;
                config = {
                  allowUnfree = true;
                };
              };
            };
            modules = [
              {
                nixpkgs.overlays = [ inputs.neovim-nightly-overlay.overlays.default ];
              }
              ./home-manager/roles/battlestation.nix
              ./hosts/death/home.nix
              disableHomeManagerNews

              wired.homeManagerModules.default

              (_: {
                services.wired = {
                  enable = true;
                  # config = ./wired.ron;
                };

                programs.neovim.package = mkNightlyNeovimPackage system;
              })
            ];
          };
      };
    };
}
