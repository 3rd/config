{ config, lib, pkgs, options, ... }:

{
  imports = [
    ../modules/hardware/audio.nix
    ../modules/hardware/bluetooth.nix
    ../modules/services/docker.nix
    ../modules/services/ssh.nix
    ../modules/fonts.nix
    ../modules/services/tailscale.private.nix
    ../modules/services/syncthing.private.nix
    ../modules/security.private.nix
    # ../modules/packages/emacs.nix
  ];

  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      sandbox = true;
      substituters =
        [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      auto-optimise-store = true;
      trusted-users = [ "root" "rabbit" ];
      max-jobs = 32;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };
  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = super:
      let self = super.pkgs;
      in {
        stable = import <nixos-stable> { inherit (config.nixpkgs) config; };
      };
  };

  # sysctl - a
  boot.kernel.sysctl = {
    "kernel.sched_cfs_bandwidth_slice_us" = 3000;
    "kernel.sched_latency_ns" = 4000000;
    "kernel.sched_migration_cost_ns" = 250000;
    "kernel.sched_min_granularity_ns" = 500000;
    "kernel.sched_nr_migrate" = 128;
    "kernel.sched_wakeup_granularity_ns" = 50000;
    "vm.dirty_background_ratio" = 20;
    "vm.dirty_ratio" = 50;
    "vm.swappiness" = 90;
    "vm.vfs_cache_pressure" = 50;
  };

  # packages
  environment.variables = {
    TERMINAL = "kitty";
    BROWSER = "google-chrome-stable";
  };
  environment.systemPackages = with pkgs; [
    (import (fetchTarball "https://install.devenv.sh/latest")).default
    (luajit.withPackages (ps: with ps; [ luacheck moonscript luarocks magick ]))
    (python3.withPackages (ps: with ps; [ neovim pynvim ]))
    nodePackages.pnpm

    age
    alacritty
    android-file-transfer
    apktool
    appimage-run
    arandr
    autorandr
    bintools-unwrapped
    bottom
    bridge-utils
    brightnessctl
    bruno
    btop
    bun
    cachix
    cargo-edit
    cargo-watch
    clang
    clang-tools
    cmake
    conda
    coreutils
    cppcheck
    cpufrequtils
    curl
    deno
    discord
    dmidecode
    dnsutils
    efibootmgr
    evemu
    exiv2
    fd
    ffmpeg-full
    ffmpegthumbnailer
    file
    firefox
    flameshot
    flyctl
    frida-tools
    fswatch
    fzf
    gcc
    gdb
    gdu
    gh
    ghostscript
    gimp
    git
    git-lfs
    glow
    glxinfo
    gnome.eog
    gnome.file-roller
    gnome.gnome-disk-utility
    gnome.gnome-font-viewer
    gnome.gucharmap
    gnumake
    gnutls
    google-chrome
    gotools
    gparted
    gron
    hasura-cli
    hdparm
    hexchat
    hsetroot
    htop
    yazi
    hyperfine
    i7z
    iftop
    imagemagickBig
    inetutils
    inferno
    inxi
    iotop
    jadx
    jdk17
    jless
    jq
    keepassxc
    ksystemlog
    libnotify
    lm_sensors
    lshw
    lsof
    lua-language-server
    trippy
    man-pages
    masterpdfeditor4
    microsoft-edge-dev
    moreutils
    mprocs
    mpv
    msr-tools
    ncdu
    neofetch
    nethogs
    netlify-cli
    ngrok
    nitrogen
    niv
    nixd
    nixfmt
    nixos-option
    nodejs_latest
    nvtop-amd
    obs-studio
    openai
    openssl
    openvpn
    p7zip
    pandoc
    pass
    patchelf
    pavucontrol
    pciutils
    pciutils
    pcmanfm
    pkg-config
    playerctl
    polybarFull
    poppler_utils
    proselint
    proximity-sort
    psmisc
    pup
    qbittorrent
    quickemu
    ranger
    restic
    ripgrep
    rlwrap
    rsync
    rust-analyzer
    rustfmt
    rustup
    s-tui
    scrcpy
    selene
    shellcheck
    shellharden
    shfmt
    silicon
    skypeforlinux
    sl
    slack
    slop
    sniffnet
    socat
    sox
    speedtest-cli
    spicy
    spotify
    sshfs
    sshuttle
    stable.anki
    stable.awscli2
    stable.copyq
    stable.insomnia
    stable.libreoffice
    stable.openfortivpn
    stable.postman
    stable.qimgv
    statix
    stress-ng
    stripe-cli
    stylua
    syncthing
    sysfsutils
    sysstat
    tdesktop
    terminal-typeracer
    timg
    tmux
    stable.tmuxp
    tree
    tree-sitter
    ueberzugpp
    unrar-wrapper
    unzip
    up
    urlscan
    usbutils
    vale
    veracrypt
    vim
    virt-manager
    vulkan-tools
    w3m
    wget
    which
    whois
    wireshark
    wmctrl
    xclip
    xdotool
    xfce.tumbler
    xorg.xdpyinfo
    xorg.xev
    xorg.xhost
    xorg.xkill
    xorg.xmodmap
    yad
    yarn
    yarn2nix
    youtube-dl
    zellij
    zip
    zoxide
    zx
    arduino
    arduino-ide
    arduino-cli
  ];

  programs = {
    adb.enable = true;
    dconf.enable = true;
    light.enable = true;
    seahorse.enable = true;
    gamemode.enable = true;
  };

  services = {
    avahi.enable = true;
    dbus.enable = true;
    flatpak.enable = true;
    fstrim.enable = true;
    fwupd.enable = true;
    timesyncd.enable = lib.mkDefault true;
    udev.packages = [ pkgs.android-udev-rules ];
    udisks2.enable = true;
    gvfs.enable = true; # MTP
    gnome.gnome-keyring.enable = true;
    atd.enable = true;
  };

  security.pam.services = {
    lightdm.enableGnomeKeyring = true;
    sddm.enableGnomeKeyring = true;
  };

  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      xdgOpenUsePortal = true;
      config.common.default = "gtk";
    };
  };

  environment.etc."issue.d/ip.issue".text = ''
    \4
  '';

  virtualisation.libvirtd = {
    enable = true;
    qemu.package = pkgs.qemu_kvm;
  };

  # https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.systemd-udevd.restartIfChanged = false;
  systemd.network.wait-online.anyInterface = true;
  systemd.network.wait-online.ignoredInterfaces = [ ];
  systemd.enableEmergencyMode = false;

  # Stream Deck
  services.udev.extraRules = ''
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0fd9", GROUP="users", TAG+="uaccess"
    SUBSYSTEM=="input", GROUP="input", MODE="0666"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0060", MODE:="666"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0063", MODE:="666"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", MODE:="666"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", MODE:="666"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0080", MODE:="666"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0084", MODE:="666"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0086", MODE:="666"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0090", MODE:="666"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0060", MODE:="666"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0063", MODE:="666"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", MODE:="666"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", MODE:="666"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0080", MODE:="666"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0084", MODE:="666"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0086", MODE:="666"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0090", MODE:="666"
  '';
}
