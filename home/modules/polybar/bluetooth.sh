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

connected_adapters=$(bluetoothctl list | awk '{print $2}' | while read -r mac; do
  echo -e "select $mac\ndevices" | bluetoothctl | awk '/Device/ {print $2}' | while read -r device; do
    echo -e "select $mac\ninfo $device" | bluetoothctl | grep -q "Connected: yes" && echo "$mac"
  done
done)

if [ "$(bluetoothctl show | grep "Powered: yes" | tr -d '[:space:]' | wc -c)" -eq 0 ]; then
  echo "%{F#66ffffff}"
else
  # no device connected
  if [ "$(echo "$connected_adapters" | tr -d '[:space:]' | wc -c)" -eq 0 ]; then
    echo ""
  else
    # at least one device connected
    echo "%{F#2193ff}"
  fi
fi
