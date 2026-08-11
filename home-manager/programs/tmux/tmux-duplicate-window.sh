#!/usr/bin/env bash

# open a new window with the current window's pane count and layout, running nothing

LAYOUT=$(tmux display-message -p '#{window_layout}')
PANE_COUNT=$(tmux display-message -p '#{window_panes}')
PATH_CURRENT=$(tmux display-message -p '#{pane_current_path}')

FIRST_PANE=$(tmux new-window -a -P -F '#{pane_id}' -c "$PATH_CURRENT")

PANE="$FIRST_PANE"
while [ "$PANE_COUNT" -gt 1 ]; do
  PANE=$(tmux split-window -t "$PANE" -P -F '#{pane_id}' -c "$PATH_CURRENT")
  # keep panes even so later splits still have room
  tmux select-layout -t "$FIRST_PANE" tiled
  PANE_COUNT=$((PANE_COUNT - 1))
done

tmux select-layout -t "$FIRST_PANE" "$LAYOUT"
