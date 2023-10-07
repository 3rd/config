#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="$1"
CONFIG_DIR=$(realpath "$(dirname "$0")/..")
NIX_CONFIGURATION="$CONFIG_DIR/machines/$(hostname)/configuration.nix"
NIX_FLAKE="$CONFIG_DIR/machines/$(hostname)/flake.nix"
NIX_FLAKE_LOCK="$CONFIG_DIR/machines/$(hostname)/flake.lock"
NIX_HOME="$CONFIG_DIR/machines/$(hostname)/home.nix"

function setup_nixos() {
  echo "- configuration.nix: yes"
  sudo ln -sTf "$NIX_CONFIGURATION" /etc/nixos/configuration.nix
  # sudo ln -sTf "$NIX_FLAKE" /etc/nixos/flake.nix
  sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos
  sudo nix-channel --add https://nixos.org/channels/nixos-20.09 nixos-stable
  sudo nix-channel --update
  sudo nixos-rebuild switch --upgrade
}

function setup_home_manager() {
  echo "- home.nix: yes"
  mkdir -p "$HOME/.config/home-manager"
  ln -sTf "$NIX_HOME" "$HOME/.config/home-manager/home.nix"
  nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
  nix-channel --update
  export NIX_PATH=$HOME/.nix-defexpr/channels${NIX_PATH:+:}$NIX_PATH
  nix-shell "<home-manager>" -A install
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
  fi
}

main
