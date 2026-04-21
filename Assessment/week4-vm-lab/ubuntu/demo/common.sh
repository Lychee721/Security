#!/usr/bin/env bash
set -euo pipefail

is_private_ip() {
  local ip="$1"
  [[ "$ip" =~ ^10\. ]] || \
  [[ "$ip" =~ ^192\.168\. ]] || \
  [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || \
  [[ "$ip" =~ ^169\.254\. ]]
}

require_private_ip() {
  local ip="$1"
  if ! is_private_ip "$ip"; then
    echo "[!] Refusing to use non-private or non-lab-local IP: $ip"
    exit 1
  fi
}

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "[!] Missing file: $file"
    exit 1
  fi
}
