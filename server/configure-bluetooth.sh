#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DISCOVERABLE_TIMEOUT_SECONDS=180

info() { printf 'INFO    %s\n' "$1"; }
ok() { printf 'OK      %s\n' "$1"; }
warning() { printf 'WARNING %s\n' "$1"; }
error() { printf 'ERROR   %s\n' "$1" >&2; }
section() { printf '\n== %s ==\n' "$1"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--check|--apply|--help]

Modes:
  --check   Inspect BlueZ/Bluetooth state. No system changes. Default.
  --apply   Start/enable bluetooth.service, unblock rfkill if possible, and make the
            adapter pairable/discoverable for ${DISCOVERABLE_TIMEOUT_SECONDS}s.
  --help    Show this help.

This script does not force HFP/HSP roles and does not write permanent BlueZ config.
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

system_bus_available() {
  have_command busctl && busctl --system list >/dev/null 2>&1
}

require_root_for_service_changes() {
  if [[ "${EUID}" -ne 0 ]]; then
    error "--apply needs root for systemctl/rfkill operations; re-run with sudo"
    return 1
  fi
}

run_or_warn() {
  local description="$1"
  shift
  if "$@"; then
    ok "$description"
  else
    warning "$description failed"
  fi
}

show_bluetoothctl_state() {
  if ! have_command bluetoothctl; then
    warning "bluetoothctl is missing"
    return
  fi
  if ! system_bus_available; then
    warning "system D-Bus is not reachable; skipping bluetoothctl state"
    return
  fi

  info "controllers:"
  bluetoothctl list 2>/dev/null | sed 's/^/INFO    /' || warning "bluetoothctl list failed"
  info "default controller:"
  bluetoothctl show 2>/dev/null | sed 's/^/INFO    /' || warning "bluetoothctl show failed"
}

check_bluetooth() {
  section "Bluetooth check"

  if have_command systemctl && systemctl is-active --quiet bluetooth.service 2>/dev/null; then
    ok "bluetooth.service is active"
  else
    warning "bluetooth.service is not active"
  fi

  if have_command rfkill; then
    info "rfkill Bluetooth state:"
    rfkill list bluetooth 2>/dev/null | sed 's/^/INFO    /' || warning "rfkill has no Bluetooth entries"
  else
    warning "rfkill is missing"
  fi

  show_bluetoothctl_state

  info "manual pairing commands:"
  printf 'INFO      bluetoothctl\n'
  printf 'INFO      power on\n'
  printf 'INFO      agent KeyboardDisplay\n'
  printf 'INFO      default-agent\n'
  printf 'INFO      pairable on\n'
  printf 'INFO      discoverable on\n'
}

apply_bluetooth() {
  section "Bluetooth apply"
  require_root_for_service_changes

  if ! have_command systemctl; then
    error "systemctl is required"
    return 1
  fi

  run_or_warn "enabled bluetooth.service" systemctl enable bluetooth.service
  run_or_warn "started bluetooth.service" systemctl start bluetooth.service

  if have_command rfkill; then
    run_or_warn "unblocked Bluetooth rfkill entries" rfkill unblock bluetooth
  else
    warning "rfkill is missing; cannot unblock Bluetooth"
  fi

  if have_command bluetoothctl && system_bus_available; then
    info "enabling temporary pairable/discoverable mode"
    bluetoothctl power on >/dev/null 2>&1 || warning "bluetoothctl power on failed"
    bluetoothctl pairable on >/dev/null 2>&1 || warning "bluetoothctl pairable on failed"
    bluetoothctl discoverable-timeout "$DISCOVERABLE_TIMEOUT_SECONDS" >/dev/null 2>&1 || true
    bluetoothctl discoverable on >/dev/null 2>&1 || warning "bluetoothctl discoverable on failed"
    ok "pairable/discoverable requested for ${DISCOVERABLE_TIMEOUT_SECONDS}s"
  else
    warning "cannot set pairable/discoverable without bluetoothctl and system D-Bus"
  fi

  info "no permanent BlueZ configuration was written"
  info "HFP/HSP role forcing is intentionally not implemented yet"
  show_bluetoothctl_state
}

main() {
  local mode="--check"
  case "${1:---check}" in
    --check | --apply)
      mode="$1"
      ;;
    -h | --help)
      usage
      return 0
      ;;
    *)
      error "unknown option: $1"
      usage >&2
      return 2
      ;;
  esac

  if [[ "$mode" == "--apply" ]]; then
    apply_bluetooth
  else
    check_bluetooth
  fi
}

main "$@"
