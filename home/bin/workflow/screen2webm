#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  if [ "$#" -ne 1 ]; then
    echo "screen2webm target.webm"
    exit 0
  fi

  slop=$(slop -f "%x %y %w %h %g %i") || exit 1
  IFS=$' ' read -r X Y W H _ < <(echo "$slop")
  ffmpeg -f alsa -ac 2 -i pulse -f x11grab -s "${W}x$H" -i ":0.0+$X,$Y" -r 60 -acodec libvorbis -ab 320000 -vb 840000 -vcodec libvpx -threads 0 "$1"
fi
