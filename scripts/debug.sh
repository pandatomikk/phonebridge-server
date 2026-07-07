#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  printf '%s\n' "$1"
}

run_section() {
  local title="$1"
  shift

  printf '\n== %s ==\n' "$title"
  "$@" || printf 'WARN  command failed: %s\n' "$*"
}

main() {
  log "PhoneBridge Server debug snapshot"
  log "This script collects command output only; it does not modify system configuration."

  run_section "System" uname -a
  run_section "OS release" cat /etc/os-release
  run_section "PhoneBridge diagnostic" "$ROOT_DIR/server/check-system.sh"

  if command -v bluetoothctl >/dev/null 2>&1; then
    run_section "bluetoothctl show" bluetoothctl show
  fi

  if command -v wpctl >/dev/null 2>&1; then
    run_section "wpctl status" wpctl status
  fi
}

main "$@"
