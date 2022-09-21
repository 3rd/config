{ pkgs, ... }:

{
  services.mysql = {
    enable = true;
    package = pkgs.stable.mariadb;
    settings = { mysqld.bind-address = "localhost"; };
  };
}
