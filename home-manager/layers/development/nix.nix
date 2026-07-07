{ pkgs, ... }:

{
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs; [
    nil
    statix
    nixfmt
  ];
}
