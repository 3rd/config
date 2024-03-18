#!/run/current-system/sw/bin/bash

export PATH="/run/current-system/sw/bin/:$PATH"

ACTION="$1"

if [[ $ACTION = "right" ]]; then
  if [ "$(bluetoothctl show | grep "Powered: yes" | wc -c)" -eq 0 ]; then
    bluetoothctl power on
  else
    bluetoothctl power off
  fi
  exit
fi

if [ "$(hciconfig | grep "UP RUNNING" | wc -c)" -eq 0 ]; then
  echo "%{F#66ffffff}"
else
  if [ "$(hcitool con | wc -l)" -eq 1 ]; then
    echo ""
  else
    echo "%{F#2193ff}"
  fi
fi
