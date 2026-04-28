{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../layers/communication.nix
    ../layers/custom
    ../layers/development
    ../layers/file-management.nix
    ../layers/media.nix
    ../layers/password-management.nix
    ../layers/tts.nix
    ../desktop/mime.nix
    ../desktop/xdg-desktop-entries.nix
    ../programs/bat.nix
    ../programs/chromium.nix
    ../programs/emacs.nix
    ../programs/eza.nix
    ../programs/fish.nix
    ../programs/fzf.nix
    ../programs/git
    ../programs/kitty.nix
    ../programs/navi.nix
    ../programs/neovim.nix
    ../programs/newsboat
    ../programs/rofi.nix
    ../programs/starship.nix
    ../programs/television
    ../programs/tmux
    ../programs/zathura.nix
    ../programs/zoxide.nix
    ../programs/mise.nix
    ../desktop/apps.nix
    ../desktop/gtk.nix
    ../layers/utilities.nix
    ../services/nerdctl.nix
    # ../programs/ghostty.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home = {
    username = "rabbit";
    homeDirectory = "/home/rabbit";
  };

  programs.home-manager.enable = true;

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    DO_NOT_TRACK = "true";
    EDITOR = "nvim";
    MANPAGER = "nvim +Man!";
    MANWIDTH = "80";
  };

  systemd.user.startServices = "sd-switch";
  home.stateVersion = "24.05";
}
