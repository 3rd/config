{ lib, pkgs, ... }:

{
  home = {
    sessionPath = [ "$HOME/.npm/global/bin" "$HOME/.pnpm" ];
    sessionVariables = {
      NODE_PATH = "$HOME/.npm/global/lib/node_modules";
      NODE_OPTIONS = "";
      PNPM_HOME = "$HOME/.pnpm";
    };
    activation = {
      npm_set_prefix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${pkgs.nodejs}/bin/npm set prefix ~/.npm/global
      '';
    };
  };

  programs.fish.shellAbbrs = {
    npx = "bunx";
    pnpx = "bunx";
    run = "bun run";
  };
}
