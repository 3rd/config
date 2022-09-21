#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  sudo cpupower -c all frequency-set -g performance
fi
