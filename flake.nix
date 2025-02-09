{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-silicon = {
      url = "github:tpwrules/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      # url = "github:nix-community/neovim-nightly-overlay?rev=fd381a5a19f553c2466dc437fb94fcf799d77e82";
      # url =
      #   "github:nix-community/neovim-nightly-overlay?rev=9fb5bc0eff86f8bad827f9f3d17d76789d28643b";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wired.url = "github:Toqozz/wired-notify";

    nixpkgs-chromium.url =
      "github:nixos/nixpkgs?rev=8dd2f1add978a4747a5962f2874b8ad20f86b01c";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-master, home-manager, wired
    , nixpkgs-chromium, ... }@inputs:
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
          modules = [ ./hosts/spaceship/configuration.nix ];
        };
        macbook = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs;

            pkgs-stable =
              import nixpkgs-stable { config = { allowUnfree = true; }; };
          };
          modules = [ ./hosts/macbook/configuration.nix ];
        };
        workstation = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs;
            pkgs-stable =
              import nixpkgs-stable { config = { allowUnfree = true; }; };
          };
          modules = [ ./hosts/workstation/configuration.nix ];
        };
      };

      homeConfigurations = {
        "rabbit@spaceship" = let system = "x86_64-linux";
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
            ./home-manager/roles/battlestation.nix
            ./hosts/spaceship/home.nix
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
        "rabbit@macbook" = let system = "aarch64-linux";
        in home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              wired.overlays.default

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
        "rabbit@workstation" = let system = "x86_64-linux";
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
            ./home-manager/roles/workstation.nix
            ./hosts/workstation/home.nix
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

