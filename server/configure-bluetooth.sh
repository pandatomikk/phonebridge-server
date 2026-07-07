#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
APPLY=false

log() {
  printf '%s\n' "$1"
}

warn() {
  printf 'WARN  %s\n' "$1"
}

ok() {
  printf 'OK    %s\n' "$1"
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

system_bus_available() {
  have_command busctl && busctl --system list >/dev/null 2>&1
}

inspect_bluez() {
  log "Inspecting Bluetooth/BlueZ state..."

  if have_command systemctl && systemctl is-active --quiet bluetooth.service 2>/dev/null; then
    ok "bluetooth.service is active"
  else
    warn "bluetooth.service is not active"
  fi

  if have_command bluetoothctl; then
    if system_bus_available; then
      bluetoothctl list || warn "bluetoothctl list failed"
      bluetoothctl show || warn "bluetoothctl show failed"
    else
      warn "system D-Bus is not reachable; skipping bluetoothctl controller details"
    fi
  else
    warn "bluetoothctl is missing"
  fi
}

apply_configuration() {
  log "No Bluetooth configuration is applied in v0.1."
  log "Future versions will add guarded BlueZ HFP/HSP settings after they are documented."
  log "This script will not enable discoverable or pairable mode automatically."
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--apply|--help]

Without --apply, inspect Bluetooth/BlueZ state only.
--apply is accepted for future compatibility, but v0.1 does not modify Bluetooth settings.
EOF
}

main() {
  case "${1:-}" in
    --apply)
      APPLY=true
      ;;
    -h | --help)
      usage
      return 0
      ;;
    "")
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      return 2
      ;;
  esac

  inspect_bluez

  if [[ "$APPLY" == true ]]; then
    apply_configuration
  else
    log "Dry run only. Use --apply when a future version provides safe configuration changes."
  fi
}

main "$@"
