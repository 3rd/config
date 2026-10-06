#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

sshSourcePath=$1
sshTargetPath=$2
if [[ "$sshSourcePath" -ef "$sshTargetPath" ]]; then
  exit 0
fi

sshFilePaths=("$sshSourcePath/config" "$sshSourcePath/"*.pub)

for sshFilePath in "${sshFilePaths[@]}"; do
  if [[ ! -f "$sshFilePath" ]]; then
    printf 'Missing SSH source file: %s\n' "$sshFilePath" >&2
    exit 1
  fi

  sshLinkPath="$sshTargetPath/${sshFilePath##*/}"
  if [[ -e "$sshLinkPath" || -L "$sshLinkPath" ]] && [[ ! "$sshFilePath" -ef "$sshLinkPath" ]]; then
    printf 'Refusing to replace SSH file: %s\n' "$sshLinkPath" >&2
    exit 1
  fi
done

if [[ ! -d "$sshTargetPath" ]]; then
  mkdir -m 700 -- "$sshTargetPath"
fi

for sshFilePath in "${sshFilePaths[@]}"; do
  sshLinkPath="$sshTargetPath/${sshFilePath##*/}"
  if [[ "$sshFilePath" -ef "$sshLinkPath" ]]; then
    continue
  fi

  ln -s -- "$sshFilePath" "$sshLinkPath"
done

if [[ -L "$sshTargetPath/ssh" && "$sshTargetPath/ssh" -ef "$sshSourcePath" ]]; then
  unlink -- "$sshTargetPath/ssh"
fi
