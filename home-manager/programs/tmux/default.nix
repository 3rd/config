{
  config,
  pkgs,
  pkgs-stable,
  ...
}:

let
  scripts = {
    tmux-workspace = pkgs.writeShellScriptBin "tmux-workspace" (builtins.readFile ./tmux-workspace.sh);
    tmux-duplicate-window = pkgs.writeShellScriptBin "tmux-duplicate-window" (
      builtins.readFile ./tmux-duplicate-window.sh
    );
    tmux-desktop-environment = pkgs.writeShellScriptBin "tmux-desktop-environment" (
      builtins.readFile ./tmux-desktop-environment.sh
    );
    tmux-pane-handles-navigation =
      pkgs.runCommand "tmux-pane-handles-navigation"
        {
          nativeBuildInputs = [ pkgs.stdenv.cc ];
        }
        ''
          mkdir -p "$out/bin"
          cc -std=c11 -O2 -Wall -Wextra -Werror \
            ${./tmux-pane-handles-navigation.c} \
            -o "$out/bin/tmux-pane-handles-navigation"
        '';
  };
in
{
  imports = [ ../../colors.nix ];

  # https://github.com/nix-community/home-manager/blob/master/modules/programs/tmux.nix
  # programs.tmux = { enable = true; };
  # xdg.configFile."tmux/tmux.conf".source = ./tmux.conf;

  xdg.configFile."tmux/theme.conf".text = with config.colors; ''
    set -g status-style "bg=${gray-darker},fg=${gray-lightest}"

    if-shell '[ -n "$SSH_CONNECTION" ]' \
      'set -g status-left "#[bg=${red-darkest},fg=${red-lightest},bold] SSH #[bg=${gray-darker},fg=${gray-lighter}] #S #[default]"' \
      'set -g status-left " #[fg=${gray-lighter},bg=${gray-darker}]#[bg=${gray-lighter},fg=${background},bold]λ#[fg=${gray-lighter},bg=${gray-darker}]#[fg=${gray-lighter},nobold] #S #[default]"'

    set -g status-right "#[bg=${gray-darkish},fg=${gray-lightest}] %H:%M #[bg=${gray-dark},fg=${gray-lighter}] %b %d #[default]"

    set -g window-status-style "fg=${gray-medium}"
    set -g window-status-format " #[fg=${gray-medium}]#I#[fg=${gray-darkish}]:#[fg=${gray-medium}]#W#{?window_zoomed_flag,#[fg=${gray-lighter}],} "

    set -g window-status-activity-style "fg=${yellow-light}"

    set -g window-status-current-style "fg=${gray-lightest}"
    set -g window-status-current-format " #[fg=${gray-lighter},bold]#I#[fg=${gray-light}]:#[fg=${gray-lightest}]#W#{?window_zoomed_flag,#[fg=${gray-lightest}],} "

    set -g pane-active-border-style "bg=default,fg=${gray-darkish}"
    set -g pane-border-style "bg=default,fg=${gray-darker}"
    set -g pane-border-format " #{?pane_active,#[fg=${gray-lighter}],#[fg=${gray-darkish}]}#{pane_current_command} #[fg=${gray-medium}]· #{?pane_active,#[fg=${gray-light}],#[fg=${gray-darkish}]}#{E:@pane-short-current-path} "
  '';

  home.packages = with pkgs; [
    # pinned to stable: tmux 3.7b wedges the server when an ssh client dies
    # uncleanly (tmux/tmux#5455); also limits client/server version drift
    pkgs-stable.tmux
    pkgs-stable.tmuxp
    scripts.tmux-workspace
    scripts.tmux-duplicate-window
    scripts.tmux-desktop-environment
    scripts.tmux-pane-handles-navigation
  ];
  programs.fish.shellAliases = {
    t = "tmux-workspace";
  };
}
