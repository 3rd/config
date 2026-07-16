#!/usr/bin/env bash

set -euo pipefail

if [[ -z ${XDG_RUNTIME_DIR:-} ]]; then
  printf 'desktop-menu: XDG_RUNTIME_DIR is required\n' >&2
  exit 1
fi

readonly ROFI_PID_FILE="$XDG_RUNTIME_DIR/desktop-menu-rofi.pid"
readonly ACTION_LABELS=(
  "Applications"
  "Windows"
  "Calculator"
)

declare -a displayed_labels=("${ACTION_LABELS[@]}")
declare -a unavailable_reasons=()

mark_unavailable() {
  local index=$1
  local reason=$2

  displayed_labels[index]="${ACTION_LABELS[index]} — unavailable"
  unavailable_reasons[index]=$reason
}

rofi_help="$(rofi -help 2>&1 || true)"
grep -Fq -- '-display-calc' <<<"$rofi_help" || mark_unavailable 2 "Rofi calc mode"

show_unavailable() {
  local reason=$1
  local message="desktop-menu: $reason is unavailable"

  printf '%s\n' "$message" >&2
  if ! rofi -e "$message" -pid "$ROFI_PID_FILE" -replace; then
    printf 'desktop-menu: failed to display the unavailable-owner error\n' >&2
  fi
  return 127
}

run_rofi_mode() {
  local mode=$1
  shift
  local status

  if rofi -show "$mode" -pid "$ROFI_PID_FILE" -replace "$@"; then
    return 0
  else
    status=$?
  fi

  if ((status == 1)); then
    return 0
  fi

  printf 'desktop-menu: Rofi %s mode failed with status %d\n' "$mode" "$status" >&2
  return "$status"
}

selection=""
if selection="$(
  printf '%s\n' "${displayed_labels[@]}" \
    | rofi \
      -dmenu \
      -i \
      -no-custom \
      -format i \
      -p "Desktop" \
      -pid "$ROFI_PID_FILE" \
      -replace
)"; then
  status=0
else
  status=$?
fi

if ((status == 1)); then
  exit 0
fi
if ((status != 0)); then
  printf 'desktop-menu: selector failed with status %d\n' "$status" >&2
  exit "$status"
fi
if [[ ! $selection =~ ^[0-9]+$ ]] || ((selection < 0 || selection >= ${#ACTION_LABELS[@]})); then
  printf 'desktop-menu: unexpected selection: %s\n' "$selection" >&2
  exit 2
fi
if [[ -n ${unavailable_reasons[selection]:-} ]]; then
  show_unavailable "${unavailable_reasons[selection]}"
  exit $?
fi

case "$selection" in
  0) run_rofi_mode drun ;;
  1) run_rofi_mode window ;;
  2) run_rofi_mode calc ;;
esac
