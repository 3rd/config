#!/usr/bin/env bash

set -euo pipefail

TMUX_SOCKET=$1
DESKTOP_ENVIRONMENT=$(
  systemctl --user show-environment --output=json | jq -e '
    {DISPLAY, XAUTHORITY}
    | if all(.[]; type == "string" and length > 0) then .
      else error("The graphical session must publish DISPLAY and XAUTHORITY")
      end
  '
)
SESSION_IDS=$(tmux -S "$TMUX_SOCKET" list-sessions -F '#{session_id}')

while IFS= read -r name; do
  value=$(jq -r --arg name "$name" '.[$name]' <<<"$DESKTOP_ENVIRONMENT")
  tmux -S "$TMUX_SOCKET" set-environment -g "$name" "$value"

  while IFS= read -r session; do
    if [ -n "$session" ]; then
      tmux -S "$TMUX_SOCKET" set-environment -u -t "$session" "$name"
    fi
  done <<<"$SESSION_IDS"
done < <(jq -r 'keys[]' <<<"$DESKTOP_ENVIRONMENT")
