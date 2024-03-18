#!/run/current-system/sw/bin/bash
set -uf -o pipefail
IFS=$'\n\t'

export PATH="/run/current-system/sw/bin/:$PATH"

INFO="$( ( (pgrep -a openforti | head -n 1 | awk '{print $1 }') || (pgrep -a openvpn | head -n 1 | awk '{print $1 }') || (pgrep -a charon | head -n 1 | awk '{print $1 }')) | head -n 1)"

if [ "$INFO" != "" ]; then
  printf "VPN: %s" "$INFO"
fi
echo ""
