#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="$ROOT_DIR"
source "$LAB_DIR/ubuntu/demo/common.sh"
HOME_DIR="${HOME:-/home/elec0138}"
WORK_DIR="$HOME_DIR/week4-lab"
LOG_DIR="$WORK_DIR/logs"
EVID_DIR="$WORK_DIR/evidence"
HOST_EVID_DIR="$LAB_DIR/evidence"

mkdir -p "$LOG_DIR" "$EVID_DIR" "$HOST_EVID_DIR"

echo "[*] Refreshing sudo credentials"
sudo -v

echo "[*] Installing required packages"
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y snort hping3 curl python3 net-tools

echo "[*] Detecting a private interface and IP"
TARGET_IFACE="$(detect_lab_interface)"

if [[ -z "${TARGET_IFACE:-}" ]]; then
  echo "[!] Could not find a usable private interface" | tee "$EVID_DIR/demo_summary.txt"
  ip -br addr | tee "$EVID_DIR/ip_addr.txt"
  exit 1
fi

TARGET_IP="$(ip -o -4 addr show "$TARGET_IFACE" | awk '{print $4}' | cut -d/ -f1)"
HOME_NET="$(home_net_for_ip "$TARGET_IP")"

echo "[*] Interface: $TARGET_IFACE"
echo "[*] Target IP: $TARGET_IP"
echo "[*] HOME_NET: $HOME_NET"

ip -br addr | tee "$EVID_DIR/ip_addr.txt"
ip -br link | tee "$EVID_DIR/ip_link.txt"

echo "[*] Installing coursework Snort rules"
bash "$LAB_DIR/ubuntu/snort/apply_local_rules.sh" "$TARGET_IFACE" | tee "$EVID_DIR/apply_local_rules.txt"
sudo sed -i "s#^ipvar HOME_NET .*#ipvar HOME_NET $HOME_NET#" /etc/snort/snort.conf
sudo grep '^ipvar HOME_NET' /etc/snort/snort.conf | tee "$EVID_DIR/home_net.txt"

echo "[*] Validating Snort"
sudo snort -k none -T -i "$TARGET_IFACE" -c /etc/snort/snort.conf |& tee "$EVID_DIR/snort_test.txt"

echo "[*] Cleaning up older demo processes"
sudo pkill snort 2>/dev/null || true
pkill -f mock_thermostat.py 2>/dev/null || true

echo "[*] Starting Snort in the background"
sudo sh -c "snort -k none -A console -i '$TARGET_IFACE' -c /etc/snort/snort.conf > '$LOG_DIR/snort_console.log' 2>&1 & echo \$! > '$LOG_DIR/snort.pid'"
sleep 5

echo "[*] Starting mock thermostat service"
nohup python3 "$LAB_DIR/ubuntu/demo/mock_thermostat.py" > "$LOG_DIR/thermostat.log" 2>&1 &
echo $! > "$LOG_DIR/thermostat.pid"
sleep 2

echo "[*] Sanity check request"
curl -fsS "http://$TARGET_IP:8080/status" | tee "$EVID_DIR/thermostat_status.json"

echo "[*] Running HTTP burst demo"
bash "$LAB_DIR/ubuntu/demo/http_burst_demo.sh" "$TARGET_IP" 8080 500 50 | tee "$LOG_DIR/http_burst.log"
sleep 3

echo "[*] Checking for Snort HTTP alert"
grep -n "ELEC0138 repeated requests to thermostat service" "$LOG_DIR/snort_console.log" > "$EVID_DIR/http_alert_hits.txt" || true

HTTP_HITS="$(count_lines_if_nonempty "$EVID_DIR/http_alert_hits.txt")"

ICMP_HITS=0
if [[ "$HTTP_HITS" -eq 0 ]]; then
  echo "[*] HTTP alert not found, falling back to ICMP burst"
  bash "$LAB_DIR/ubuntu/demo/icmp_burst_demo.sh" "$TARGET_IP" 3000 | tee "$LOG_DIR/icmp_burst.log" || true
  sleep 3
  grep -n "ELEC0138 ICMP burst to private host" "$LOG_DIR/snort_console.log" > "$EVID_DIR/icmp_alert_hits.txt" || true
  ICMP_HITS="$(count_lines_if_nonempty "$EVID_DIR/icmp_alert_hits.txt")"
else
  : > "$EVID_DIR/icmp_alert_hits.txt"
fi

echo "[*] Making logs readable"
sudo chmod -R a+r "$WORK_DIR"

cat > "$EVID_DIR/demo_summary.txt" <<EOF
interface=$TARGET_IFACE
target_ip=$TARGET_IP
home_net=$HOME_NET
http_alert_hits=$HTTP_HITS
icmp_alert_hits=$ICMP_HITS
logs_dir=$LOG_DIR
evidence_dir=$EVID_DIR
EOF

copy_artifacts_to_host "$HOST_EVID_DIR" \
  "$EVID_DIR/demo_summary.txt" \
  "$EVID_DIR/ip_addr.txt" \
  "$EVID_DIR/snort_test.txt" \
  "$EVID_DIR/http_alert_hits.txt" \
  "$EVID_DIR/icmp_alert_hits.txt" \
  "$LOG_DIR/snort_console.log" \
  "$LOG_DIR/thermostat.log"

echo
echo "[*] Demo completed"
cat "$EVID_DIR/demo_summary.txt"
echo
echo "[*] Next command to display a compact screenshot view:"
echo "bash show-demo-results.sh"
