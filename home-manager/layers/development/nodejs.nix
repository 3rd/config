{ lib, pkgs, ... }:

{

  home.packages = with pkgs; [
    #
    nodejs_latest
    electron
    quick-lint-js
    bun
  ];

  home = {
    sessionPath = [ "$HOME/.npm/global/bin" "$HOME/.pnpm" ];
    sessionVariables = {
      NODE_PATH = "$HOME/.npm/global/lib/node_modules";
      NODE_OPTIONS = "";
      PNPM_HOME = "$HOME/.pnpm";
      ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    };
    activation = {
      npm_set_prefix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${pkgs.nodejs_latest}/bin/npm set prefix ~/.npm/global
      '';
    };
  };
}
