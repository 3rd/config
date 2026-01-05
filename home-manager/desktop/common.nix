{ config, lib, pkgs, ... }:

{
  home.pointerCursor = {
    name = "Posy_Cursor";
    package = pkgs.posy-cursors;
    size = lib.mkDefault 32;
    gtk.enable = true;
    x11.enable = true;
  };
}
