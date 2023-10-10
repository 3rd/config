{ config, pkgs, ... }:

{
  nixpkgs.config = { allowUnfree = true; };

  imports = [
    ./services/polybar
    ./services/dunst.nix
    ./services/i3.nix
    ./services/picom.nix
    ./services/syncthing.nix
    ./services/activitywatch.nix

    ./programs/bat.nix
    ./programs/direnv.nix
    ./programs/eza.nix
    ./programs/fish.nix
    ./programs/fzf.nix
    ./programs/git
    ./programs/kitty.nix
    ./programs/navi.nix
    ./programs/neovim.nix
    ./programs/newsboat
    ./programs/rofi.nix
    ./programs/starship.nix
    ./programs/tmux
    ./programs/urxvt.nix
    ./programs/zathura.nix
    ./programs/zoxide.nix

    ./golang.nix
    ./nodejs.nix
    ./rust.nix

    ./gtk.nix
    ./mime.nix
    ./remarkable.nix
    ./utilities.nix
    ./xresources.nix

    ./custom/work
    ./custom/journal.nix
    ./custom/lock.nix
    ./custom/private.nix
    ./custom/vault.nix
    ./custom/wiki.nix

  ];

  programs.home-manager.enable = true;

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    EDITOR = "nvim";
    MANPAGER = "nvim +Man!";
    MANWIDTH = "80";
  };

  # https://github.com/NixOS/nixpkgs/issues/196651
  manual.manpages.enable = false;
  news.display = "silent";

  xsession.profileExtra = ''
    systemctl --user import-environment
    eval $(${pkgs.gnome.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets,ssh,pkcs11)
    export SSH_AUTH_SOCK
  '';
}
