{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    #
    lazydocker
    distrobox
  ];

  virtualisation = {
    oci-containers.backend = "docker";
    docker = {
      enable = true;
      enableOnBoot = true;
      # new docker shitfest
      package = pkgs.docker_25;
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
