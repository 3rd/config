{ pkgs, ... }:

{
  home.packages = with pkgs; [
    #
    lua-language-server
    stylua
    (luajit.withPackages (ps: with ps; [ luacheck moonscript luarocks magick ]))
  ];
}
