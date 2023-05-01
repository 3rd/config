#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="$1"
CONFIG_DIR=$(realpath "$(dirname "$0")/..")
NIX_CONFIGURATION="$CONFIG_DIR/machines/$(hostname)/configuration.nix"
NIX_HOME="$CONFIG_DIR/machines/$(hostname)/home.nix"

function setup_nixos() {
  if test -f "$NIX_CONFIGURATION"; then
    echo "- configuration.nix: yes"
    sudo ln -sTf "$NIX_CONFIGURATION" /etc/nixos/configuration.nix
    sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos
    sudo nix-channel --add https://nixos.org/channels/nixos-20.09 nixos-stable
    sudo nix-channel --update
    sudo nixos-rebuild switch --upgrade
  else
    echo "- configuration.nix: no"
  fi
}

function setup_home_manager() {
  if test -f "$NIX_HOME"; then
    echo "- home.nix: yes"
    mkdir -p "$HOME/.config/nixpkgs"
    ln -sTf "$NIX_HOME" "$HOME/.config/home-manager/home.nix"
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    nix-channel --update
    export NIX_PATH=$HOME/.nix-defexpr/channels${NIX_PATH:+:}$NIX_PATH
    nix-shell "<home-manager>" -A install
  else
    echo "- home.nix: no"
  fi
}

function link() {
  make link
}

function main() {
  echo "Setup host: $(hostname)"
  read -p "Continue? " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    setup_nixos
    setup_home_manager
    # mkdir -p ~/.local/share/fonts
    # link
  fi
}

main
