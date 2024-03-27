{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # dev
    rust-petname
    jq
    jless
    hyperfine # https://github.com/sharkdp/hyperfine
    just # https://github.com/casey/just
    k6 # https://github.com/grafana/k6
    scc # https://github.com/boyter/scc
    tealdeer # https://github.com/dbrgn/tealdeer
    tokei # https://github.com/XAMPPRocky/tokei
    watchexec # https://github.com/watchexec/watchexec
    ht-rust # https://github.com/ducaale/xh
    miniserve # https://github.com/svenstaro/miniserve
    dogdns # https://github.com/ogham/dog
    fx # https://github.com/antonmedv/fx
    xsv # https://github.com/BurntSushi/xsv
    sd # https://github.com/chmln/sd
    grex # https://github.com/pemistahl/grex
    gron
    sqlite
    ast-grep
    flyctl
    netlify-cli
    ngrok
    rlwrap
    socat
    sshfs
    usbutils
    virt-manager

    # system
    htop
    du-dust # https://github.com/bootandy/dust
    dua # https://github.com/Byron/dua-cli
    fclones # https://github.com/pkolaczk/fclones
    lfs # https://github.com/Canop/lfs
    xcp # https://github.com/tarka/xcp
    procs # https://github.com/dalance/procs
    evemu
    ncdu
    gparted
    nix-du
    brightnessctl
    dmidecode
    lsof

    # misc
    file
    eva # https://github.com/nerdypepper/eva
    slop
    silicon
    mprocs
    veracrypt

    # gui
    gparted
    flameshot
    copyq
    qimgv
    scrcpy
    insomnia
    gnome.eog
    gnome.file-roller
    gnome.gnome-disk-utility
    gnome.gnome-font-viewer
    gnome.gucharmap
    gnome.gnome-system-monitor
    zathura
  ];

  programs.fish.shellAliases = {
    http = "xh";
    serve = "miniserve";
    calc = "eva";
    cp = "xcp";
  };
}

