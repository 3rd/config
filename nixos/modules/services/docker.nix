{ config, pkgs, options, ... }:

{
  environment.systemPackages = with pkgs; [ docker-compose lazydocker ];

  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune.enable = true;
  virtualisation.oci-containers.backend = "docker";
}
