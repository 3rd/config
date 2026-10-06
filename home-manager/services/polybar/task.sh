#!/run/current-system/sw/bin/bash
export PATH="/run/current-system/sw/bin/:$PATH"

task_output=""
task_status=125
timeout_messages=""
if timeout_log=$(mktemp 2>/dev/null); then
  trap 'rm -f -- "$timeout_log"' EXIT
  task_output=$(
    {
      LC_ALL=C timeout --verbose --kill-after=2 5 sh -c 'exec "$@" 2>/dev/null' core-task /home/rabbit/go/bin/core task current -e
    } 2>"$timeout_log"
  )
  task_status=$?
  timeout_messages=$(<"$timeout_log")
fi

error_style=""
if [ -n "${TASK_ERROR_COLOR:-}" ]; then
  error_style="%{F$TASK_ERROR_COLOR}"
fi

if [ "$task_status" -eq 0 ]; then
  if [ -n "$task_output" ]; then
    result="%{F#f97e48}  $task_output"
  else
    result="No running task"
  fi
elif [[ "$timeout_messages" == *"timeout: sending signal "* ]]; then
  result="${error_style}  Task status timed out%{F-}"
else
  result="${error_style}  Task status unavailable%{F-}"
fi

printf '%s\n' "$result"
