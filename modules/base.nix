{ lib, config, pkgs, options, ... }:

{
  # nix
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      sandbox = true;
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
        "https://arm.cachix.org/"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "arm.cachix.org-1:5BZ2kjoL1q6nWhlnrbAl+G7ThY7+HaBRD9PZzqZkbnM="
      ];
      auto-optimise-store = true;
      trusted-users = [ "root" "@wheel" ];
      allowed-users = [ "@wheel" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    extraOptions = ''
      builders-use-substitutes = true
      keep-derivations = true
      keep-outputs = true
    '';
  };
  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = super:
      let self = super.pkgs;
      in {
        stable = import <nixos-stable> { inherit (config.nixpkgs) config; };
      };
  };

  boot.loader.grub.configurationLimit = 50;
  boot.initrd.systemd.enable = true;

  boot.tmp = {
    useTmpfs = lib.mkDefault true;
    cleanOnBoot = lib.mkDefault (!config.boot.tmp.useTmpfs);
  };
  systemd.services.nix-daemon = { environment.TMPDIR = "/var/tmp"; };

  fileSystems."/" = { options = [ "noatime" "nodiratime" "discard" ]; };

  # networking
  networking = {
    enableIPv6 = false;
    dhcpcd = {
      enable = false;
      wait = "background";
      extraConfig = "noarp";
    };
    useDHCP = false;
    networkmanager = {
      enable = true;
      plugins = lib.mkForce (with pkgs; [
        networkmanager-openvpn
        networkmanager-l2tp
        # networkmanager-fortisslvpn
        # networkmanager-iodine
        # networkmanager-openconnect
        # networkmanager-vpnc
        # networkmanager-sstp
      ]);
      wifi.backend = "iwd";
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
    };
    usePredictableInterfaceNames = true;
    nameservers = [ "1.0.0.1" "1.1.1.1" ];
  };

  # locale
  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  time.hardwareClockInLocalTime = true;

  # hardware
  hardware = {
    firmware = with pkgs; [ firmwareLinuxNonfree ];
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    i2c.enable = true;
  };

  # security
  security.rtkit.enable = true;
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.systemd-udevd.restartIfChanged = false;
  systemd.network.wait-online.anyInterface = true;
  systemd.network.wait-online.ignoredInterfaces = [ ];
  systemd.enableEmergencyMode = false;

  # ulimit https://github.com/NixOS/nixpkgs/issues/159964
  security.pam.loginLimits = [
    {
      domain = "*";
      item = "nofile";
      type = "-";
      value = "999999";
    }
    {
      domain = "*";
      item = "memlock";
      type = "-";
      value = "999999";
    }
    {
      domain = "@users";
      item = "rtprio";
      type = "-";
      value = 1;
    }
  ];
  systemd.user.extraConfig = "DefaultLimitNOFILE=999999";
}

