{ config, pkgs, pkgs-master, lib, ... }:

# https://mise.jdx.dev/configuration.html#global-config-config-mise-config-toml
{
  programs.mise = {
    enable = true;
    globalConfig = {
      settings = {
        # tools = {
        #   #
        #   guck = "latest";
        # };
        # aliases = {
        #   cnode = "20";
        # };
      };
    };
  };
}

