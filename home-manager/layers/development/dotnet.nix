{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # disgusting
    dotnet-sdk_8
    csharp-ls
  ];
}
