#!/usr/bin/env bash
set -euf -o pipefail
IFS=$'\n\t'
PS4='${LINENO}: '

USERNAME=$(whoami)
HOSTNAME=$(hostname)
TMPDIR=$(mktemp -d -t flakey.XXXXXXXXXX)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

#/ Usage: flakey
#/ Options:
#/   --help: Display this help message
#/   --nix: Build and switch to NixOS config
#/   --update: Update flakes
#/   --home: Build and switch to home-manager config

copy_relevant_files_to_tmpdir() {
  include=(
    ./home-manager
    ./hosts
    ./modules
    ./overlays
    ./roles
    ./flake.nix
    ./flake.lock
  )
  command cp -r "${include[@]}" "$TMPDIR"
  echo "Copied relevant files to $TMPDIR"
}

nix_switch() {
  echo "Building NixOS config"
  copy_relevant_files_to_tmpdir
  cd "$TMPDIR"
  sudo nixos-rebuild switch --show-trace --impure --flake .#"$HOSTNAME"
}

nix_update() {
  echo "Updating flake.lock"
  copy_relevant_files_to_tmpdir
  cd "$TMPDIR"
  nix flake update
}

home_switch() {
  echo "Building home-manager config"
  copy_relevant_files_to_tmpdir
  cd "$TMPDIR"
  home-manager --flake .#"$USERNAME"@"$HOSTNAME" switch --show-trace
}

help() {
  grep '^#/' "$0" | cut -c4-
}

if expr "$*" : ".*--nix" >/dev/null; then
  nix_switch
elif expr "$*" : ".*--update" >/dev/null; then
  nix_update
elif expr "$*" : ".*--home" >/dev/null; then
  home_switch
else
  help
fi

cleanup() {
  cd "$ROOT"
  if [[ -f "$TMPDIR/flake.lock" ]]; then
    mv "$TMPDIR/flake.lock" .
  fi
  rm -rf "$TMPDIR"
}
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  trap cleanup EXIT
fi
