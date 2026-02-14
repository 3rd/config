{ inputs, lib, config, pkgs, ... }:

{
  imports = [
    #
    ./workstation.nix
    ../layers/custom/private.nix
    ../layers/custom/vault.nix
    ../services/syncthing.private.nix
    ../programs/remarkable.nix
    ../programs/obs.nix
  ];

  home.packages = with pkgs;
    [
      #
    ];
}

