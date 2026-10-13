#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

binRoot=$1
if [[ ! -d "$binRoot" ]]; then
  exit 0
fi

commandsPath="$binRoot/.commands"
if [[ -L "$commandsPath" ]]; then
  printf 'Refusing to use symlink as command directory: %s\n' "$commandsPath" >&2
  exit 1
fi

mkdir -p -- "$commandsPath"
exec {lockFd}>>"$commandsPath/.lock"
flock --exclusive "$lockFd"

for entryPath in "$binRoot"/*/src/index.ts; do
  if [[ ! -f "$entryPath" || ! -x "$entryPath" ]]; then
    continue
  fi

  utilityPath=${entryPath%/src/index.ts}
  commandName=${utilityPath##*/}
  commandPath="$commandsPath/$commandName"
  linkTarget="../$commandName/src/index.ts"
  if [[ -L "$commandPath" && "$(readlink -- "$commandPath")" == "$linkTarget" ]]; then
    continue
  fi

  if [[ -e "$commandPath" || -L "$commandPath" ]]; then
    printf 'Refusing to replace command: %s\n' "$commandPath" >&2
    exit 1
  fi

  ln -s -- "$linkTarget" "$commandPath"
done

for commandPath in "$commandsPath"/*; do
  if [[ ! -L "$commandPath" ]]; then
    continue
  fi

  commandName=${commandPath##*/}
  linkTarget=$(readlink -- "$commandPath")
  if [[ "$linkTarget" == "../$commandName/src/index.ts" && ( ! -f "$commandPath" || ! -x "$commandPath" ) ]]; then
    rm -- "$commandPath"
  fi
done
