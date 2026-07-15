{ pkgs, ... }:

let
  fastcompmgr = pkgs.fastcompmgr.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ./fastcompmgr-i3-restart.patch ];
  });
in
{
  home.packages = [ fastcompmgr ];

  systemd.user.services.fastcompmgr = {
    Unit = {
      Description = "Fastcompmgr X11 compositor";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      ExecStart = "${fastcompmgr}/bin/fastcompmgr -c -C -o 0.4 -r 12";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
