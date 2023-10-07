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
    };
    useDHCP = false;
    networkmanager.enable = true;
    firewall.enable = true;
    firewall.allowedTCPPorts = [ 19000 ];
    interfaces.wlp0s20f3.useDHCP = true;
  };
  programs.nm-applet.enable = true;

  # locale
  time.timeZone = "Europe/Bucharest";
  time.hardwareClockInLocalTime = true;
  i18n.defaultLocale = "en_US.UTF-8";

  # hardware
  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    firmware = with pkgs; [ firmwareLinuxNonfree ];
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
