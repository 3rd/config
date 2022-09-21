{ config, pkgs, options, ... }:

{
  services.elasticsearch = {
    enable = true;
    package = pkgs.elasticsearch7;
  };
}
