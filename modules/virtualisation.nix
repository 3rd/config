{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    #
    docker-compose
    lazydocker
    distrobox
  ];

  virtualisation = {
    oci-containers.backend = "docker";
    docker = {
      enable = true;
      autoPrune.enable = true;
      # package = pkgs.stable.docker;
    };
    libvirtd = {
      enable = true;
      qemu.package = pkgs.qemu_kvm;
    };
    # virtualisation.podman = {
    #   enable = true;
    #   dockerCompat = true;
    #   defaultNetwork.settings = { dns_enabled = true; };
    # };
  };

}
