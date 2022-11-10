{ config, pkgs, ... }:

{
  imports = [ ./csv.nix ./json.nix ./text.nix ];

  home.packages = with pkgs;
    [
      choose # https://github.com/theryangeary/choose
    ];
}
