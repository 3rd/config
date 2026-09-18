{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    alloy6
    inputs.buildprof.packages.${pkgs.stdenv.hostPlatform.system}.default
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
