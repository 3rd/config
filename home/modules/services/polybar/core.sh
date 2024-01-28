#!/run/current-system/sw/bin/bash

export PATH="/run/current-system/sw/bin/:$PATH"

# ACTION="$1"
# if [[ $ACTION = "right" ]]; then
#   exit
# fi

RESPONSE=$(curl -s http://localhost:9000/polybar/status || echo "%{F#d13048}")
echo "$RESPONSE"
