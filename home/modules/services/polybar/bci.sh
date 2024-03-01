#!/run/current-system/sw/bin/bash

export PATH="/run/current-system/sw/bin/:$PATH"

# ACTION="$1"
# if [[ $ACTION = "right" ]]; then
#   exit
# fi

STATUS_PATH="/tmp/core-bci-polybar"

if [ -f "$STATUS_PATH" ]; then
  if [ $(($(date +%s) - $(date -r "$STATUS_PATH" +%s))) -le 5 ]; then
    cat "$STATUS_PATH"
    exit 0
  fi
fi

echo "BCI OFF"
