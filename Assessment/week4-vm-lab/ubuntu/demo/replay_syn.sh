#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

IFACE="${1:-}"
SRC_IP="${2:-}"
DST_IP="${3:-}"
SRC_MAC="${4:-}"
DST_MAC="${5:-}"
PCAP="${6:-$HOME/week4-lab/pcaps/SYN.pcap}"

if [[ -z "$IFACE" || -z "$SRC_IP" || -z "$DST_IP" || -z "$SRC_MAC" || -z "$DST_MAC" ]]; then
  echo "Usage: $0 <interface> <private-src-ip> <private-dst-ip> <src-mac> <dst-mac> [pcap]"
  exit 1
fi

require_private_ip "$SRC_IP"
require_private_ip "$DST_IP"
require_file "$PCAP"

echo "[*] Replaying SYN traffic from $PCAP"
sudo tcpreplay-edit \
  --srcipmap=10.0.0.2:"$SRC_IP" \
  --dstipmap=10.128.0.2:"$DST_IP" \
  --enet-smac="$SRC_MAC" \
  --enet-dmac="$DST_MAC" \
  --loop=10 \
  -i "$IFACE" \
  "$PCAP"
