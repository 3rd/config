{ config, pkgs, ... }:

{
  imports = [ ./file-management.nix ./markdown.nix ./process-management.nix ];

  home.packages = with pkgs; [
    fd # https://github.com/sharkdp/fd
    ripgrep # https://github.com/BurntSushi/ripgrep
    ripgrep-all # https://github.com/phiresky/ripgrep-all
  ];
}
