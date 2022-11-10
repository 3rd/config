{ config, pkgs, ... }:

{
  nixpkgs.config = { allowUnfree = true; };

  programs.home-manager.enable = true;
  news.display = "silent";

  imports = [
    ./data-processing
    ./development
    ./misc
    ./toolkit
    ./workflow

    ./atuin.nix
    ./bat.nix
    ./custom-vault
    ./custom-wiki.nix
    ./direnv.nix
    ./dunst.nix
    ./exa.nix
    ./fish.nix
    ./fzf.nix
    ./git
    ./golang
    ./gpg.nix
    ./gtk.nix
    ./kitty.nix
    ./lock.nix
    ./mime.nix
    ./navi.nix
    ./newsboat
    ./nodejs.nix
    ./private.nix
    ./remarkable.nix
    ./rofi.nix
    ./rust.nix
    ./starship.nix
    ./syncthing.nix
    ./tmux
    ./vscode.nix
    ./wezterm.nix
    ./zathura.nix
    ./zoxide.nix
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    EDITOR = "nvim";
    MANPAGER = "nvim +Man!";
    MANWIDTH = "80";
  };

  # https://github.com/NixOS/nixpkgs/issues/196651
  manual.manpages.enable = false;
}
