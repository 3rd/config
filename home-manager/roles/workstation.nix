{ inputs, lib, config, pkgs, ... }: {
  imports = [
    ../layers/custom
    ../layers/development
    ../layers/password-management.nix
    ../layers/communication.nix
    ../layers/file-management.nix
    ../layers/media.nix
    ../programs/git
    ../programs/tmux
    ../programs/bat.nix
    ../programs/chromium.nix
    ../programs/eza.nix
    ../programs/fish.nix
    ../programs/fzf.nix
    ../programs/kitty.nix
    ../programs/navi.nix
    ../programs/zathura.nix
    ../programs/neovim.nix
    ../programs/rofi.nix
    ../programs/starship.nix
    ../programs/zoxide.nix
    ../gtk.nix
    ../utilities.nix
    ../desktop/xdg-desktop-entries.nix
    ../apps.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home = {
    username = "rabbit";
    homeDirectory = "/home/rabbit";
  };

  programs.home-manager.enable = true;

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    EDITOR = "nvim";
    MANPAGER = "nvim +Man!";
    MANWIDTH = "80";
  };

  systemd.user.startServices = "sd-switch";
  home.stateVersion = "24.05";
}

