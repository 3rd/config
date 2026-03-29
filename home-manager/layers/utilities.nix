{ pkgs, pkgs-stable, ... }:

{
  home.packages =
    with pkgs;
    [
      # system
      htop
      dust # https://github.com/bootandy/dust
      dua # https://github.com/Byron/dua-cli
      fclones # https://github.com/pkolaczk/fclones
      dysk # https://github.com/Canop/lfs
      xcp # https://github.com/tarka/xcp
      procs # https://github.com/dalance/procs
      evemu
      ncdu
      gparted
      duf
      dig
      brightnessctl
      dmidecode
      lsof
      tomato-c
      nix-du
      usbutils
      virt-manager

      # misc
      file
      p7zip
      sshfs
      eva # https://github.com/nerdypepper/eva
      slop
      mprocs
      scooter
      playerctl

      # gui
      firefox
      gparted
      scrcpy
      eog
      file-roller
      gnome-disk-utility
      gnome-font-viewer
      gucharmap
      libqalculate
      gnome-system-monitor
      onefetch

      # new
      below
      posting
      superfile

    ]
    ++ [
      #
      pkgs-stable.miniserve # https://github.com/svenstaro/miniserve
      pkgs-stable.silicon
      pkgs-stable.netlify-cli
      pkgs-stable.copyq
      pkgs-stable.flameshot
      pkgs-stable.flyctl
    ];

  programs.fish.shellAliases = {
    serve = "miniserve";
    calc = "qalc";
    cp = "xcp";
  };
}
