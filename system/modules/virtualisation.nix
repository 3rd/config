{ pkgs, ... }:

{
  networking.nftables.enable = true;

  environment.systemPackages = with pkgs; [
    lazydocker
    distrobox
  ];

  # hardware.nvidia-container-toolkit.enable = true;
  virtualisation = {
    oci-containers.backend = "docker";
    libvirtd = {
      enable = true;
      qemu.package = pkgs.qemu_kvm;
    };
    docker = {
      enable = true;
      enableOnBoot = false;
      # new docker shitfest
      package = pkgs.docker_25;
      # package = pkgs.stable.docker;
      # extraOptions = "--default-runtime=nvidia";
    };
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
