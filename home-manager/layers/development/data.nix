{ pkgs, ... }:

{
  home.packages = with pkgs; [
    jq
    jless
    fx # https://github.com/antonmedv/fx
    gron
    sqlite
    duckdb
  ];
}
