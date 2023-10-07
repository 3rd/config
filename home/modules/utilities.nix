{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # core
    fd # https://github.com/sharkdp/fd
    ripgrep # https://github.com/BurntSushi/ripgrep

    # dev
    hyperfine # https://github.com/sharkdp/hyperfine
    just # https://github.com/casey/just
    k6 # https://github.com/grafana/k6
    scc # https://github.com/boyter/scc
    tealdeer # https://github.com/dbrgn/tealdeer
    tokei # https://github.com/XAMPPRocky/tokei
    watchexec # https://github.com/watchexec/watchexec

    # system
    du-dust # https://github.com/bootandy/dust
    dua # https://github.com/Byron/dua-cli
    fclones # https://github.com/pkolaczk/fclones
    lfs # https://github.com/Canop/lfs
    xcp # https://github.com/tarka/xcp
    procs # https://github.com/dalance/procs

    # http
    ht-rust # https://github.com/ducaale/xh
    miniserve # https://github.com/svenstaro/miniserve

    # dns
    dogdns # https://github.com/ogham/dog

    # json
    fx # https://github.com/antonmedv/fx

    # csv
    xsv # https://github.com/BurntSushi/xsv

    # markdown
    inlyne # https://github.com/trimental/inlyne
    mdbook # https://github.com/rust-lang/mdBook
    mdcat # https://github.com/lunaryorn/mdcat

    # search/replace
    sd # https://github.com/chmln/sd

    # misc
    choose # https://github.com/theryangeary/choose
    eva # https://github.com/nerdypepper/eva
    grex # https://github.com/pemistahl/grex
    htmlq # https://github.com/mgdm/htmlq
    macchina # https://github.com/macchina-cli/macchina
    monolith # https://github.com/y2z/monolith
    pastel # https://github.com/sharkdp/pastel
    lemmeknow # https://github.com/swanandx/lemmeknow
  ];

  programs.fish.shellAliases = {
    http = "xh";
    serve = "miniserve";
    calc = "eva";
    cp = "xcp";
  };
}
