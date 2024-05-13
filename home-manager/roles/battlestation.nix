{ inputs, lib, config, pkgs, ... }:

{
  imports = [
    #
    ./workstation.nix
    ../layers/custom/private.nix
    ../layers/custom/vault.nix
    ../services/syncthing.private.nix
    ../misc/remarkable.nix
  ];

  home.packages = with pkgs;
    [
      #
      armcord
    ];
}

