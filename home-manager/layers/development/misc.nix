{ pkgs, ... }:

{
  home.packages = with pkgs; [
    #
    postman
    duckdb
    dbeaver-bin
  ];
}
