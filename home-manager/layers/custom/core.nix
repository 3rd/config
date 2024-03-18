{ config, pkgs, ... }:

let
  build_dir = "/home/rabbit/brain/core/rewrite/daemon";
  # command = "/bin/sh -c 'go run . daemon start'";
  command = "/bin/sh -c '/home/rabbit/go/bin/core daemon start'";
in {
  systemd.user.services.core = {
    Unit.Description = "Core Service";
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      WorkingDirectory = "${build_dir}";
      ExecStart = "${command}";
      # "${pkgs.watchexec}/bin/watchexec --no-discover-ignore -w . -r ${command}";
    };
  };
}
