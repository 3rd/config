{ lib, pkgs, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/audio.nix
    ../modules/bluetooth.nix
    ../modules/xorg.nix
    ../modules/fonts.nix
    ../modules/virtualisation.nix
    ../modules/syncthing.private.nix
    ../modules/tailscale.private.nix
    ../modules/security.private.nix
  ];

  environment.systemPackages = with pkgs; [
    # core
    coreutils
    moreutils
    openssl
    wget
    whois
    vim
    git
    gnumake
    usbutils
    pciutils
    libnotify
    acpi
    unzip
    zip
    glib
    graphviz
    #
    ripgrep
    fzf
    fd
    bluez
    appimage-run
  ];
  environment.variables.EDITOR = "vim";

  # xdg
  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      xdgOpenUsePortal = true;
      config.common.default = "gtk";
    };
  };

  services.avahi.enable = true;
  services.dbus.enable = true;
  services.flatpak.enable = true;
  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.timesyncd.enable = lib.mkDefault true;
  services.udisks2.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.atd.enable = true;
  services.udev.packages = [ pkgs.android-udev-rules ];
  services.gvfs.enable = true; # MTP

  # misc
  programs.dconf.enable = true;
  programs.nm-applet.enable = true;
  programs.nix-ld.enable = true;
  programs.light.enable = true;
}
