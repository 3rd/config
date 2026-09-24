#!/usr/bin/env bash

WORKSPACE_DIR=~/brain/config/workspaces
CLIENT=""
CLIENT_STATE=""
SOCKET=""
KILL_SESSION=""
SESSION=""
TMUX_COMMAND=(tmux)
TMUXP_OPTIONS=()

# helpers
readClientState() {
  local name pid session

  while IFS=$'\t' read -r name pid session; do
    if [[ "$name" == "$CLIENT" ]]; then
      printf '%s:%s\n' "$pid" "$session"
      return 0
    fi
  done < <("${TMUX_COMMAND[@]}" list-clients -F $'#{client_name}\t#{client_pid}\t#{session_id}')

  return 1
}

fail() {
  local currentState

  printf 'tmux-workspace: %s\n' "$1" >&2

  if [[ -n "$CLIENT_STATE" ]]; then
    currentState=$(readClientState 2>/dev/null)
    if [[ "${currentState%%:*}" == "${CLIENT_STATE%%:*}" ]]; then
      "${TMUX_COMMAND[@]}" display-message -l -c "$CLIENT" -d 10000 "tmux-workspace: $1"
    fi
  fi

  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client|--socket|--kill-session)
      [[ $# -ge 2 && -n "$2" ]] || fail "Missing value for $1."

      case "$1" in
        --client) CLIENT=$2 ;;
        --socket) SOCKET=$2 ;;
        --kill-session) KILL_SESSION=$2 ;;
      esac

      shift 2
      ;;
    --)
      shift
      [[ $# -le 1 && -z "$SESSION" ]] || fail "Expected at most one session name."
      SESSION=${1:-}
      break
      ;;
    -*)
      fail "Unknown option: $1"
      ;;
    *)
      [[ -z "$SESSION" ]] || fail "Expected at most one session name."
      SESSION=$1
      shift
      ;;
  esac
done

if [[ -z "$SOCKET" && -n "${TMUX:-}" ]]; then
  SOCKET=${TMUX%,*}
  SOCKET=${SOCKET%,*}
fi

if [[ -n "$SOCKET" ]]; then
  TMUX_COMMAND+=(-S "$SOCKET")
  TMUXP_OPTIONS+=(-S "$SOCKET")
fi

if [[ -z "$CLIENT" && -n "${TMUX:-}" ]]; then
  mapfile -t CLIENTS < <(
    while read -r session pane; do
      if [[ "$pane" == "${TMUX_PANE:-}" ]]; then
        "${TMUX_COMMAND[@]}" list-clients -t "$session" -F '#{client_name}'
      fi
    done < <("${TMUX_COMMAND[@]}" list-panes -a -F '#{session_id} #{pane_id}')
  )
  [[ ${#CLIENTS[@]} -eq 1 ]] || fail "Cannot identify a single terminal for this pane. Use Ctrl-a ; to switch only your terminal."
  CLIENT=${CLIENTS[0]}
fi

if [[ -n "$CLIENT" ]]; then
  CLIENT_STATE=$(readClientState) || fail "The initiating tmux client is no longer attached."
fi

if [[ -n "$KILL_SESSION" ]]; then
  [[ -n "$CLIENT_STATE" && "$KILL_SESSION" == "${CLIENT_STATE#*:}" ]] || fail "The session to kill is not the initiating client's session."
fi

# use arg-provided session or prompt user to select one
if [[ -z "$SESSION" ]]; then
  # collect sessions (active and workspaces)
  CURRENT_SESSIONS=$("${TMUX_COMMAND[@]}" list-sessions -F '#{session_name}' 2>/dev/null)
  SESSIONS=()

  # build session list
  while IFS= read -r session; do
    if [[ -n "$session" ]]; then
      SESSIONS+=($'\033[34m'"$session"$'\033[0m')
    fi
  done <<<"$CURRENT_SESSIONS"

  for file in "$WORKSPACE_DIR"/*.yml; do
    [[ -f "$file" ]] || continue
    session=${file##*/}
    session=${session%.yml}

    if [[ $'\n'"$CURRENT_SESSIONS"$'\n' != *$'\n'"$session"$'\n'* ]]; then
      SESSIONS+=("$session")
    fi
  done

  [[ ${#SESSIONS[@]} -gt 0 ]] || fail "No sessions or saved workspaces found. Pass a session name to create one."
  SESSION=$(printf '%s\n' "${SESSIONS[@]}" | fzf --ansi --preview-window up:1 --reverse --cycle +s -e --prompt "Session: ")
  PICKER_STATUS=$?

  # cancel if no session was selected
  if [[ $PICKER_STATUS -eq 1 || $PICKER_STATUS -eq 130 ]]; then
    exit 130
  fi

  [[ $PICKER_STATUS -eq 0 ]] || fail "The session picker failed."
  [[ -n "$SESSION" ]] || exit 130
fi

if [[ -n "$CLIENT" ]]; then
  [[ "$(readClientState)" == "$CLIENT_STATE" ]] || fail "The initiating tmux client changed or disconnected."
fi

# create/restore
SESSION_FILE="$WORKSPACE_DIR/$SESSION.yml"
if ! "${TMUX_COMMAND[@]}" has-session -t "=$SESSION" 2>/dev/null; then
  if [[ -f "$SESSION_FILE" ]]; then
    LOAD_OUTPUT=$(tmuxp load -d -y "${TMUXP_OPTIONS[@]}" "$SESSION_FILE" </dev/null 2>&1) || fail "$LOAD_OUTPUT"
  else
    "${TMUX_COMMAND[@]}" new-session -d -s "$SESSION" || fail "Could not create session: $SESSION"
  fi
fi

DESTINATION=$("${TMUX_COMMAND[@]}" display-message -p -t "=$SESSION:" '#{session_id}')
[[ -n "$DESTINATION" ]] || fail "The destination session is unavailable: $SESSION"

if [[ -z "$CLIENT" ]]; then
  exec "${TMUX_COMMAND[@]}" attach-session -t "$DESTINATION"
fi

[[ "$(readClientState)" == "$CLIENT_STATE" ]] || fail "The initiating tmux client changed or disconnected."
[[ "$DESTINATION" != "${CLIENT_STATE#*:}" ]] || exit 0

# inside tmux, switch
if [[ -n "$KILL_SESSION" ]]; then
  SWITCH_OUTPUT=$("${TMUX_COMMAND[@]}" switch-client -c "$CLIENT" -t "$DESTINATION" \; kill-session -t "$KILL_SESSION" 2>&1) || fail "$SWITCH_OUTPUT"
else
  SWITCH_OUTPUT=$("${TMUX_COMMAND[@]}" switch-client -c "$CLIENT" -t "$DESTINATION" 2>&1) || fail "$SWITCH_OUTPUT"
fi
