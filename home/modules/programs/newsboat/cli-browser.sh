#!/usr/bin/env bash
set -uf -o pipefail
IFS=$'\n\t'

URL="$1"

# go install github.com/mrusme/reader@latest

HR=$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' "-")
HEADER=$(printf " URL: %s\n%s\n" "$URL" "$HR")
CONTENT=$(~/go/bin/reader "$URL")

echo "$HEADER$CONTENT" | bat --paging=always --pager="less -R -c" --style=plain,grid,snip
exit 0
