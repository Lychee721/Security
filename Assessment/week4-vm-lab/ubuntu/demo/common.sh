#!/usr/bin/env bash
set -euo pipefail

is_private_ip() {
  local ip="$1"
  [[ "$ip" =~ ^10\. ]] || \
  [[ "$ip" =~ ^192\.168\. ]] || \
  [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || \
  [[ "$ip" =~ ^169\.254\. ]]
}

require_private_ip() {
  local ip="$1"
  if ! is_private_ip "$ip"; then
    echo "[!] Refusing to use non-private or non-lab-local IP: $ip"
    exit 1
  fi
}

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "[!] Missing file: $file"
    exit 1
  fi
}

detect_lab_interface() {
  local prefer_link_local="${1:-0}"
  if [[ "$prefer_link_local" == "1" ]]; then
    ip -o -4 addr show | awk '
      $2 == "enp0s8" && $4 ~ /^169\.254\./ {print $2; exit}
      $4 ~ /^192\.168\.56\./ {print $2; exit}
      $4 ~ /^10\./ && $2 != "lo" {print $2; exit}
      $4 ~ /^192\.168\./ && $2 != "lo" {print $2; exit}
      $4 ~ /^172\.(1[6-9]|2[0-9]|3[0-1])\./ && $2 != "lo" {print $2; exit}
      $4 ~ /^169\.254\./ && $2 != "lo" {print $2; exit}
    '
    return
  fi

  ip -o -4 addr show | awk '
    $4 ~ /^192\.168\.56\./ {print $2; exit}
    $2 == "enp0s8" && $4 ~ /^169\.254\./ {print $2; exit}
    $4 ~ /^10\./ && $2 != "lo" {print $2; exit}
    $4 ~ /^192\.168\./ && $2 != "lo" {print $2; exit}
    $4 ~ /^172\.(1[6-9]|2[0-9]|3[0-1])\./ && $2 != "lo" {print $2; exit}
    $4 ~ /^169\.254\./ && $2 != "lo" {print $2; exit}
  '
}

home_net_for_ip() {
  local ip="$1"
  local mode="${2:-subnet24}"

  if [[ "$mode" == "link_local_16" && "$ip" =~ ^169\.254\. ]]; then
    echo "169.254.0.0/16"
    return
  fi

  echo "$ip" | awk -F. '{print $1 "." $2 "." $3 ".0/24"}'
}

count_lines_if_nonempty() {
  local file="$1"
  if [[ -s "$file" ]]; then
    wc -l < "$file"
  else
    echo 0
  fi
}

copy_with_sudo_fallback() {
  local src="$1"
  local dest_dir="$2"
  cp -f "$src" "$dest_dir"/ 2>/dev/null || sudo cp -f "$src" "$dest_dir"/
}

copy_artifacts_to_host() {
  local dest_dir="$1"
  shift

  local src
  for src in "$@"; do
    copy_with_sudo_fallback "$src" "$dest_dir"
  done
}

ensure_runtime_packages() {
  local missing=()
  local spec pkg cmd

  for spec in "$@"; do
    pkg="${spec%%:*}"
    cmd="${spec#*:}"
    if [[ "$cmd" == "$spec" ]]; then
      cmd="$pkg"
    fi

    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    echo "[*] Required runtime packages already installed"
    return
  fi

  echo "[*] Installing missing runtime packages: ${missing[*]}"
  sudo apt update
  sudo DEBIAN_FRONTEND=noninteractive apt install -y "${missing[@]}"
}

sha256_fingerprint() {
  local value="$1"
  printf '%s' "$value" | sha256sum | awk '{print substr($1, 1, 12)}'
}
