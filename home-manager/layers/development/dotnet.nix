{ pkgs, ... }:

let
  csharp-ls_0_16_0 = pkgs.buildDotnetGlobalTool {
    pname = "csharp-ls";
    version = "0.16.0";
    nugetHash = "sha256-1uj0GlnrOXIYcjJSbkr3Kugft9xrHX4RYOeqH0hf1VU=";
  };
in { home.packages = with pkgs; [ dotnet-sdk_8 csharp-ls_0_16_0 ]; }
