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
API_KEY="${THERMOSTAT_API_KEY:-elec0138-demo-key}"

mkdir -p "$LOG_DIR" "$EVID_DIR" "$HOST_EVID_DIR"

echo "[*] Refreshing sudo credentials"
sudo -v

ensure_runtime_packages snort curl python3

echo "[*] Detecting a lab interface and IP"
TARGET_IFACE="$(detect_lab_interface 1)"

if [[ -z "${TARGET_IFACE:-}" ]]; then
  echo "[!] Could not find a usable lab interface" | tee "$EVID_DIR/defense_demo_summary.txt"
  ip -br addr | tee "$EVID_DIR/ip_addr.txt"
  exit 1
fi

TARGET_IP="$(ip -o -4 addr show "$TARGET_IFACE" | awk '{print $4}' | cut -d/ -f1)"
HOME_NET="$(home_net_for_ip "$TARGET_IP" "link_local_16")"

echo "[*] Interface: $TARGET_IFACE"
echo "[*] Target IP: $TARGET_IP"
echo "[*] HOME_NET: $HOME_NET"

ip -br addr | tee "$EVID_DIR/defense_ip_addr.txt"
ip -br link | tee "$EVID_DIR/defense_ip_link.txt"

echo "[*] Installing coursework Snort rules"
bash "$LAB_DIR/ubuntu/snort/apply_local_rules.sh" "$TARGET_IFACE" | tee "$EVID_DIR/defense_apply_local_rules.txt"
sudo sed -i "s#^ipvar HOME_NET .*#ipvar HOME_NET $HOME_NET#" /etc/snort/snort.conf
sudo grep '^ipvar HOME_NET' /etc/snort/snort.conf | tee "$EVID_DIR/defense_home_net.txt"

echo "[*] Validating Snort"
sudo snort -k none -T -i "$TARGET_IFACE" -c /etc/snort/snort.conf |& tee "$EVID_DIR/defense_snort_test.txt"

echo "[*] Cleaning up older demo processes"
sudo pkill snort 2>/dev/null || true
pkill -f defended_thermostat.py 2>/dev/null || true
pkill -f mock_thermostat.py 2>/dev/null || true

echo "[*] Starting Snort in the background"
sudo sh -c "snort -k none -A console -i '$TARGET_IFACE' -c /etc/snort/snort.conf > '$LOG_DIR/defense_snort_console.log' 2>&1 & echo \$! > '$LOG_DIR/defense_snort.pid'"
sleep 5

echo "[*] Starting defended thermostat service"
export THERMOSTAT_API_KEY="$API_KEY"
nohup bash "$LAB_DIR/ubuntu/demo/start_defended_thermostat.sh" 8080 "$API_KEY" > "$LOG_DIR/defended_thermostat.log" 2>&1 &
echo $! > "$LOG_DIR/defended_thermostat.pid"
sleep 2

echo "[*] Sanity check status endpoint"
curl -fsS "http://$TARGET_IP:8080/status" | tee "$EVID_DIR/defense_status.json"

echo "[*] Unauthorized state change probe"
curl -sS -o "$EVID_DIR/unauthorized_set_temp_body.json" -w "%{http_code}\n" \
  "http://$TARGET_IP:8080/set_temp?value=27" | tee "$EVID_DIR/unauthorized_set_temp_status.txt"

echo "[*] Authorized state change"
curl -sS -H "X-API-Key: $API_KEY" -o "$EVID_DIR/authorized_set_temp_body.json" -w "%{http_code}\n" \
  "http://$TARGET_IP:8080/set_temp?value=23" | tee "$EVID_DIR/authorized_set_temp_status.txt"

echo "[*] Running bounded burst against /status to exercise rate limiting and IDS visibility"
bash "$LAB_DIR/ubuntu/demo/defended_status_burst.sh" "$TARGET_IP" 8080 120 20 | tee "$EVID_DIR/defended_status_burst_summary.txt"
sleep 3

echo "[*] Collecting defended service metrics"
curl -fsS -H "X-API-Key: $API_KEY" "http://$TARGET_IP:8080/admin/metrics" | tee "$EVID_DIR/defended_metrics.json"

echo "[*] Checking for Snort repeated-request alerts"
grep -n "ELEC0138 repeated requests to thermostat service" "$LOG_DIR/defense_snort_console.log" > "$EVID_DIR/defense_http_alert_hits.txt" || true

HTTP_HITS="$(count_lines_if_nonempty "$EVID_DIR/defense_http_alert_hits.txt")"
API_KEY_FINGERPRINT="$(sha256_fingerprint "$API_KEY")"

echo "[*] Making logs readable"
sudo chmod -R a+r "$WORK_DIR"

cat > "$EVID_DIR/defense_demo_summary.txt" <<EOF
interface=$TARGET_IFACE
target_ip=$TARGET_IP
home_net=$HOME_NET
auth_mode=api_key
api_key_fingerprint=$API_KEY_FINGERPRINT
http_alert_hits=$HTTP_HITS
logs_dir=$LOG_DIR
evidence_dir=$EVID_DIR
EOF

copy_artifacts_to_host "$HOST_EVID_DIR" \
  "$EVID_DIR/defense_demo_summary.txt" \
  "$EVID_DIR/defense_status.json" \
  "$EVID_DIR/unauthorized_set_temp_body.json" \
  "$EVID_DIR/authorized_set_temp_body.json" \
  "$EVID_DIR/defended_status_burst_summary.txt" \
  "$EVID_DIR/defended_metrics.json" \
  "$EVID_DIR/defense_http_alert_hits.txt" \
  "$LOG_DIR/defense_snort_console.log" \
  "$LOG_DIR/defended_thermostat.log"

echo
echo "[*] Multi-layer defense demo completed"
cat "$EVID_DIR/defense_demo_summary.txt"
echo
echo "[*] Next command to display a compact screenshot view:"
echo "bash show-defense-results.sh"
