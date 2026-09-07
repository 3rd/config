{ pkgs, ... }:

let
  grokBot = pkgs.callPackage ./package.nix { };
in
{
  home.packages = [ grokBot ];
}
