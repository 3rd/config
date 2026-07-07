{ config, pkgs, ... }:

let
  frpcConfigPath = "${config.xdg.configHome}/frp/frpc.toml";
in
{
  home.packages = [ pkgs.frp ];

  xdg.configFile."frp/frpc.example.toml".text = ''
    serverAddr = "example.com"
    serverPort = 7000

    [[proxies]]
    name = "ssh"
    type = "tcp"
    localIP = "127.0.0.1"
    localPort = 22
    remotePort = 6000
  '';

  systemd.user.services.frpc = {
    Unit = {
      Description = "frp reverse proxy client";
      Documentation = "https://gofrp.org/en/docs/";
      ConditionPathExists = frpcConfigPath;
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStart = "${pkgs.frp}/bin/frpc -c ${frpcConfigPath}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
