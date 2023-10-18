{ pkgs, options, ... }:

{
  # nix
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # filesystem
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
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
    };
    usePredictableInterfaceNames = true;
    nameservers = [ "1.0.0.1" "1.1.1.1" ];
  };
  programs.nm-applet.enable = true;

  # locale
  time.timeZone = "Europe/Bucharest";
  time.hardwareClockInLocalTime = true;
  i18n.defaultLocale = "en_US.UTF-8";

  # hardware
  hardware = {
    firmware = with pkgs; [ firmwareLinuxNonfree ];
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    i2c.enable = true;
  };

  # security
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = true;

  # base packages
  environment.systemPackages = with pkgs; [
    #
    git
    vim
    wget
    curl
  ];
  environment.variables.EDITOR = "vim";
}
