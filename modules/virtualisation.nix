{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    #
    docker-compose
    lazydocker
    distrobox
  ];

  virtualisation.docker = {
    enable = true;
    package = pkgs.stable.docker;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # virtualisation.podman = {
  #   enable = true;
  #   dockerCompat = true;
  #   defaultNetwork.settings = { dns_enabled = true; };
  # };

  virtualisation.libvirtd = {
    enable = true;
    qemu.package = pkgs.qemu_kvm;
  };
}
