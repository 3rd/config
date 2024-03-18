#!/usr/bin/env bash
set -uf -o pipefail
IFS=$'\n\t'

ln -s "$(dirname "$(readlink -f "$0")")/linx-client.conf" ~/.config/linx-client.conf
ln -s "$(dirname "$(readlink -f "$0")")/linxlog" ~/.linxlog
