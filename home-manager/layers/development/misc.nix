{ pkgs, pkgs-stable, ... }:

{
  home.packages = with pkgs;
    [
      #
      duckdb
    ] ++ (with pkgs-stable;
      [
        #
        postman
      ]);
}
