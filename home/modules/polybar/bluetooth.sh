#!/run/current-system/sw/bin/bash

export PATH="/run/current-system/sw/bin/:$PATH"

ACTION="$1"

if [[ $ACTION = "right" ]]; then
  if [ "$(bluetoothctl show | grep "Powered: yes" | wc -c)" -eq 0 ]; then
    bluetoothctl power on
  else
    bluetoothctl power off
  fi
fi

if [ "$(bluetoothctl show | grep "Powered: yes" | wc -c)" -eq 0 ]; then
  echo "%{F#66ffffff}"
else
  if [ "$(echo info | bluetoothctl | grep 'Device' | wc -c)" -eq 0 ]; then
    echo ""
  fi
  echo "%{F#2193ff}"
fi
