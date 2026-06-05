{ inputs, pkgs }:

let
  claudeDesktopSource = inputs.claude-desktop;
  claudeDesktop = pkgs.callPackage (claudeDesktopSource + "/nix/claude-desktop.nix") {
    node-pty = pkgs.callPackage (claudeDesktopSource + "/nix/node-pty.nix") { };
  };
in
{
  claudeDesktop = pkgs.callPackage (claudeDesktopSource + "/nix/fhs.nix") {
    claude-desktop = claudeDesktop;
  };
  qimgv = pkgs.callPackage ./qimgv { };
}
// (import ./tts { inherit pkgs; })
