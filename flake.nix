{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";
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
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs
    # , nixpkgs-stable
    , home-manager, ... }@inputs:
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

      nixosConfigurations = {
        spaceship = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [ ./hosts/spaceship/configuration.nix ];
        };
        macbook = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [ ./hosts/macbook/configuration.nix ];
        };
        workstation = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [ ./hosts/workstation/configuration.nix ];
        };
      };

      homeConfigurations = {
        "rabbit@spaceship" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
            # pkgs-stable = import nixpkgs {
            #   system = "x86_64-linux";
            #   config = { allowUnfree = true; };
            # };
          };
          modules = [
            { nixpkgs.overlays = [ inputs.neovim-nightly-overlay.overlay ]; }
            ./home-manager
            ./hosts/spaceship/home.nix
            disableHomeManagerNews
          ];
        };
        "rabbit@macbook" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
            # pkgs-stable = import nixpkgs {
            #   system = "aarch64-linux";
            #   config = { allowUnfree = true; };
            # };
          };
          modules = [
            { nixpkgs.overlays = [ inputs.neovim-nightly-overlay.overlay ]; }
            ./home-manager
            ./hosts/macbook/home.nix
            disableHomeManagerNews
          ];
        };
        "rabbit@workstation" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
            # pkgs-stable = import nixpkgs {
            #   system = "x86_64-linux";
            #   config = { allowUnfree = true; };
            # };
          };
          modules = [
            { nixpkgs.overlays = [ inputs.neovim-nightly-overlay.overlay ]; }
            ./home-manager
            ./hosts/workstation/home.nix
            disableHomeManagerNews
          ];
        };
      };
    };
}

