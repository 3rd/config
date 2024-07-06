{ pkgs, ... }:

{
  home.packages = with pkgs; [
    #
    lua-language-server
    stylua
    (lua5_1.withPackages (ps: with ps; [ luacheck moonscript luarocks ]))
  ];
}
