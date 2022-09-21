#!/usr/bin/env bash

WORKSPACE_DIR=~/brain/config/home/workspaces

# helpers
function colorize() {
  sed "s/^.*$/$(printf "\033[34m")&$(printf "\033[0m")/g" <<<"$1"
}
function decolorize() {
  sed 's/\x1b\[[0-9;]*m//g' <<<"$1"
}

# collect sessions (active and workspaces)
CURRENT_SESSIONS=$(tmux ls | cut -d":" -f1)
WORKSPACES=$(
  cat "$WORKSPACE_DIR"/* | grep session_name | sed -e 's/.*:\s//'
)
INACTIVE_WORKSPACES=$(comm -23 <(echo "$WORKSPACES") <(echo "$CURRENT_SESSIONS"))

# build session list
COLORIZED_CURRENT_SESSIONS=$(colorize "$CURRENT_SESSIONS")
if [[ "$CURRENT_SESSIONS" ]]; then
  SESSIONS=$(printf "%s\n%s" "$COLORIZED_CURRENT_SESSIONS" "$INACTIVE_WORKSPACES")
else
  SESSIONS="$INACTIVE_WORKSPACES"
fi

# use arg-provided session or prompt user to select one
if [ "$1" != "" ]; then
  SESSION="$1"
else
  SESSION=$(echo "$SESSIONS" | fzf --ansi --preview-window up:1 --reverse --cycle +s -e --prompt "session: ")
  SESSION=$(decolorize "$SESSION")
fi

# cancel if not session was selected
if [ "$SESSION" = "" ]; then
  exit 1
fi

# create/restore
if [ "$TMUX" != "" ]; then
  # inside tmux, switch
  tmux switch-client -t "$SESSION" || tmuxp load "$SESSION" 2>/dev/null || tmux -2 new-session -d -s "$SESSION" && tmux switch-client -t "$SESSION"
else
  SESSION_FILE="$WORKSPACE_DIR/$SESSION.yml"
  tmux attach -t "$SESSION" || tmuxp load "$SESSION_FILE" || tmux new -s "$SESSION"
fi
