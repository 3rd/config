{ config, lib, pkgs, ... }:

let
  packages = [
    "@fsouza/prettierd"
    "depcheck"
    "esbuild"
    "eslint"
    "eslint_d"
    "fixjson"
    "lerna"
    "neovim"
    "node2nix"
    "parcel"
    "prettier"
    "prettier_d_slim"
    "rustywind"
    "typescript"
    "typescript"
  ];
in {
  home.sessionPath = [ "$HOME/.npm/global/bin" "$HOME/.pnpm" ];
  home.sessionVariables = {
    NODE_PATH = "$HOME/.npm/global/lib/node_modules";
    NODE_OPTIONS =
      "--max_old_space_size=16384 --trace-warnings --use-largepages=silent";
    PNPM_PATH = "$HOME/.pnpm";
  };
  home.activation = {
    npm_set_prefix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      npm set prefix ~/.npm/global
      # npm install -g ${lib.concatMapStringsSep " " (x: x) packages}
    '';
  };
}
