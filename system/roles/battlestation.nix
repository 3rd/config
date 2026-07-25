{ lib, pkgs, ... }:

{
  imports = [
    ./workstation.nix
    ../modules/syncthing.private.nix
    ../modules/tailscale.private.nix
    ../modules/security.private.nix
  ];

  environment.systemPackages = with pkgs; [ ];

  systemd = {
    services.nvme-bfq = {
      description = "Enable BFQ on NVMe devices after local filesystems are mounted";
      after = [
        "local-fs.target"
      ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        ${pkgs.kmod}/bin/modprobe bfq
        for scheduler in /sys/block/nvme*n*/queue/scheduler; do
          if [ -w "$scheduler" ] && ${pkgs.gnugrep}/bin/grep -qw bfq "$scheduler"; then
            echo bfq > "$scheduler"
          fi
        done
      '';
      serviceConfig = {
        RemainAfterExit = true;
        Type = "oneshot";
      };
    };
    services.nix-daemon.serviceConfig = {
      IOWeight = 10;
    };
    slices.user.sliceConfig.IOWeight = lib.mkForce 200;
  };

  services.avahi.enable = true;
  users.groups.netdev = { };
}
