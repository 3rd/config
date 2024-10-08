{ pkgs, pkgs-stable, ... }:

{
  home.packages = with pkgs;
    [
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
      dig
      tree-sitter
      inferno
      plantuml
      duf
      d2
      delta

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
      brightnessctl
      dmidecode
      lsof

      # misc
      file
      eva # https://github.com/nerdypepper/eva
      slop
      mprocs

      # gui
      firefox
      gparted
      flameshot
      copyq
      scrcpy
      eog
      file-roller
      gnome-disk-utility
      gnome-font-viewer
      gucharmap
      libqalculate
      gnome-system-monitor
    ] ++ [
      #
      pkgs-stable.miniserve # https://github.com/svenstaro/miniserve
      pkgs-stable.silicon
    ];

  programs.fish.shellAliases = {
    http = "xh";
    serve = "miniserve";
    calc = "qalc";
    cp = "xcp";
  };

  xdg.desktopEntries = {
    httpie = {
      name = "httpie";
      genericName = "HTTPie";
      exec = "appimage-run /home/rabbit/apps/HTTPie-2024.1.2.AppImage";
      terminal = false;
    };
  };
}

