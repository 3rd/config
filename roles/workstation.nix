{ lib, pkgs, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/audio.nix
    ../modules/bluetooth.nix
    ../modules/xorg.nix
    ../modules/fonts.nix
    ../modules/virtualisation.nix
  ];

  boot.kernel.sysctl = {
    "fs.inotify.max_queued_events" = 32768;
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 1048576;

    "net.core.rmem_max" = 67108864;
    "net.core.wmem_max" = 67108864;
    "net.ipv4.tcp_rmem" = "4096 87380 33554432";
    "net.ipv4.tcp_wmem" = "4096 65536 33554432";
    "net.ipv4.tcp_tw_reuse" = true;
    "net.core.netdev_max_backlog" = 8388608;
    "net.core.somaxconn" = 8388608;
    "net.ipv4.tcp_max_orphans" = 32768;
  };
  systemd.extraConfig = "DefaultLimitNOFILE=1048576";
  systemd.user.extraConfig = "DefaultLimitNOFILE=1048576";

  environment.systemPackages = with pkgs; [
    acpi
    appimage-run
    bluez
    coreutils
    fd
    fzf
    git
    glib
    gnumake
    graphviz
    imhex
    inotify-tools
    libfaketime
    libnotify
    moreutils
    openssl
    pciutils
    ripgrep
    unzip
    usbutils
    vim
    wget
    whois
    zip
    s-tui
    memtester
    (pkgs.buildFHSUserEnv (pkgs.appimageTools.defaultFhsEnvArgs // {
      name = "fhs";
      profile = "export FHS=1";
      runScript = "fish";
    }))
  ];
  environment.variables.EDITOR = "vim";

  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      xdgOpenUsePortal = true;
      config.common.default = "gtk";
    };
  };

  programs.dconf.enable = true;
  programs.nm-applet.enable = true;
  programs.light.enable = true;

  services.dbus.enable = true;
  services.flatpak.enable = true;
  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.timesyncd.enable = lib.mkDefault true;
  services.udisks2.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.atd.enable = true;
  services.gvfs.enable = true; # trash, MTP
  services.logind.killUserProcesses = true;
  services.devmon.enable = true;
  services.irqbalance.enable = true;
}
