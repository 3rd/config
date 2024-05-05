#!/run/current-system/sw/bin/bash
set -uf -o pipefail
IFS=$'\n\t'

export PATH="/run/current-system/sw/bin/:$PATH"

INFO="$( ( (pgrep -a openforti | head -n 1 | awk '{print $1 }') || (pgrep -a openvpn | head -n 1 | awk '{print $1 }') || (pgrep -a charon | head -n 1 | awk '{print $1 }')) | head -n 1)"
if [ "$INFO" != "" ]; then
  printf "VPN: %s" "$INFO"
  exit 0
fi

INFO=$(mullvad status 2>/dev/null)
if [[ $INFO == *"Connected"* ]]; then
  LOCATION=$(echo "$INFO" | grep -oP "Your connection appears to be from: \K.*")
  printf "Mullvad: %s" "$LOCATION"
  exit 0
fi

echo ""
