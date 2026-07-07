{ inputs, pkgs }:

let
  claudeDesktopSource = inputs.claude-desktop;
  claudeDesktop = pkgs.callPackage (claudeDesktopSource + "/nix/claude-desktop.nix") { };
in
{
  claudeDesktop = pkgs.callPackage (claudeDesktopSource + "/nix/fhs.nix") {
    claude-desktop = claudeDesktop;
  };
  qimgv = pkgs.callPackage ./qimgv { };
}
// (import ./tts { inherit pkgs; })
