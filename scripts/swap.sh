#!/usr/bin/env bash
set -uf -o pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
REMOTE=$(git remote -v | grep origin | grep fetch | awk '{print $2}')

function swap() {
  TMP_PATH=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
  mv "$1" "$TMP_PATH"
  mv "$2" "$1"
  mv "$TMP_PATH" "$2"
}

if [[ $REMOTE == *"github"* ]]; then
  echo "Public -> Private"
else
  echo "Private -> Public"
fi

swap "$ROOT/.git" "$ROOT/.git-alt"
swap "$ROOT/.gitignore" "$ROOT/.gitignore-alt"
