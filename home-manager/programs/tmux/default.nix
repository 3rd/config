{
  config,
  lib,
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
    set -g @agent-attention-count '#{n:#{P:#{?@agent-attention,1,}}}'
    set -g @agent-attention-badge '#{?#{E:@agent-attention-count},#[bg=#955DB7#,fg=${selection-foreground}#,#{?window_active,bold,nobold}] #{E:@agent-attention-count} #[default],}'
    set -g window-status-format "#{?#{E:@agent-attention-count},#[bg=#4B455D#,fg=${foreground}] #I:#W #[default], #[fg=${gray-medium}]#I#[fg=${gray-darkish}]:#[fg=${gray-medium}]#W#{?window_zoomed_flag,#[fg=${gray-lighter}],}}#{E:@agent-attention-badge} "

    set -g window-status-activity-style "fg=${lib.toLower yellow-light}"

    set -g window-status-current-style "fg=${gray-lightest}"
    set -g window-status-current-format "#{?#{E:@agent-attention-count},#[bg=#5C526C#,fg=${foreground}#,bold] #I:#W #[default], #[fg=${gray-lighter}#,bold]#I#[fg=${gray-light}]:#[fg=${gray-lightest}]#W#{?window_zoomed_flag,#[fg=${gray-lightest}],}}#{E:@agent-attention-badge} "

    set -g pane-active-border-style "bg=default,fg=#{?@agent-attention,${magenta-light},${gray-darkish}}"
    set -g pane-border-style "bg=default,fg=#{?@agent-attention,${magenta-dark},${gray-darker}}"
    set -g pane-border-format " #{?@agent-attention,#[fg=${magenta-lighter}]#{pane_current_command} · #{E:@pane-short-current-path},#{?pane_active,#[fg=${gray-lighter}],#[fg=${gray-darkish}]}#{pane_current_command} #[fg=${gray-medium}]· #{?pane_active,#[fg=${gray-light}],#[fg=${gray-darkish}]}#{E:@pane-short-current-path}} "
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
