{ lib, pkgs, ... }:

let
  lazydocker_0_24_4 = pkgs.lazydocker.overrideAttrs (_oldAttrs: rec {
    version = "0.24.4";
    src = pkgs.fetchFromGitHub {
      owner = "jesseduffield";
      repo = "lazydocker";
      rev = "v${version}";
      sha256 = "sha256-cW90/yblSLBkcR4ZdtcSI9MXFjOUxyEectjRn9vZwvg=";
    };
    ldflags = [
      "-s"
      "-w"
      "-X main.version=${version}"
    ];
  });
in
{
  networking.nftables.enable = true;

  environment.systemPackages = with pkgs; [
    # TODO: until project view bug is fixed
    lazydocker_0_24_4
    distrobox
  ];

  # hardware.nvidia-container-toolkit.enable = true;
  virtualisation = {
    oci-containers.backend = lib.mkDefault "podman";
    libvirtd = {
      enable = true;
      qemu.package = pkgs.qemu_kvm;
    };
    docker = {
      enable = lib.mkDefault false;
      enableOnBoot = lib.mkDefault false;
      rootless = {
        enable = lib.mkDefault true;
        setSocketVariable = lib.mkDefault false;
        # the rootful daemon.settings below does not apply to the rootless daemon; without
        # this, rootless containers land in the user manager's user.slice uncontained
        daemon.settings = {
          "cgroup-parent" = "docker.slice";
        };
      };
      # new docker shitfest
      package = pkgs.docker_25;
      # package = pkgs.stable.docker;
      # extraOptions = "--default-runtime=nvidia";
      daemon.settings = {
        "cgroup-parent" = "docker.slice";
      };
    };
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
