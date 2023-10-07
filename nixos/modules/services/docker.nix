{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ docker-compose lazydocker ];

  # virtualisation.docker.package = pkgs.stable.docker;
  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune.enable = true;
  virtualisation.oci-containers.backend = "docker";
}
