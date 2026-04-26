{ pkgs }:

{
  claudeDesktop = pkgs.callPackage ./claude-desktop { electron = pkgs.electron-bin; };
  qimgv = pkgs.callPackage ./qimgv { };
}
// (import ./tts { inherit pkgs; })
