{ pkgs, ... }:

{
  home.packages = with pkgs; [
    aw-server-rust
    aw-watcher-afk
    aw-watcher-window
  ];

  systemd.user.services = {
    activitywatch = {
      Unit.Description = "ActivityWatch Server (Rust implementation)";
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.aw-server-rust}/bin/aw-server";
        Restart = "always";
      };

      Install = { WantedBy = [ "default.target" ]; };
    };

    activitywatch-afk = {
      Unit.Description = "ActivityWatch Watcher AFK";
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.activitywatch}/bin/aw-watcher-afk";
        Restart = "always";
      };
      Install.WantedBy = [ "default.target" ];
    };

    activitywatch-window = {
      Unit.Description = "ActivityWatch Watcher Window";
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.activitywatch}/bin/aw-watcher-window";
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
