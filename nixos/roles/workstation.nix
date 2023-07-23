{ config, lib, pkgs, options, ... }:

{
  imports = [
    ../modules/fonts.nix
    ../modules/hardware/audio.nix
    ../modules/hardware/bluetooth.nix
    # ../modules/packages/emacs.nix
    ../modules/packages/neovim.nix
    ../modules/packages/alien.nix
    ../modules/services/docker.nix
    ../modules/services/syncthing.nix
    ../modules/services/tailscale.private.nix
    ../modules/security.private.nix
  ];

  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    settings = {
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
    EDITOR = "nvim";
    BROWSER = "google-chrome-stable";
  };
  environment.systemPackages = with pkgs; [
    (python3.withPackages (ps: with ps; [ neovim pynvim ]))
    age
    appimage-run
    bintools-unwrapped
    bottom
    brightnessctl
    bun
    cachix
    anki
    bc
    calibre
    cargo-edit
    cargo-watch
    clang-tools
    coreutils
    cpufrequtils
    curl
    curlie
    deadnix
    diskonaut
    dnsutils
    duf
    entr
    fd
    ffmpeg-full
    file
    fsrx
    fzf
    gcc
    gdb
    gdu
    gh
    git
    git-lfs
    gitlint
    glances
    glow
    iftop
    glxinfo
    gnumake
    unrar-wrapper
    gnutls
    fwts
    go-jira
    gotools
    gotop
    gron
    hadolint
    htop
    btop
    hy
    hyperfine
    i7z
    inetutils
    inxi
    iotop
    jdk17
    jless
    dbeaver
    cppcheck
    jq
    libnotify
    stable.libreoffice
    lm_sensors
    lsof
    rust-petname

    (luajit.withPackages (ps: with ps; [ luacheck moonscript luarocks magick ]))

    imagemagickBig
    syncthing
    man-pages
    moreutils
    mosh
    ncdu
    neofetch
    netlify-cli
    ngrok
    niv
    nixfmt
    proximity-sort
    flyctl
    nixos-option
    nodePackages.pnpm
    patchelf
    nodejs
    openssl
    openvpn
    p7zip
    pandoc
    pass
    pciutils
    peco
    playerctl
    hexchat
    apktool
    jadx
    frida-tools
    proselint
    sysstat
    nethogs
    psmisc
    pup
    sysfsutils
    ranger
    bridge-utils
    restic
    pciutils
    stable.awscli2
    efibootmgr
    ripgrep
    ripgrep-all
    rlwrap
    rnix-lsp
    rsync
    rust-analyzer
    sniffnet
    rustfmt
    rustup
    s-tui
    selene
    shellcheck
    shellharden
    shfmt
    silicon
    fio
    hdparm
    dmidecode
    usbutils
    nvtop-amd
    lshw
    slop
    cmake
    bottles
    ghostscript
    socat
    speedtest-cli
    sshfs
    sshuttle
    stable.openfortivpn
    tmuxp
    tor-browser-bundle-bin
    statix
    stress
    stylua
    sumneko-lua-language-server
    terminal-typeracer
    tmux
    tree
    tree-sitter
    unzip
    up
    urlscan
    vale
    inferno
    vim
    vulkan-tools
    w3m
    wget
    which
    sox
    whois
    wmctrl
    x2x
    xdotool
    xorg.xdpyinfo
    yarn
    youtube-dl
    zellij
    zenith
    yad
    zip
    zoxide
    zx
    # gui
    cutter
    cool-retro-term
    # wezterm
    alacritty
    android-file-transfer
    # bottles
    chromium
    discord
    firefox
    flameshot
    gnome.file-roller
    gnome.gucharmap
    gnome.gnome-disk-utility
    neovide
    gnome.gnome-font-viewer
    gnome.eog
    google-chrome
    ueberzugpp
    gparted
    hsetroot
    stable.insomnia
    keepassxc
    openai
    ksystemlog
    lutris
    masterpdfeditor4
    quickemu
    spicy
    pkg-config
    yarn2nix
    evemu
    deno
    # microsoft-edge-dev
    spotify
    stress-ng
    sl
    mpv
    nitrogen
    obs-studio
    pavucontrol
    pcmanfm
    polybarFull
    stable.postman
    qbittorrent
    stable.qimgv
    scrcpy
    skypeforlinux
    slack
    stable.copyq
    stable.smartgithg
    steam
    steam-run-native
    steamcmd
    tdesktop
    veracrypt
    virt-manager
    wine
    wireshark
    xclip
    xorg.xev
    xorg.xhost
    xorg.xkill
    xorg.xmodmap
    timg
    wezterm
    # sec
    feroxbuster
    # vscode
  ];

  programs.firejail.enable = true;
  programs.firejail.wrappedBinaries = {
    firefox = {
      executable = "${pkgs.lib.getBin pkgs.firefox}/bin/firefox";
      profile = "${pkgs.firejail}/etc/firejail/firefox.profile";
    };
    chromium = {
      executable = "${pkgs.lib.getBin pkgs.chromium}/bin/chromium";
      profile = "${pkgs.firejail}/etc/firejail/chromium.profile";
    };
  };
  security.chromiumSuidSandbox.enable = true;

  programs.adb.enable = true;
  programs.dconf.enable = true;
  programs.light.enable = true;
  services.avahi.enable = true;
  services.dbus.enable = true;
  services.flatpak.enable = true;
  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.timesyncd.enable = lib.mkDefault true;
  services.udev.packages = [ pkgs.android-udev-rules ];
  services.udisks2.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.lightdm.enableGnomeKeyring = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  programs.seahorse.enable = true;

  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
      ];
    };
  };

  # ssh & gpg
  services.openssh = {
    enable = true;
    # forwardX11 = true;
    # gatewayPorts = "yes";
  };
  programs.ssh.setXAuthLocation = true;
  programs.gamemode.enable = true;

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

  # systemd.extraConfig = ''
  #   # file descriptor limit
  #   DefaultLimitNOFILE=65535
  # '';

  # Google Chrome ulimit upping
  # https://bugs.chromium.org/p/chromium/issues/detail?id=362603#c28
  # security.pam.loginLimits = [{
  #   domain = "*";
  #   item = "nofile";
  #   type = "-";
  #   value = "65535";
  # }];

  # https://github.com/NixOS/nixpkgs/issues/159964
  # systemd.services."user@1000".serviceConfig.LimitNOFILE = "65535";
  # security.pam.loginLimits = [
  #   {
  #     domain = "*";
  #     item = "nofile";
  #     type = "-";
  #     value = "65535";
  #   }
  #   {
  #     domain = "*";
  #     item = "memlock";
  #     type = "-";
  #     value = "65535";
  #   }
  # ];
}
