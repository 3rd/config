{ lib, config, pkgs, ... }:

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
    ./work

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
    ./zathura.nix
    ./zoxide.nix
    # ./wezterm.nix
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    EDITOR = "nvim";
    MANPAGER = "nvim +Man!";
    MANWIDTH = "80";
  };

  # https://github.com/NixOS/nixpkgs/issues/196651
  manual.manpages.enable = false;

  # https://github.com/NixOS/nixpkgs/issues/201324
  # nixpkgs.overlays = [
  #   (self: super: {
  #     gnomefix = self.gnome // {
  #       gnome-keyring = super.gnome.gnome-keyring.override {
  #         glib = self.glib.overrideAttrs (a: rec {
  #           patches = a.patches ++ [
  #             (super.fetchpatch {
  #               url =
  #                 "https://gitlab.gnome.org/GNOME/glib/-/commit/2a36bb4b7e46f9ac043561c61f9a790786a5440c.patch";
  #               sha256 = "b77Hxt6WiLxIGqgAj9ZubzPWrWmorcUOEe/dp01BcXA=";
  #             })
  #           ];
  #         });
  #       };
  #     };
  #   })
  # ];

  xsession.profileExtra = ''
    systemctl --user import-environment
    eval $(${pkgs.gnome.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets,ssh,pkcs11)
    export SSH_AUTH_SOCK
  '';
}
