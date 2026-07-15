#!/usr/bin/env bash

set -euo pipefail

readonly OSD_APP_NAME="Desktop OSD"
readonly ERROR_APP_NAME="Desktop Control Error"
readonly ERROR_NOTIFICATION_ID=9995
readonly VOLUME_NORMAL=65536

usage() {
  cat >&2 <<'EOF'
Usage:
  desktop-osd brightness up|down
  desktop-osd keyboard-brightness up|down
  desktop-osd volume up|down|toggle
  desktop-osd microphone toggle|mute
EOF
}

control_error() {
  local message=$1

  printf 'desktop-osd: %s\n' "$message" >&2
  notify-send \
    --app-name="$ERROR_APP_NAME" \
    --replace-id="$ERROR_NOTIFICATION_ID" \
    --urgency=critical \
    --expire-time=0 \
    --icon=dialog-error \
    "Desktop control failed" \
    "$message" || true
  return 1
}

send_osd() {
  local notification_id=$1
  local icon=$2
  local value=$3
  local summary=$4
  local body=$5

  notify-send \
    --app-name="$OSD_APP_NAME" \
    --replace-id="$notification_id" \
    --transient \
    --expire-time=1000 \
    --icon="$icon" \
    --hint="int:value:$value" \
    "$summary" \
    "$body"
}

clamp_percentage() {
  local value=$1

  if ((value < 0)); then
    printf '0\n'
  elif ((value > 100)); then
    printf '100\n'
  else
    printf '%d\n' "$value"
  fi
}

percentage_from_raw() {
  local current=$1
  local maximum=$2

  ((maximum > 0)) || return 1
  clamp_percentage "$(((current * 100 + maximum / 2) / maximum))"
}

raw_from_percentage() {
  local percentage=$1
  local maximum=$2

  printf '%d\n' "$(((percentage * maximum + 50) / 100))"
}

apply_direction_actions() {
  local percentage=$1
  local step=$2
  shift 2

  local action
  for action in "$@"; do
    case "$action" in
      up) percentage=$((percentage + step)) ;;
      down) percentage=$((percentage - step)) ;;
      *) return 1 ;;
    esac
    percentage=$(clamp_percentage "$percentage")
  done

  printf '%d\n' "$percentage"
}

read_integer() {
  local value

  value=$("$@") || return 1
  [[ $value =~ ^[0-9]+$ ]] || return 1
  printf '%d\n' "$value"
}

apply_brightnessctl() {
  local family=$1
  local label=$2
  local device=$3
  local step=$4
  shift 4

  local old_raw maximum old_percentage target_percentage target_raw actual_raw verified_percentage
  old_raw=$(read_integer brightnessctl --device="$device" get) || {
    control_error "$label device '$device' could not be read"
    return
  }
  maximum=$(read_integer brightnessctl --device="$device" max) || {
    control_error "$label device '$device' did not report a valid maximum"
    return
  }
  old_percentage=$(percentage_from_raw "$old_raw" "$maximum") || {
    control_error "$label device '$device' reported an invalid maximum of $maximum"
    return
  }
  target_percentage=$(apply_direction_actions "$old_percentage" "$step" "$@") || {
    control_error "$label received an invalid queued action"
    return
  }
  target_raw=$(raw_from_percentage "$target_percentage" "$maximum")

  if ((target_raw != old_raw)); then
    if ! brightnessctl --device="$device" set "$target_raw" >/dev/null; then
      if brightnessctl --device="$device" set "$old_raw" >/dev/null \
        && actual_raw=$(read_integer brightnessctl --device="$device" get) \
        && ((actual_raw == old_raw)); then
        control_error "$label update failed; previous value was restored"
      else
        control_error "$label update failed and rollback to $old_percentage% is unresolved"
      fi
      return
    fi
  fi

  actual_raw=$(read_integer brightnessctl --device="$device" get) || true
  if [[ -z ${actual_raw:-} ]] || ((actual_raw != target_raw)); then
    if brightnessctl --device="$device" set "$old_raw" >/dev/null \
      && actual_raw=$(read_integer brightnessctl --device="$device" get) \
      && ((actual_raw == old_raw)); then
      control_error "$label verification failed; previous value was restored"
    else
      control_error "$label verification failed and rollback to $old_percentage% is unresolved"
    fi
    return
  fi
  verified_percentage=$(percentage_from_raw "$actual_raw" "$maximum")

  case "$family" in
    brightness)
      send_osd 9991 display-brightness-symbolic "$verified_percentage" "Display brightness" "$verified_percentage%" || {
        control_error "Display brightness changed to $verified_percentage%, but its OSD could not be displayed"
        return
      }
      ;;
    keyboard-brightness)
      send_osd 9994 input-keyboard-symbolic "$verified_percentage" "Keyboard brightness" "$verified_percentage%" || {
        control_error "Keyboard brightness changed to $verified_percentage%, but its OSD could not be displayed"
        return
      }
      ;;
  esac
}

single_backlight_device() {
  local listing
  local -a devices=()

  listing=$(brightnessctl --class=backlight --list --machine-readable) || return 1
  mapfile -t devices < <(awk -F, 'NF { print $1 }' <<<"$listing")
  ((${#devices[@]} == 1)) || return 1
  printf '%s\n' "${devices[0]}"
}

connected_edids() {
  local properties

  properties=$(xrandr --prop) || return 1
  awk '
    /^[^[:space:]]+ (connected|disconnected)/ {
      connector = $1
      connected = ($2 == "connected")
      reading_edid = 0
    }
    /^[[:space:]]+EDID:/ {
      reading_edid = connected
      edid = ""
      next
    }
    reading_edid && /^[[:space:]]+[[:xdigit:]]+$/ {
      line = $0
      gsub(/[[:space:]]/, "", line)
      if (length(line) != 32) {
        reading_edid = 0
        next
      }
      edid = edid tolower(line)
      if (length(edid) == 256) {
        print connector "|" edid
        reading_edid = 0
      }
      next
    }
    reading_edid { reading_edid = 0 }
  ' <<<"$properties"
}

ddc_read_brightness() {
  local edid=$1
  local output marker code value_type current maximum extra

  output=$(ddcutil --edid "$edid" --terse getvcp 10 2>/dev/null) || return 1
  read -r marker code value_type current maximum extra <<<"$output"
  [[ $marker == VCP && $code == 10 && $value_type == C && -z ${extra:-} ]] || return 1
  [[ $current =~ ^[0-9]+$ && $maximum =~ ^[0-9]+$ ]] || return 1
  ((maximum > 0 && current <= maximum)) || return 1
  printf '%s %s\n' "$current" "$maximum"
}

join_names() {
  local separator=""
  local name

  for name in "$@"; do
    printf '%s%s' "$separator" "$name"
    separator=", "
  done
}

apply_ddc_brightness() {
  local step=$1
  shift

  local configured=${DESKTOP_OSD_DDC_MONITORS:-}
  local connected_output label edid primary connector connected_edid readback
  local primary_index=-1
  local -a connected_records=()
  local -a labels=()
  local -a edids=()
  local -a old_raw=()
  local -a maxima=()
  local -a target_raw=()
  local -a attempted=()
  local -a changed=()
  local -a restored=()
  local -a unresolved=()

  [[ -n $configured ]] || {
    control_error "Display brightness is unavailable: no DDC/CI monitors are configured"
    return
  }

  connected_output=$(connected_edids) || {
    control_error "Display brightness is unavailable: connected monitor identities could not be read"
    return
  }
  mapfile -t connected_records <<<"$connected_output"

  while IFS='|' read -r label edid primary; do
    [[ -n $label && $edid =~ ^[[:xdigit:]]{256}$ && $primary =~ ^[01]$ ]] || {
      control_error "Display brightness has an invalid DDC/CI monitor configuration"
      return
    }
    edid=${edid,,}
    connector=""
    for connected_edid in "${connected_records[@]}"; do
      if [[ ${connected_edid#*|} == "$edid" ]]; then
        connector=${connected_edid%%|*}
        break
      fi
    done
    if [[ -z $connector ]]; then
      if [[ $primary == 1 ]]; then
        control_error "Display brightness is unavailable: primary monitor '$label' is disconnected"
        return
      fi
      continue
    fi

    labels+=("$label")
    edids+=("$edid")
    if [[ $primary == 1 ]]; then
      ((primary_index == -1)) || {
        control_error "Display brightness has more than one connected primary monitor"
        return
      }
      primary_index=$((${#labels[@]} - 1))
    fi
  done <<<"$configured"

  ((primary_index >= 0)) || {
    control_error "Display brightness is unavailable: its primary monitor is disconnected"
    return
  }

  local i current maximum
  for i in "${!labels[@]}"; do
    readback=$(ddc_read_brightness "${edids[i]}") || {
      control_error "Display brightness preflight failed for '${labels[i]}'; no monitors were changed"
      return
    }
    read -r current maximum <<<"$readback"
    old_raw[i]=$current
    maxima[i]=$maximum
  done

  local primary_percentage target_percentage represented_percentage
  local verified_target_percentage=-1
  primary_percentage=$(percentage_from_raw "${old_raw[primary_index]}" "${maxima[primary_index]}")
  target_percentage=$(apply_direction_actions "$primary_percentage" "$step" "$@") || {
    control_error "Display brightness received an invalid queued action"
    return
  }
  for i in "${!labels[@]}"; do
    target_raw[i]=$(raw_from_percentage "$target_percentage" "${maxima[i]}")
    represented_percentage=$(percentage_from_raw "${target_raw[i]}" "${maxima[i]}")
    if ((verified_target_percentage == -1)); then
      verified_target_percentage=$represented_percentage
    elif ((represented_percentage != verified_target_percentage)); then
      control_error "Display brightness cannot represent one shared percentage on every connected monitor; no monitors were changed"
      return
    fi
  done

  local failed_index=-1 failure_kind=""
  for i in "${!labels[@]}"; do
    if ((target_raw[i] == old_raw[i])); then
      continue
    fi
    attempted+=("$i")
    if ! ddcutil --edid "${edids[i]}" setvcp 10 "${target_raw[i]}" >/dev/null 2>&1; then
      failed_index=$i
      failure_kind="write"
      break
    fi
    readback=$(ddc_read_brightness "${edids[i]}") || {
      failed_index=$i
      failure_kind="readback"
      break
    }
    read -r current maximum <<<"$readback"
    if ((current != target_raw[i] || maximum != maxima[i])); then
      failed_index=$i
      failure_kind="verification"
      break
    fi
    changed+=("${labels[i]}")
  done

  if ((failed_index >= 0)); then
    for i in "${attempted[@]}"; do
      if ddcutil --edid "${edids[i]}" setvcp 10 "${old_raw[i]}" >/dev/null 2>&1 \
        && readback=$(ddc_read_brightness "${edids[i]}"); then
        read -r current maximum <<<"$readback"
        if ((current == old_raw[i] && maximum == maxima[i])); then
          restored+=("${labels[i]}")
          continue
        fi
      fi
      unresolved+=("${labels[i]}")
    done

    local changed_text restored_text unresolved_text
    changed_text=$(join_names "${changed[@]}")
    restored_text=$(join_names "${restored[@]}")
    unresolved_text=$(join_names "${unresolved[@]}")
    [[ -n $changed_text ]] || changed_text="none verified"
    [[ -n $restored_text ]] || restored_text="none"
    [[ -n $unresolved_text ]] || unresolved_text="none"
    control_error "Display brightness $failure_kind failed at '${labels[failed_index]}'. Changed: $changed_text. Restored: $restored_text. Unresolved: $unresolved_text."
    return
  fi

  send_osd 9991 display-brightness-symbolic "$verified_target_percentage" "Display brightness" "$verified_target_percentage%" || {
    control_error "Displays changed to $verified_target_percentage%, but their OSD could not be displayed"
    return
  }
}

read_audio_snapshot() {
  local kind=$1
  local target=$2
  local volume_output mute_output

  volume_output=$(pactl "get-$kind-volume" "$target") || return 1
  mute_output=$(pactl "get-$kind-mute" "$target") || return 1
  mapfile -t AUDIO_RAW < <(
    awk '{
      for (i = 1; i <= NF; i++) {
        if ($i == "/" && $(i - 1) ~ /^[0-9]+$/) print $(i - 1)
      }
    }' <<<"$volume_output"
  )
  ((${#AUDIO_RAW[@]} > 0)) || return 1
  case "$mute_output" in
    "Mute: yes") AUDIO_MUTE=yes ;;
    "Mute: no") AUDIO_MUTE=no ;;
    *) return 1 ;;
  esac
}

audio_percentage() {
  local maximum=0
  local raw

  for raw in "$@"; do
    ((raw > maximum)) && maximum=$raw
  done
  percentage_from_raw "$maximum" "$VOLUME_NORMAL"
}

restore_audio() {
  local kind=$1
  local target=$2
  local old_mute=$3
  shift 3
  local -a old_raw=("$@")

  pactl "set-$kind-volume" "$target" "${old_raw[@]}" >/dev/null \
    && pactl "set-$kind-mute" "$target" "$old_mute" >/dev/null \
    && read_audio_snapshot "$kind" "$target" \
    && [[ ${AUDIO_RAW[*]} == "${old_raw[*]}" && $AUDIO_MUTE == "$old_mute" ]]
}

apply_volume() {
  local step=$1
  shift

  local sink
  sink=$(pactl get-default-sink) || {
    control_error "Volume is unavailable: the default sink could not be resolved"
    return
  }
  [[ -n $sink ]] || {
    control_error "Volume is unavailable: no default sink is configured"
    return
  }

  declare -ga AUDIO_RAW=()
  declare -g AUDIO_MUTE=""
  read_audio_snapshot sink "$sink" || {
    control_error "Volume state for default sink '$sink' could not be read"
    return
  }
  local -a old_raw=("${AUDIO_RAW[@]}")
  local -a target_raw=("${AUDIO_RAW[@]}")
  local old_mute=$AUDIO_MUTE
  local target_mute=$AUDIO_MUTE
  local delta=$(((step * VOLUME_NORMAL + 50) / 100))
  local action i

  for i in "${!target_raw[@]}"; do
    ((target_raw[i] > VOLUME_NORMAL)) && target_raw[i]=$VOLUME_NORMAL
  done

  for action in "$@"; do
    case "$action" in
      up)
        for i in "${!target_raw[@]}"; do
          target_raw[i]=$((target_raw[i] + delta))
          ((target_raw[i] > VOLUME_NORMAL)) && target_raw[i]=$VOLUME_NORMAL
        done
        target_mute=no
        ;;
      down)
        for i in "${!target_raw[@]}"; do
          target_raw[i]=$((target_raw[i] - delta))
          ((target_raw[i] < 0)) && target_raw[i]=0
        done
        ;;
      toggle)
        [[ $target_mute == yes ]] && target_mute=no || target_mute=yes
        ;;
      *)
        control_error "Volume received an invalid queued action"
        return
        ;;
    esac
  done

  if ! pactl set-sink-volume "$sink" "${target_raw[@]}" >/dev/null \
    || ! pactl set-sink-mute "$sink" "$target_mute" >/dev/null \
    || ! read_audio_snapshot sink "$sink" \
    || [[ ${AUDIO_RAW[*]} != "${target_raw[*]}" || $AUDIO_MUTE != "$target_mute" ]]; then
    if restore_audio sink "$sink" "$old_mute" "${old_raw[@]}"; then
      control_error "Volume update failed; previous sink state was restored"
    else
      control_error "Volume update failed and rollback for default sink '$sink' is unresolved"
    fi
    return
  fi

  local percentage icon body
  percentage=$(audio_percentage "${AUDIO_RAW[@]}")
  if [[ $AUDIO_MUTE == yes ]]; then
    icon=audio-volume-muted-symbolic
    body=Muted
    percentage=0
  elif ((percentage < 34)); then
    icon=audio-volume-low-symbolic
    body="$percentage%"
  elif ((percentage < 67)); then
    icon=audio-volume-medium-symbolic
    body="$percentage%"
  else
    icon=audio-volume-high-symbolic
    body="$percentage%"
  fi

  send_osd 9992 "$icon" "$percentage" Volume "$body" || {
    control_error "Volume changed, but its OSD could not be displayed"
    return
  }
}

apply_microphone() {
  local source
  source=$(pactl get-default-source) || {
    control_error "Microphone is unavailable: the default source could not be resolved"
    return
  }
  [[ -n $source ]] || {
    control_error "Microphone is unavailable: no default source is configured"
    return
  }

  declare -ga AUDIO_RAW=()
  declare -g AUDIO_MUTE=""
  read_audio_snapshot source "$source" || {
    control_error "Microphone state for default source '$source' could not be read"
    return
  }
  local -a old_raw=("${AUDIO_RAW[@]}")
  local old_mute=$AUDIO_MUTE
  local target_mute=$AUDIO_MUTE
  local action

  for action in "$@"; do
    case "$action" in
      mute) target_mute=yes ;;
      toggle) [[ $target_mute == yes ]] && target_mute=no || target_mute=yes ;;
      *)
        control_error "Microphone received an invalid queued action"
        return
        ;;
    esac
  done

  if ! pactl set-source-mute "$source" "$target_mute" >/dev/null \
    || ! read_audio_snapshot source "$source" \
    || [[ ${AUDIO_RAW[*]} != "${old_raw[*]}" || $AUDIO_MUTE != "$target_mute" ]]; then
    if restore_audio source "$source" "$old_mute" "${old_raw[@]}"; then
      control_error "Microphone update failed; previous source state was restored"
    else
      control_error "Microphone update failed and rollback for default source '$source' is unresolved"
    fi
    return
  fi

  local percentage icon body
  percentage=$(audio_percentage "${AUDIO_RAW[@]}")
  if [[ $AUDIO_MUTE == yes ]]; then
    icon=microphone-sensitivity-muted-symbolic
    body=Muted
    percentage=0
  else
    icon=microphone-sensitivity-high-symbolic
    body="Active · $percentage%"
  fi

  send_osd 9993 "$icon" "$percentage" Microphone "$body" || {
    control_error "Microphone state changed, but its OSD could not be displayed"
    return
  }
}

process_actions() {
  local family=$1
  shift

  case "$family" in
    brightness)
      case "${DESKTOP_OSD_BRIGHTNESS_BACKEND:-disabled}" in
        disabled)
          control_error "Display brightness is unavailable on this host because no verified all-display backend is configured"
          ;;
        single-backlight)
          local device
          device=$(single_backlight_device) || {
            control_error "Display brightness requires exactly one kernel backlight device"
            return
          }
          apply_brightnessctl brightness "Display brightness" "$device" "${DESKTOP_OSD_DISPLAY_STEP:-5}" "$@"
          ;;
        ddc)
          apply_ddc_brightness "${DESKTOP_OSD_DISPLAY_STEP:-5}" "$@"
          ;;
        *)
          control_error "Display brightness has an invalid backend configuration"
          ;;
      esac
      ;;
    keyboard-brightness)
      apply_brightnessctl keyboard-brightness "Keyboard brightness" smc::kbd_backlight "${DESKTOP_OSD_KEYBOARD_STEP:-25}" "$@"
      ;;
    volume)
      apply_volume "${DESKTOP_OSD_VOLUME_STEP:-5}" "$@"
      ;;
    microphone)
      apply_microphone "$@"
      ;;
  esac
}

validate_request() {
  [[ $# == 2 ]] || return 1

  case "$1:$2" in
    brightness:up | brightness:down) ;;
    keyboard-brightness:up | keyboard-brightness:down) ;;
    volume:up | volume:down | volume:toggle) ;;
    microphone:toggle | microphone:mute) ;;
    *) return 1 ;;
  esac
}

run_coalesced() {
  local family=$1
  local action=$2
  local runtime_base=${DESKTOP_OSD_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-}/desktop-osd}
  local queue_file sequence_file state_lock worker_lock result_file
  local sequence=0 ticket status line batch_status
  local -a actions=()
  local -a tickets=()
  local -a pending=()

  [[ -n ${XDG_RUNTIME_DIR:-} || -n ${DESKTOP_OSD_RUNTIME_DIR:-} ]] || {
    control_error "Desktop OSD requires XDG_RUNTIME_DIR"
    return
  }
  if ! mkdir -p "$runtime_base" || ! chmod 0700 "$runtime_base"; then
    control_error "Desktop OSD runtime state could not be created"
    return
  fi
  queue_file="$runtime_base/$family.queue"
  sequence_file="$runtime_base/$family.sequence"
  state_lock="$runtime_base/$family.state.lock"
  worker_lock="$runtime_base/$family.worker.lock"

  exec 8>"$state_lock"
  exec 9>"$worker_lock"
  flock 8
  if [[ -f $sequence_file ]]; then
    sequence=$(<"$sequence_file")
    [[ $sequence =~ ^[0-9]+$ ]] || sequence=0
  fi
  ticket=$((sequence + 1))
  printf '%d\n' "$ticket" >"$sequence_file"
  result_file="$runtime_base/$family.result.$ticket"
  printf '%d|%s\n' "$ticket" "$action" >>"$queue_file"
  if ! flock -n 9; then
    flock -u 8
    flock 9
    flock 8
    if [[ -f $result_file ]]; then
      status=$(<"$result_file")
      rm -f "$result_file"
      flock -u 8
      flock -u 9
      return "$status"
    fi
    flock -u 8
  else
    flock -u 8
  fi

  while true; do
    flock 8
    if [[ ! -s $queue_file ]]; then
      if [[ -f $result_file ]]; then
        status=$(<"$result_file")
        rm -f "$result_file"
      else
        status=1
      fi
      # Releasing the worker while the state lock is held prevents a lost enqueue.
      flock -u 9
      flock -u 8
      return "$status"
    fi
    mapfile -t pending <"$queue_file"
    : >"$queue_file"
    flock -u 8

    actions=()
    tickets=()
    for line in "${pending[@]}"; do
      tickets+=("${line%%|*}")
      actions+=("${line#*|}")
    done

    batch_status=0
    process_actions "$family" "${actions[@]}" || batch_status=$?

    flock 8
    for ticket in "${tickets[@]}"; do
      printf '%d\n' "$batch_status" >"$runtime_base/$family.result.$ticket"
    done
    if ((batch_status != 0)); then
      if [[ -s $queue_file ]]; then
        mapfile -t pending <"$queue_file"
        for line in "${pending[@]}"; do
          ticket=${line%%|*}
          printf '1\n' >"$runtime_base/$family.result.$ticket"
        done
      fi
      : >"$queue_file"
      if [[ -f $result_file ]]; then
        status=$(<"$result_file")
        rm -f "$result_file"
      else
        status=1
      fi
      flock -u 9
      flock -u 8
      return "$status"
    fi
    flock -u 8
  done
}

main() {
  if ! validate_request "$@"; then
    usage
    return 2
  fi

  run_coalesced "$1" "$2"
}

main "$@"
