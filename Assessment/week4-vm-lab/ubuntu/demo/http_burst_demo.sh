#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TARGET_IP="${1:-}"
PORT="${2:-8080}"
REQUESTS="${3:-300}"
PARALLELISM="${4:-30}"

if [[ -z "$TARGET_IP" ]]; then
  echo "Usage: $0 <private-target-ip> [port] [requests] [parallelism]"
  exit 1
fi

require_private_ip "$TARGET_IP"

echo "[*] Sending repeated HTTP requests to http://$TARGET_IP:$PORT/status"
seq "$REQUESTS" | xargs -P "$PARALLELISM" -I{} curl -fsS "http://$TARGET_IP:$PORT/status" -o /dev/null
echo "[*] HTTP burst complete"
