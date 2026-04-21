#!/usr/bin/env bash
set -euo pipefail

echo "[*] Updating package index"
sudo apt update

echo "[*] Installing Week 4 lab packages"
sudo apt install -y snort tcpreplay tcpdump iputils-ping hping3 curl python3 net-tools

echo "[*] Creating working folders"
mkdir -p "$HOME/week4-lab/pcaps"
mkdir -p "$HOME/week4-lab/logs"
mkdir -p "$HOME/week4-lab/screenshots"

cat <<'EOF'

[*] Setup finished.

Next steps:
1. Copy the Week 4 PCAP files into ~/week4-lab/pcaps/
2. Find your network interface with: ip addr
3. Apply the custom Snort rules:
   bash ubuntu/snort/apply_local_rules.sh <interface>
4. Start Snort:
   bash ubuntu/demo/start_snort_console.sh <interface>

EOF
