{ config, lib, pkgs, inputs, ... }:

{
  home.packages = [
    #
    # inputs.browser-previews.packages.${pkgs.stdenv.hostPlatform.system}.google-chrome-dev
  ];
}
