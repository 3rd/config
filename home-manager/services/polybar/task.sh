#!/run/current-system/sw/bin/bash
export PATH="/run/current-system/sw/bin/:$PATH"

# TASK=$(/home/rabbit/go/bin/core task current -e)
# if [ "$TASK" != "" ]; then
#   printf " %s " "$TASK"
# fi
# echo ""

# ACTION="$1"
# if [[ $ACTION = "right" ]]; then
#   exit
# fi

RESPONSE=$(curl -s http://localhost:9000/polybar/task || echo "%{F#d13048}")
echo "$RESPONSE"
