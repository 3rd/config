{ pkgs }:

{
  qimgv = pkgs.callPackage ./qimgv { };
}
// (import ./tts { inherit pkgs; })
