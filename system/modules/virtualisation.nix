{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    #
    lazydocker
    distrobox
  ];

  # hardware.nvidia-container-toolkit.enable = true;
  virtualisation = {
    oci-containers.backend = "docker";
    docker = {
      enable = true;
      enableOnBoot = false;
      # new docker shitfest
      package = pkgs.docker_25;
      # package = pkgs.stable.docker;
      # extraOptions = "--default-runtime=nvidia";
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
