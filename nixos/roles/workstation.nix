{ config, lib, pkgs, options, ... }:

{
  imports = [
    ../modules/fonts.nix
    ../modules/hardware/audio.nix
    ../modules/hardware/bluetooth.nix
    ../modules/packages/emacs.nix
    ../modules/packages/neovim.nix
    ../modules/services/docker.nix
    ../modules/services/syncthing.nix
    ../modules/services/tailscale.private.nix
  ];

  nix = {
    package = pkgs.nixFlakes;
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
      in
      {
        stable = import <nixos-stable> { inherit (config.nixpkgs) config; };
      };
  };

  # sysctl - a
  boot.kernel.sysctl = {
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
    "vm.swappiness" = 0;
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
    aws
    bintools-unwrapped
    bottom
    brightnessctl
    bun
    cachix
    cargo-edit
    cargo-watch
    clang-tools
    coreutils
    cppcheck
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
    glxinfo
    gnumake
    gnutls
    go-jira
    gotools
    gotop
    gron
    hadolint
    htop
    httpie
    hy
    hyperfine
    i7z
    inetutils
    inxi
    iotop
    jdk11
    jq
    libnotify
    libreoffice
    lm_sensors
    lsof
    luajit
    luajitPackages.luacheck
    luajitPackages.moonscript
    man-pages
    moreutils
    mosh
    ncdu
    neofetch
    netlify-cli
    ngrok
    niv
    nixfmt
    nixos-option
    nodePackages.pnpm
    nodejs
    openssl
    openvpn
    p7zip
    pandoc
    pass
    pciutils
    peco
    playerctl
    powertop
    proselint
    psmisc
    pup
    ranger
    restic
    ripgrep
    ripgrep-all
    rlwrap
    rnix-lsp
    rsync
    rust-analyzer
    rustfmt
    rustup
    s-tui
    scc
    sd
    selene
    shellcheck
    shellharden
    shfmt
    silicon
    slop
    socat
    speedtest-cli
    sshfs
    sshuttle
    stable.openfortivpn
    stable.tmuxp
    statix
    stress
    stylua
    sumneko-lua-language-server
    terminal-typeracer
    tmux
    tokei
    tree
    tree-sitter
    unzip
    up
    urlscan
    vale
    vim
    vulkan-tools
    w3m
    watchexec
    wget
    which
    whois
    wmctrl
    x2x
    xdotool
    xorg.xdpyinfo
    yarn
    youtube-dl
    zellij
    zenith
    zip
    zoxide
    zx
    # gui
    alacritty
    android-file-transfer
    bottles
    chromium
    discord
    firefox
    flameshot
    gnome.file-roller
    gnome.gnome-disk-utility
    gnome3.file-roller
    gnome3.gnome-font-viewer
    gnome3.zenity
    google-chrome
    gparted
    hsetroot
    insomnia
    keepassxc
    kooha
    ksystemlog
    lutris
    masterpdfeditor4
    microsoft-edge-dev
    mpv
    nitrogen
    obs-studio
    pavucontrol
    pcmanfm
    peek
    polybarFull
    postman
    qbittorrent
    qimgv
    scrcpy
    skypeforlinux
    slack
    stable.copyq
    stable.smartgithg
    steam
    steam-run-native
    steam-tui
    steamcmd
    tdesktop
    veracrypt
    virt-manager
    wine
    wireshark
    xclip
    xorg.xev
    xorg.xkill
    xorg.xmodmap
    zettlr
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
  services.gnome.gnome-keyring.enable = true;
  services.timesyncd.enable = lib.mkDefault true;
  services.udev.packages = [ pkgs.android-udev-rules ];
  xdg.portal.enable = lib.mkDefault true;

  # ssh & gpg
  services.openssh = {
    enable = true;
    forwardX11 = true;
    gatewayPorts = "yes";
  };
  programs.ssh.setXAuthLocation = true;
  programs.gamemode.enable = true;

  environment.etc."issue.d/ip.issue".text = ''
    \4
  '';
  networking.dhcpcd.runHook = "${pkgs.utillinux}/bin/agetty --reload";

  virtualisation.libvirtd = {
    enable = true;
    qemu.package = pkgs.qemu_kvm;
  };

  systemd.enableEmergencyMode = false;
}
