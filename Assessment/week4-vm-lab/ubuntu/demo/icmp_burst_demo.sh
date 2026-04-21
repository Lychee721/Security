#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TARGET_IP="${1:-}"
COUNT="${2:-5000}"

if [[ -z "$TARGET_IP" ]]; then
  echo "Usage: $0 <private-target-ip> [count]"
  exit 1
fi

require_private_ip "$TARGET_IP"

echo "[*] Sending bounded ICMP burst to $TARGET_IP"
echo "[*] This is intentionally limited for the lab"
sudo hping3 --icmp -i u1000 -c "$COUNT" "$TARGET_IP"
