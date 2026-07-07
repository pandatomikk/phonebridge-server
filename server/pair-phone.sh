#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DISCOVERABLE_SECONDS=180

info() { printf 'INFO    %s\n' "$1"; }
ok() { printf 'OK      %s\n' "$1"; }
warning() { printf 'WARNING %s\n' "$1"; }
error() { printf 'ERROR   %s\n' "$1" >&2; }
section() { printf '\n== %s ==\n' "$1"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--check|--discoverable|--pair|--remove|--help]

Commands:
  --check         Show current adapter and paired-device state. No changes. Default.
  --discoverable  Enable temporary discoverable/pairable mode for ${DISCOVERABLE_SECONDS}s,
                  display a countdown, then restore previous discoverable/pairable state.
  --pair          Guide Android pairing and display current pairing status.
  --remove        List paired devices and interactively remove one selected device.
  --help          Show this help.

This helper does not configure HFP audio and does not edit BlueZ configuration files.
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

system_bus_available() {
  have_command busctl && busctl --system list >/dev/null 2>&1
}

require_bluetoothctl() {
  if ! have_command bluetoothctl; then
    error "bluetoothctl is required"
    return 1
  fi
  if ! system_bus_available; then
    error "system D-Bus is not reachable; BlueZ cannot be controlled from this session"
    return 1
  fi
}

bluetooth_show() {
  bluetoothctl show 2>/dev/null || true
}

bluetooth_property() {
  local name="$1"
  bluetooth_show | sed -n "s/^[[:space:]]*$name: //p" | head -n 1
}

adapter_present() {
  bluetoothctl list 2>/dev/null | grep -q '^Controller '
}

paired_devices() {
  bluetoothctl paired-devices 2>/dev/null || bluetoothctl devices Paired 2>/dev/null || true
}

show_status() {
  section "Bluetooth pairing status"
  require_bluetoothctl

  if adapter_present; then
    ok "adapter present"
    bluetoothctl list 2>/dev/null | sed 's/^/INFO    /'
  else
    error "no Bluetooth adapter present"
    return 1
  fi

  info "adapter state:"
  bluetooth_show | sed -n '1,80p' | sed 's/^/INFO    /'

  info "paired devices:"
  paired_devices | sed 's/^/INFO    /' || warning "could not list paired devices"
}

restore_state() {
  local previous_discoverable="$1"
  local previous_pairable="$2"
  info "restoring previous pairable/discoverable state"
  if [[ -n "$previous_discoverable" ]]; then
    bluetoothctl discoverable "$previous_discoverable" >/dev/null 2>&1 || warning "could not restore discoverable=$previous_discoverable"
  fi
  if [[ -n "$previous_pairable" ]]; then
    bluetoothctl pairable "$previous_pairable" >/dev/null 2>&1 || warning "could not restore pairable=$previous_pairable"
  fi
}

discoverable_window() {
  section "Temporary discoverable mode"
  require_bluetoothctl

  if ! adapter_present; then
    error "no Bluetooth adapter present"
    return 1
  fi

  local previous_discoverable previous_pairable
  previous_discoverable="$(bluetooth_property "Discoverable")"
  previous_pairable="$(bluetooth_property "Pairable")"

  trap 'restore_state "$previous_discoverable" "$previous_pairable"' EXIT
  trap 'trap - EXIT INT TERM; restore_state "$previous_discoverable" "$previous_pairable"; exit 130' INT TERM

  bluetoothctl power on >/dev/null 2>&1 || warning "could not power adapter on"
  bluetoothctl pairable-timeout "$DISCOVERABLE_SECONDS" >/dev/null 2>&1 || true
  bluetoothctl discoverable-timeout "$DISCOVERABLE_SECONDS" >/dev/null 2>&1 || true
  bluetoothctl pairable on >/dev/null 2>&1 || warning "could not enable pairable mode"
  bluetoothctl discoverable on >/dev/null 2>&1 || warning "could not enable discoverable mode"

  ok "PhoneBridge should be discoverable for ${DISCOVERABLE_SECONDS}s"
  info "On Android: Settings -> Bluetooth -> Pair new device -> select PhoneBridge"

  local remaining
  for ((remaining = DISCOVERABLE_SECONDS; remaining > 0; remaining--)); do
    printf '\rINFO    discoverable window remaining: %3ss ' "$remaining"
    sleep 1
  done
  printf '\n'

  restore_state "$previous_discoverable" "$previous_pairable"
  trap - EXIT INT TERM
  show_status
}

pair_guide() {
  section "Android pairing guide"
  require_bluetoothctl

  cat <<'EOF'
Manual bluetoothctl flow if Android requests confirmation:

  bluetoothctl
  power on
  agent KeyboardDisplay
  default-agent
  pairable on
  discoverable on
  devices
  paired-devices
  info <ANDROID_MAC>
  trust <ANDROID_MAC>

This helper does not assume success. Confirm on Android that the device is connected for calls.
EOF

  show_status
}

remove_device() {
  section "Remove paired device"
  require_bluetoothctl

  local devices
  devices="$(paired_devices)"
  if [[ -z "$devices" ]]; then
    warning "no paired devices found"
    return 0
  fi

  info "paired devices:"
  printf '%s\n' "$devices" | nl -w1 -s'. ' | sed 's/^/INFO    /'

  if [[ ! -t 0 ]]; then
    error "--remove requires an interactive terminal"
    return 1
  fi

  printf 'Enter the device number to remove, or blank to cancel: '
  local selection
  read -r selection
  if [[ -z "$selection" ]]; then
    info "remove cancelled"
    return 0
  fi
  if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
    error "invalid selection: $selection"
    return 2
  fi

  local line mac
  line="$(printf '%s\n' "$devices" | sed -n "${selection}p")"
  mac="$(awk '{print $2}' <<<"$line")"
  if [[ -z "$mac" ]]; then
    error "selection does not match a paired device"
    return 1
  fi

  printf 'Remove paired device %s? [y/N] ' "$line"
  local answer
  read -r answer
  if [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]; then
    bluetoothctl remove "$mac"
  else
    info "remove cancelled"
  fi
}

main() {
  local command="--check"
  case "${1:---check}" in
    --check | --discoverable | --pair | --remove)
      command="$1"
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

  case "$command" in
    --check)
      show_status
      ;;
    --discoverable)
      discoverable_window
      ;;
    --pair)
      pair_guide
      ;;
    --remove)
      remove_device
      ;;
  esac
}

main "$@"
