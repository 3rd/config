#!/run/current-system/sw/bin/bash
export PATH="/run/current-system/sw/bin/:$PATH"

TASK=$(/home/rabbit/go/bin/core task current -e)
RESULT="  EVERY SECOND COUNTS"
if [ "$TASK" != "" ]; then
  RESULT="%{F#f97e48}  $TASK"
fi
echo "$RESULT"
