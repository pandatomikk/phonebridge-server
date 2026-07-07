#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
FAILURES=0
WARNINGS=0

print_header() {
  printf '\n== %s ==\n' "$1"
}

info() {
  printf 'INFO  %s\n' "$1"
}

ok() {
  printf 'OK    %s\n' "$1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf 'WARN  %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf 'FAIL  %s\n' "$1"
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

check_command() {
  local command_name="$1"
  local package_hint="$2"

  if have_command "$command_name"; then
    ok "command '$command_name' is available"
  else
    fail "command '$command_name' is missing (package hint: $package_hint)"
  fi
}

system_service_state() {
  local service_name="$1"

  if ! have_command systemctl; then
    warn "systemctl is not available; cannot inspect $service_name"
    return
  fi

  if systemctl list-unit-files "$service_name" >/dev/null 2>&1; then
    if systemctl is-active --quiet "$service_name"; then
      ok "$service_name is active"
    elif systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
      warn "$service_name is installed and enabled, but not active"
    else
      warn "$service_name is installed, but not active or enabled"
    fi
  else
    fail "$service_name is not known to systemd"
  fi
}

user_service_state() {
  local service_name="$1"

  if ! have_command systemctl; then
    warn "systemctl is not available; cannot inspect user service $service_name"
    return
  fi

  if systemctl --user list-unit-files "$service_name" >/dev/null 2>&1; then
    if systemctl --user is-active --quiet "$service_name"; then
      ok "user service $service_name is active"
    else
      warn "user service $service_name exists but is not active for this user"
    fi
  else
    warn "user service $service_name is not known for this user"
  fi
}

check_os() {
  print_header "Operating system"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    info "system: ${PRETTY_NAME:-unknown Linux}"
    case "${ID:-unknown}" in
      debian | raspbian)
        ok "Debian-family distribution detected"
        ;;
      *)
        warn "target platform is Raspberry Pi OS Bookworm or Debian 13+; detected ID=${ID:-unknown}"
        ;;
    esac
  else
    warn "/etc/os-release is not readable"
  fi
}

check_bluetooth() {
  print_header "Bluetooth and BlueZ"
  check_command bluetoothctl bluez
  check_command btmgmt bluez
  system_service_state bluetooth.service

  if have_command lsmod && lsmod | awk '{print $1}' | grep -qx bluetooth; then
    ok "kernel module 'bluetooth' is loaded"
  else
    warn "kernel module 'bluetooth' is not currently listed by lsmod"
  fi

  if have_command bluetoothctl; then
    if bluetoothctl list 2>/dev/null | grep -q '^Controller '; then
      ok "bluetoothctl reports at least one controller"
    else
      warn "bluetoothctl does not report a controller"
    fi
  fi
}

check_pipewire() {
  print_header "PipeWire"
  check_command pipewire pipewire
  check_command pw-cli pipewire-bin
  check_command wpctl wireplumber
  user_service_state pipewire.service
  user_service_state pipewire-pulse.service

  if have_command pw-cli; then
    if pw-cli info 0 >/dev/null 2>&1; then
      ok "PipeWire core is reachable through pw-cli"
    else
      warn "pw-cli is installed but cannot reach a PipeWire core for this user"
    fi
  fi
}

check_wireplumber() {
  print_header "WirePlumber"
  check_command wireplumber wireplumber
  user_service_state wireplumber.service

  if have_command wpctl; then
    if wpctl status >/dev/null 2>&1; then
      ok "wpctl can read WirePlumber/PipeWire status"
    else
      warn "wpctl is installed but cannot read status"
    fi
  fi
}

check_ofono() {
  print_header "oFono"
  check_command ofonod ofono
  system_service_state ofono.service

  if have_command busctl; then
    if busctl --system list 2>/dev/null | grep -q 'org.ofono'; then
      ok "org.ofono is present on the system D-Bus"
    else
      warn "org.ofono is not present on the system D-Bus"
    fi
  else
    warn "busctl is not available; cannot inspect system D-Bus"
  fi
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--help]

Run PhoneBridge Server v0.1 diagnostics.
This script does not modify system configuration.
EOF
}

main() {
  case "${1:-}" in
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

  print_header "PhoneBridge Server diagnostic"
  info "diagnostic only; no system configuration will be changed"

  check_os
  check_bluetooth
  check_pipewire
  check_wireplumber
  check_ofono

  print_header "Summary"
  printf 'Warnings: %d\n' "$WARNINGS"
  printf 'Failures: %d\n' "$FAILURES"

  if ((FAILURES > 0)); then
    return 1
  fi
}

main "$@"
