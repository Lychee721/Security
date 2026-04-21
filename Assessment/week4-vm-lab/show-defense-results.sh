#!/usr/bin/env bash
set -euo pipefail

EVID_DIR="$HOME/week4-lab/evidence"
LOG_DIR="$HOME/week4-lab/logs"

echo "===== DEFENSE DEMO SUMMARY ====="
cat "$EVID_DIR/defense_demo_summary.txt"
echo

echo "===== UNAUTHORIZED SET TEMP STATUS ====="
cat "$EVID_DIR/unauthorized_set_temp_status.txt"
cat "$EVID_DIR/unauthorized_set_temp_body.json"
echo

echo "===== AUTHORIZED SET TEMP STATUS ====="
cat "$EVID_DIR/authorized_set_temp_status.txt"
cat "$EVID_DIR/authorized_set_temp_body.json"
echo

echo "===== STATUS BURST SUMMARY ====="
cat "$EVID_DIR/defended_status_burst_summary.txt"
echo

echo "===== DEFENSE METRICS ====="
cat "$EVID_DIR/defended_metrics.json"
echo

if [[ -s "$EVID_DIR/defense_http_alert_hits.txt" ]]; then
  echo "===== SNORT ALERT HITS ====="
  cat "$EVID_DIR/defense_http_alert_hits.txt"
  echo
fi

echo "===== DEFENDED THERMOSTAT LOG (tail) ====="
tail -n 30 "$LOG_DIR/defended_thermostat.log"
echo

echo "===== DEFENSE SNORT LOG (tail) ====="
tail -n 30 "$LOG_DIR/defense_snort_console.log"
