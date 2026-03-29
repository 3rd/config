{ pkgs, ... }:

{
  home.packages = with pkgs; [
    hyperfine # https://github.com/sharkdp/hyperfine
    k6 # https://github.com/grafana/k6
    scc # https://github.com/boyter/scc
    tokei # https://github.com/XAMPPRocky/tokei
    ast-grep
    inferno
  ];

  programs.fish.shellAliases = {
    astscan = "ast-grep scan";
  };
}
