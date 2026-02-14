{ pkgs, ... }:

{
  home.packages = with pkgs; [ rmapi ];
}
