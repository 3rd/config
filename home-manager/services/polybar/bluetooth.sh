#!/usr/bin/env bash

set -euo pipefail

readonly UNAVAILABLE_LABEL="%{F#66ffffff}%{F-}"
readonly POWERED_OFF_LABEL="%{F#66ffffff}%{F-}"
readonly DISCONNECTED_LABEL=""
readonly CONNECTED_LABEL="%{F#2193ff}%{F-}"

last_label=""
monitor_pid=""
monitor_dir=""
monitor_input_fd=""

run_bluetoothctl() {
  timeout --foreground 2s bluetoothctl "$@"
}

controller_state() {
  local output controller_line controller powered_line powered

  if ! output="$(run_bluetoothctl show 2>/dev/null)"; then
    return 1
  fi

  controller_line="$(grep -m1 '^Controller ' <<< "$output" || true)"
  powered_line="$(grep -m1 '^[[:space:]]*Powered: ' <<< "$output" || true)"

  if ! grep -Eq '^Controller ([[:xdigit:]]{2}:){5}[[:xdigit:]]{2} ' <<< "$controller_line"; then
    return 1
  fi

  controller="${controller_line#Controller }"
  controller="${controller%% *}"
  powered="${powered_line##*Powered: }"

  case "$powered" in
    yes | no) printf '%s\t%s\n' "$controller" "$powered" ;;
    *) return 1 ;;
  esac
}

query_label() {
  local controllers state powered connected output_line

  if ! controllers="$(run_bluetoothctl list 2>/dev/null)"; then
    printf '%s\n' "$UNAVAILABLE_LABEL"
    return 2
  fi

  if ! grep -q '^Controller ' <<< "$controllers"; then
    printf '%s\n' "$UNAVAILABLE_LABEL"
    return 3
  fi

  if ! state="$(controller_state)"; then
    printf '%s\n' "$UNAVAILABLE_LABEL"
    return 2
  fi

  IFS=$'\t' read -r _ powered <<< "$state"
  if [ "$powered" = "no" ]; then
    printf '%s\n' "$POWERED_OFF_LABEL"
    return 0
  fi

  if ! connected="$(run_bluetoothctl devices Connected 2>/dev/null)"; then
    printf '%s\n' "$UNAVAILABLE_LABEL"
    return 2
  fi

  while IFS= read -r output_line; do
    [ -z "$output_line" ] && continue
    if ! grep -Eq '^Device ([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}( .*)?$' <<< "$output_line"; then
      printf '%s\n' "$UNAVAILABLE_LABEL"
      return 2
    fi
  done <<< "$connected"

  if grep -q '^Device ' <<< "$connected"; then
    printf '%s\n' "$CONNECTED_LABEL"
  else
    printf '%s\n' "$DISCONNECTED_LABEL"
  fi
}

emit_label() {
  local label="$1"

  if [ "$label" != "$last_label" ]; then
    printf '%s\n' "$label"
    last_label="$label"
  fi
}

emit_current_label() {
  local label result

  if label="$(query_label)"; then
    result=0
  else
    result=$?
  fi

  emit_label "$label"
  return "$result"
}

status() {
  local label

  if label="$(query_label)"; then
    printf '%s\n' "$label"
    return 0
  fi

  printf '%s\n' "$label"
  return 1
}

watch() {
  local initial_result=0 monitor_output_fd event result monitor_ready=false

  emit_current_label || initial_result=$?
  if [ "$initial_result" -eq 2 ]; then
    return 1
  fi

  cleanup_monitor() {
    if [ -n "$monitor_pid" ] && kill -0 "$monitor_pid" 2>/dev/null; then
      kill "$monitor_pid" 2>/dev/null || true
    fi
    if [ -n "$monitor_pid" ]; then
      wait "$monitor_pid" 2>/dev/null || true
    fi
    if [ -n "$monitor_input_fd" ]; then
      exec {monitor_input_fd}>&-
    fi
    if [ -n "$monitor_dir" ]; then
      rm -f -- "$monitor_dir/input"
      rmdir -- "$monitor_dir" 2>/dev/null || true
    fi
  }
  trap cleanup_monitor EXIT
  trap 'exit 1' INT TERM

  monitor_dir="$(mktemp -d)"
  mkfifo "$monitor_dir/input"
  exec {monitor_input_fd}<>"$monitor_dir/input"
  coproc BLUETOOTH_MONITOR {
    bluetoothctl --monitor < "$monitor_dir/input" 2>&1
  }
  monitor_pid=$BLUETOOTH_MONITOR_PID
  monitor_output_fd=${BLUETOOTH_MONITOR[0]}

  while IFS= read -r event <&"$monitor_output_fd"; do
    case "$event" in
      *"Waiting to connect to bluetoothd"*)
        if [ "$monitor_ready" = true ]; then
          emit_label "$UNAVAILABLE_LABEL"
          return 1
        fi
        ;;
      *"Agent registered"*)
        monitor_ready=true
        ;;
      *"Controller "*)
        monitor_ready=true
        result=0
        emit_current_label || result=$?
        if [ "$result" -eq 2 ]; then
          return 1
        fi
        ;;
      *"Device "*" Connected: "* | *NEW*" Device "* | *DEL*" Device "*)
        result=0
        emit_current_label || result=$?
        if [ "$result" -eq 2 ]; then
          return 1
        fi
        ;;
    esac
  done

  emit_label "$UNAVAILABLE_LABEL"
  return 1
}

toggle_power() {
  local state controller powered target

  if ! state="$(controller_state)"; then
    printf 'polybar-bluetooth: selected controller is unavailable\n' >&2
    return 1
  fi

  IFS=$'\t' read -r controller powered <<< "$state"
  if [ "$powered" = "yes" ]; then
    target=off
  else
    target=on
  fi

  expect -f - "$controller" "$target" <<'EXPECT'
set timeout 5
set controller [lindex $argv 0]
set target [lindex $argv 1]
log_user 0

if {[catch {spawn -noecho bluetoothctl} error]} {
  puts stderr "polybar-bluetooth: failed to start bluetoothctl: $error"
  exit 1
}

expect {
  -re "Controller $controller" {}
  -re {Waiting to connect to bluetoothd} {
    puts stderr "polybar-bluetooth: BlueZ is unavailable"
    exit 1
  }
  timeout {
    puts stderr "polybar-bluetooth: timed out waiting for the selected controller"
    exit 1
  }
  eof {
    puts stderr "polybar-bluetooth: bluetoothctl exited before selecting the controller"
    exit 1
  }
}

send -- "select $controller\r"
expect {
  -re "select $controller\\r?\\n" {}
  timeout {
    puts stderr "polybar-bluetooth: timed out sending the controller selection"
    exit 1
  }
  eof {
    puts stderr "polybar-bluetooth: bluetoothctl exited before selecting the controller"
    exit 1
  }
}
expect {
  -re "Controller $controller not available" {
    puts stderr "polybar-bluetooth: selected controller disappeared"
    exit 1
  }
  -re {\[[^]]+\]>} {}
  timeout {
    puts stderr "polybar-bluetooth: timed out selecting the controller"
    exit 1
  }
  eof {
    puts stderr "polybar-bluetooth: bluetoothctl exited while selecting the controller"
    exit 1
  }
}

send -- "power $target\r"
expect {
  -re "power $target\\r?\\n" {}
  timeout {
    puts stderr "polybar-bluetooth: timed out sending the power toggle"
    exit 1
  }
  eof {
    puts stderr "polybar-bluetooth: bluetoothctl exited before the power toggle"
    exit 1
  }
}
expect {
  -re "Changing power $target succeeded" {
    send -- "quit\r"
    exit 0
  }
  -re {Failed to set power[^\r\n]*} {
    puts stderr "polybar-bluetooth: power toggle failed"
    exit 1
  }
  -re {No default controller available} {
    puts stderr "polybar-bluetooth: selected controller disappeared"
    exit 1
  }
  timeout {
    puts stderr "polybar-bluetooth: power toggle timed out"
    exit 1
  }
  eof {
    puts stderr "polybar-bluetooth: bluetoothctl exited during the power toggle"
    exit 1
  }
}
EXPECT
}

usage() {
  printf 'usage: polybar-bluetooth {watch|status|toggle-power}\n' >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

case "$1" in
  watch) watch ;;
  status) status ;;
  toggle-power) toggle_power ;;
  *)
    usage
    exit 2
    ;;
esac
