{ config, lib, pkgs, ... }:

{
  home.pointerCursor = {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = lib.mkDefault 32;
    gtk.enable = true;
    x11.enable = true;
  };
}
