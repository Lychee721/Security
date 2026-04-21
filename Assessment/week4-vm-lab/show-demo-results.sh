#!/usr/bin/env bash
set -euo pipefail

EVID_DIR="$HOME/week4-lab/evidence"
LOG_DIR="$HOME/week4-lab/logs"

echo "===== DEMO SUMMARY ====="
cat "$EVID_DIR/demo_summary.txt"
echo

echo "===== IP ADDR ====="
cat "$EVID_DIR/ip_addr.txt"
echo

echo "===== SNORT TEST (tail) ====="
tail -n 20 "$EVID_DIR/snort_test.txt"
echo

if [[ -s "$EVID_DIR/http_alert_hits.txt" ]]; then
  echo "===== HTTP ALERT HITS ====="
  cat "$EVID_DIR/http_alert_hits.txt"
  echo
fi

if [[ -s "$EVID_DIR/icmp_alert_hits.txt" ]]; then
  echo "===== ICMP ALERT HITS ====="
  cat "$EVID_DIR/icmp_alert_hits.txt"
  echo
fi

echo "===== SNORT LOG (tail) ====="
tail -n 25 "$LOG_DIR/snort_console.log"
echo

echo "===== THERMOSTAT LOG (tail) ====="
tail -n 20 "$LOG_DIR/thermostat.log"
