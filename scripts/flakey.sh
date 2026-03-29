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
#/   --list: List files flakey stages before they are copied to the store

collect_relevant_paths() {
  include=(
    ./home-manager
    ./system
    ./flake.nix
    ./flake.lock
  )

  while IFS= read -r host_file; do
    include+=("$host_file")
  done < <(find "./hosts/$HOSTNAME" -type f -name '*.nix' | sort)

  printf '%s\n' "${include[@]}"
}

list_relevant_files() {
  local files=()

  while IFS= read -r path; do
    if [[ -d "$ROOT/$path" ]]; then
      while IFS= read -r file; do
        files+=("$file")
      done < <(cd "$ROOT" && find "$path" -type f | sort)
      continue
    fi

    files+=("$path")
  done < <(collect_relevant_paths)

  printf '%s\n' "${files[@]}"
  echo
  echo "Total files: ${#files[@]}"
  (
    cd "$ROOT"
    du -ch "${files[@]}" 2>/dev/null | tail -n 1
  )
}

copy_relevant_files_to_tmpdir() {
  local include=()

  while IFS= read -r path; do
    include+=("$path")
  done < <(collect_relevant_paths)

  (
    cd "$ROOT"
    command cp -a --parents "${include[@]}" "$TMPDIR"
  )
  echo "Copied relevant files to $TMPDIR"
}

nix_switch() {
  echo "Building NixOS config"
  copy_relevant_files_to_tmpdir
  cd "$TMPDIR"
  # sudo nixos-rebuild switch --impure --flake .#"$HOSTNAME"
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
elif expr "$*" : ".*--list" >/dev/null; then
  list_relevant_files
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
