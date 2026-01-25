{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
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
    nixpkgs-chromium.url =
      "github:nixos/nixpkgs?rev=8dd2f1add978a4747a5962f2874b8ad20f86b01c";

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

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-master, home-manager, wired
    , nixpkgs-chromium, hardware, ... }@inputs:
    let
      inherit (self) outputs;
      systems = [ "aarch64-linux" "x86_64-linux" ];
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
            textual = python-super.textual.overrideAttrs
              (oldAttrs: { meta = oldAttrs.meta // { broken = false; }; });
          };
        };
        python3 = prev.python3.override {
          packageOverrides = python-self: python-super: {
            textual = python-super.textual.overrideAttrs
              (oldAttrs: { meta = oldAttrs.meta // { broken = false; }; });
          };
        };
      };
    in {
      overlays = import ./overlays { inherit inputs; };

      packages = forAllSystems (system: {
        qimgv =
          nixpkgs.legacyPackages.${system}.callPackage ./modules/packages/qimgv
          { };
      });

      nixosConfigurations = {
        spaceship = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs;
            pkgs-master =
              import nixpkgs-master { config = { allowUnfree = true; }; };
            pkgs-stable =
              import nixpkgs-stable { config = { allowUnfree = true; }; };
          };
          modules = [
            ./hosts/spaceship/configuration.nix
            { nixpkgs.overlays = [ fixTextualOverlay ]; }
          ];
        };
        macbook = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs;

            pkgs-stable =
              import nixpkgs-stable { config = { allowUnfree = true; }; };
          };
          modules = [ ./hosts/macbook/configuration.nix ];
        };
        death = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs;
            pkgs-stable =
              import nixpkgs-stable { config = { allowUnfree = true; }; };
          };
          modules = [
            hardware.nixosModules.common-pc-laptop
            hardware.nixosModules.common-pc-ssd
            hardware.nixosModules.common-cpu-amd
            hardware.nixosModules.common-cpu-amd-pstate
            hardware.nixosModules.common-gpu-amd
            # hardware.nixosModules.common-gpu-nvidia
            ./hosts/death/configuration.nix
          ];
        };
      };

      homeConfigurations = {
        "rabbit@spaceship" = let system = "x86_64-linux";
        in home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              wired.overlays.default
              fixTextualOverlay
              # inputs.ghostty.overlays.default
            ];
          };
          extraSpecialArgs = {
            inherit inputs outputs;
            pkgs-stable = import nixpkgs-stable {
              inherit system;
              config = { allowUnfree = true; };
            };
            pkgs-master = import nixpkgs-master {
              inherit system;
              config = { allowUnfree = true; };
            };
          };
          modules = [
            ./home-manager/roles/battlestation.nix
            ./hosts/spaceship/home.nix
            disableHomeManagerNews

            (_: {
              home.packages = [
                #
                self.packages.${system}.qimgv
              ];
              services.wired = {
                enable = true;
                # config = ./wired.ron;
              };

              programs.neovim.package =
                inputs.neovim-nightly-overlay.packages.${system}.default;
            })

            wired.homeManagerModules.default
          ];
        };
        "rabbit@macbook" = let system = "aarch64-linux";
        in home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ wired.overlays.default ];
          };
          extraSpecialArgs = {
            inherit inputs outputs;
            pkgs-stable = import nixpkgs-stable {
              inherit system;
              config = { allowUnfree = true; };
            };
            pkgs-master = import nixpkgs-master {
              inherit system;
              config = { allowUnfree = true; };
            };
            pkgs-chromium = import nixpkgs-chromium {
              inherit system;
              config = { allowUnfree = true; };
            };
          };
          modules = [
            {
              nixpkgs.overlays =
                [ inputs.neovim-nightly-overlay.overlays.default ];
            }
            ./home-manager/roles/battlestation.nix
            ./hosts/macbook/home.nix
            disableHomeManagerNews

            wired.homeManagerModules.default

            (_: {
              home.packages = [
                #
                self.packages.${system}.qimgv
              ];

              services.wired = {
                enable = true;
                # config = ./wired.ron;
              };

              programs.neovim.package =
                inputs.neovim-nightly-overlay.packages.${system}.default;
            })
          ];
        };
        "rabbit@death" = let system = "x86_64-linux";
        in home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ wired.overlays.default ];
          };
          extraSpecialArgs = {
            inherit inputs outputs;
            pkgs-stable = import nixpkgs-stable {
              inherit system;
              config = { allowUnfree = true; };
            };
            pkgs-master = import nixpkgs-master {
              inherit system;
              config = { allowUnfree = true; };
            };
          };
          modules = [
            {
              nixpkgs.overlays =
                [ inputs.neovim-nightly-overlay.overlays.default ];
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

              programs.neovim.package =
                inputs.neovim-nightly-overlay.packages.${system}.default;
            })
          ];
        };
      };
    };
}

