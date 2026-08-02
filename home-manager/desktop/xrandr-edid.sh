#!/usr/bin/env bash

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
