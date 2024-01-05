{ config, pkgs, ... }:

let
  build_dir = "/home/rabbit/brain/core/daemon/dist";
  command = "/bin/sh -c core-daemon";
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
