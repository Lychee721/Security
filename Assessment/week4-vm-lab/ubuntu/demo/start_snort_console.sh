#!/usr/bin/env bash
set -euo pipefail

IFACE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_SCRIPT="$SCRIPT_DIR/../snort/apply_local_rules.sh"

if [[ -z "$IFACE" ]]; then
  echo "Usage: $0 <interface>"
  exit 1
fi

TARGET_IP="$(ip -o -4 addr show "$IFACE" | awk '{print $4}' | cut -d/ -f1)"
HOME_NET=""
if [[ -n "${TARGET_IP:-}" ]]; then
  HOME_NET="$(echo "$TARGET_IP" | awk -F. '{print $1 "." $2 "." $3 ".0/24"}')"
fi

echo "[*] Syncing local.rules"
bash "$RULES_SCRIPT" "$IFACE"

if [[ -n "$HOME_NET" ]]; then
  echo "[*] Setting HOME_NET to $HOME_NET"
  sudo sed -i "s#^ipvar HOME_NET .*#ipvar HOME_NET $HOME_NET#" /etc/snort/snort.conf
fi

echo "[*] Starting Snort on $IFACE"
echo "[*] Stop with Ctrl+C"
sudo snort -k none -A console -i "$IFACE" -c /etc/snort/snort.conf
