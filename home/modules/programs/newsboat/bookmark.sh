#!/usr/bin/env bash
set -uf -o pipefail
IFS=$'\n\t'

BOOKMARK_FILE=~/brain/wiki/bookmarks

[ "$#" -eq 0 ] && exit 1
if [ "$(command -v curl)" != "" ]; then
  url=$(curl -sIL -o /dev/null -w '%{url_effective}' "$1")
else
  url="$1"
fi

url=$(echo "$url" | perl -p -e 's/(\?|\&)?utm_[a-z]+=[^\&]+//g;' -e 's/(#|\&)?utm_[a-z]+=[^\&]+//g;')
title=$(echo "$2" | w3m -dump -T text/html | tr '\n' ' ' | tr "[" "(" | tr "]" ")")
# description="$3"
domain=$(echo "$url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

month_heading="* $(date +"%B %Y")"
grep -F -q "$month_heading" "$BOOKMARK_FILE" || echo "$month_heading" >>"$BOOKMARK_FILE"

day_heading="** $(date +"%Y/%m/%d")"
grep -F -q "$day_heading" "$BOOKMARK_FILE" || echo "$day_heading" >>"$BOOKMARK_FILE"

content="  - [$title ($domain)]($url)"
grep -F -q "[$url]" "$BOOKMARK_FILE" || echo "$content" >>"$BOOKMARK_FILE"
