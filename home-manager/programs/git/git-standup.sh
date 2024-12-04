#!/usr/bin/env bash
set -euf -o pipefail

git log --author="$(git config user.email)" --format="%C(yellow)%h%Creset|%C(bold blue)%s%Creset|%C(green)%ad%Creset %+|-" --shortstat --date=format:"%Y-%m-%d %H:%M" | grep -v "^$" | paste -d"|" - - | sed -E "s/([0-9]+) insertions?\(\+\)/\x1b[32m\1+\x1b[0m/g; s/([0-9]+) deletions?\(-\)/\x1b[31m\1-\x1b[0m/g" | column -t -s'|'
