#!/usr/bin/env bash
set -uf -o pipefail
IFS=$'\n\t'

CONFIG_DIR=$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit
  pwd -P
)
REMOTE=$(git remote -v | grep origin | grep fetch | awk '{print $2}')

# if remote contains "github"
if [[ $REMOTE == *"github"* ]]; then
  echo "Public -> Private"
else
  echo "Private -> Public"
fi

swap "$CONFIG_DIR/.git" "$CONFIG_DIR/.alt-git"
swap "$CONFIG_DIR/.gitignore" "$CONFIG_DIR/.alt-gitignore"
