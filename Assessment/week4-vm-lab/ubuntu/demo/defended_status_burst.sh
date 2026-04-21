#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TARGET_IP="${1:-}"
PORT="${2:-8080}"
REQUESTS="${3:-120}"
PARALLELISM="${4:-20}"

if [[ -z "$TARGET_IP" ]]; then
  echo "Usage: $0 <target-ip> [port] [requests] [parallelism]"
  exit 1
fi

require_private_ip "$TARGET_IP"

TMP_CODES="$(mktemp)"
trap 'rm -f "$TMP_CODES"' EXIT

echo "[*] Sending $REQUESTS status requests to http://$TARGET_IP:$PORT/status with parallelism $PARALLELISM"
seq "$REQUESTS" | xargs -P "$PARALLELISM" -I{} sh -c \
  "curl -s -o /dev/null -w '%{http_code}\n' 'http://$TARGET_IP:$PORT/status'" > "$TMP_CODES"

echo "[*] HTTP status code summary"
sort "$TMP_CODES" | uniq -c
