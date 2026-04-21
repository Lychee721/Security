#!/usr/bin/env bash
set -euo pipefail

IFACE="${1:-}"

if [[ -z "$IFACE" ]]; then
  echo "Usage: $0 <interface>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="$SCRIPT_DIR/local.rules"

echo "[*] Backing up existing local.rules"
sudo cp /etc/snort/rules/local.rules "/etc/snort/rules/local.rules.bak.$(date +%Y%m%d_%H%M%S)" || true

echo "[*] Installing custom rules"
sudo cp "$RULES_FILE" /etc/snort/rules/local.rules

cat <<EOF

[*] Custom rules copied to /etc/snort/rules/local.rules

Before running Snort, make sure HOME_NET in /etc/snort/snort.conf matches your private lab range.
For example:
  ipvar HOME_NET 192.168.56.0/24

Recommended validation command:
  sudo snort -T -i $IFACE -c /etc/snort/snort.conf

EOF
