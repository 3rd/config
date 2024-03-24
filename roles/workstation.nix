{ lib, pkgs, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/audio.nix
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

  services = {
    avahi.enable = true;
    dbus.enable = true;
    flatpak.enable = true;
    fstrim.enable = true;
    fwupd.enable = true;
    timesyncd.enable = lib.mkDefault true;
    udisks2.enable = true;
    gnome.gnome-keyring.enable = true;
    atd.enable = true;
    udev.packages = [ pkgs.android-udev-rules ];
    gvfs.enable = true; # MTP
  };

  # misc
  programs.dconf.enable = true;
  programs.nm-applet.enable = true;

  programs.nix-ld.enable = true;
}
