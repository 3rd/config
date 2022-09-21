#!/run/current-system/sw/bin/bash

export PATH="/run/current-system/sw/bin/:$PATH"

TASK=$(/home/rabbit/go/bin/core task current)
if [ "$TASK" != "" ]; then
  printf " %s " "$TASK"
fi
echo ""
