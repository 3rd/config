{ lib, pkgs, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/audio.nix
    ../modules/bluetooth.nix
    ../modules/xorg.nix
    ../modules/fonts.nix
    ../modules/virtualisation.nix
    ../modules/ld.nix
  ];

  boot.kernel.sysctl = {
    "fs.inotify.max_queued_events" = 32768;
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 524288;
  };

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
  services.udev.packages = [ pkgs.android-udev-rules ];
  services.gvfs.enable = true; # trash, MTP
  services.logind.killUserProcesses = true;

}
