{ config, pkgs, ... }:

{
  imports = [ ./dns.nix ./http.nix ];

  home.packages = with pkgs; [
    hyperfine # https://github.com/sharkdp/hyperfine
    just # https://github.com/casey/just
    k6 # https://github.com/grafana/k6
    scc # https://github.com/boyter/scc
    tealdeer # https://github.com/dbrgn/tealdeer
    tokei # https://github.com/XAMPPRocky/tokei
    watchexec # https://github.com/watchexec/watchexec
  ];
}
