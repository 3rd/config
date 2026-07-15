{ pkgs, ... }:

{
  home.packages = [ pkgs.xmousepasteblock ];

  systemd.user.services.xmousepasteblock = {
    Unit = {
      Description = "Block X11 middle-click selection pastes";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      ExecStart = "${pkgs.xmousepasteblock}/bin/xmousepasteblock";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
