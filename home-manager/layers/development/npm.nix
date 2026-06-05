{ config, lib, ... }:

{
  imports = lib.optional (builtins.pathExists ./npm.private.nix) ./npm.private.nix;

  home = {
    sessionPath = [ "$HOME/.npm/global/bin" ];
    sessionVariables.NODE_PATH = "$HOME/.npm/global/lib/node_modules";

    file.".npmrc".text = ''
      prefix=${config.home.homeDirectory}/.npm/global
      ignore-scripts=true
      min-release-age=7
      allow-git=none
      engine-strict=true
      save-exact=true
      audit=true
      fund=false
    '';
  };
}
