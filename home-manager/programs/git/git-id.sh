#!/usr/bin/env bash
set -euf -o pipefail
IFS=$'\n\t'

identity_show() {
  echo "$(git config user.name) <$(git config user.email)>"
  git config user.signingkey
}

identity_switch() {
  identity=$(rg "\[user\s" <~/.config/git/config | sed -e "s/\[user\s\"*\(.*\)\"\]/\1/" | fzf)
  if [[ -n "$identity" ]]; then
    git config user.name "$(git config "user.$identity.name")"
    git config user.email "$(git config "user.$identity.email")"
    git config user.signingkey "$(git config "user.$identity.signingkey")"
    git config committer.name "$(git config "user.$identity.name")"
    git config committer.email "$(git config "user.$identity.email")"
    git config author.name "$(git config "user.$identity.name")"
    git config author.email "$(git config "user.$identity.email")"
  fi
  identity_show
}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  while getopts "s" arg; do
    case "$arg" in
      s) # switch
        identity_switch
        exit 0
        ;;
      *)
        exit 0
        ;;
    esac
  done
  identity_show
fi
