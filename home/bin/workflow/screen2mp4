#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  if [ "$#" -ne 1 ]; then
    echo "screen2mp4 target.mp4"
    exit 0
  fi

  slop=$(slop -f "%x %y %w %h %g %i") || exit 1
  IFS=$' ' read -r X Y W H _ < <(echo "$slop")

  ffmpeg -loglevel "16" \
    -f "x11grab" \
    -framerate "60" \
    -s "${W}x$H" -i ":0.0+$X,$Y" \
    -c:v "h264" \
    -preset "fast" \
    "$1"
fi
