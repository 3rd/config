{ inputs, pkgs }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  claudeDesktop = inputs.claude-desktop.packages.${system}.claude-desktop-fhs;
  qimgv = pkgs.callPackage ./qimgv { };
}
// (import ./tts { inherit pkgs; })
