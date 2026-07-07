#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DISCOVERABLE_TIMEOUT_SECONDS=180
PHONEBRIDGE_ALIAS="PhoneBridge"
STATE_DIR="/var/lib/phonebridge-server"
STATE_FILE="$STATE_DIR/bluetooth-state.env"

info() { printf 'INFO    %s\n' "$1"; }
ok() { printf 'OK      %s\n' "$1"; }
warning() { printf 'WARNING %s\n' "$1"; }
error() { printf 'ERROR   %s\n' "$1" >&2; }
section() { printf '\n== %s ==\n' "$1"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--check|--apply|--yes|--help]

Modes:
  --check   Inspect BlueZ/Bluetooth state. No system changes. Default.
  --apply   Start/enable bluetooth.service, unblock rfkill if possible, power the
            controller on, set alias "$PHONEBRIDGE_ALIAS", and request temporary
            pairable/discoverable mode for ${DISCOVERABLE_TIMEOUT_SECONDS}s.
  --yes     Skip the interactive confirmation required by --apply.
  --help    Show this help.

This script does not edit bluetoothd.conf and does not force HFP/HSP roles.
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

system_bus_available() {
  have_command busctl && busctl --system list >/dev/null 2>&1
}

bluetoothctl_available() {
  have_command bluetoothctl && system_bus_available
}

bluetooth_show() {
  bluetoothctl show 2>/dev/null || true
}

bluetooth_property() {
  local name="$1"
  bluetooth_show | sed -n "s/^[[:space:]]*$name: //p" | head -n 1
}

bluetoothd_path() {
  if have_command bluetoothd; then
    command -v bluetoothd
    return 0
  fi
  for candidate in /usr/sbin/bluetoothd /usr/lib/bluetooth/bluetoothd /usr/libexec/bluetooth/bluetoothd; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

bool_status() {
  local label="$1"
  local value="$2"
  case "$value" in
    yes | true | on)
      ok "$label: $value"
      ;;
    no | false | off | "")
      warning "$label: ${value:-unknown}"
      ;;
    *)
      info "$label: $value"
      ;;
  esac
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

run_with_timeout() {
  local seconds="$1"
  shift
  if have_command timeout; then
    timeout "$seconds" "$@"
  else
    "$@"
  fi
}

confirm_apply() {
  local assume_yes="$1"
  if [[ "$assume_yes" == "true" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    error "--apply requires an interactive confirmation; re-run with --yes if intentional"
    return 1
  fi
  printf 'This will start/enable bluetooth.service and request temporary pairing mode. Continue? [y/N] '
  local answer
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

print_bluetoothd_version() {
  section "BlueZ daemon"
  local daemon_path
  if daemon_path="$(bluetoothd_path)"; then
    info "bluetoothd path: $daemon_path"
    info "bluetoothd version: $("$daemon_path" -v 2>/dev/null || printf 'unknown')"
  else
    warning "bluetoothd binary not found"
  fi

  if have_command systemctl; then
    info "bluetooth.service state:"
    systemctl status bluetooth.service --no-pager 2>/dev/null | sed -n '1,16p' | sed 's/^/INFO    /' || warning "bluetooth.service status unavailable"
    info "bluetooth.service ExecStart:"
    systemctl show bluetooth.service -p ExecStart --value 2>/dev/null | sed 's/^/INFO    /' || true
  fi
}

print_plugins() {
  section "BlueZ plugins"
  info "BlueZ does not expose loaded plugin names through the stable Adapter1 API."
  if have_command systemctl; then
    local exec_start
    exec_start="$(systemctl show bluetooth.service -p ExecStart --value 2>/dev/null || true)"
    if [[ -n "$exec_start" ]]; then
      info "bluetoothd command line:"
      printf '%s\n' "$exec_start" | sed 's/^/INFO    /'
      if grep -q -- '--noplugin\|--plugin' <<<"$exec_start"; then
        warning "bluetoothd plugin filters are present in ExecStart; review them manually"
      else
        ok "no bluetoothd plugin filters detected in ExecStart"
      fi
    else
      warning "could not read bluetooth.service ExecStart"
    fi
  fi
  info "Manual plugin investigation: run bluetoothd in foreground with debug on a test system only."
}

print_rfkill() {
  section "rfkill"
  if have_command rfkill; then
    rfkill list bluetooth 2>/dev/null | sed 's/^/INFO    /' || warning "rfkill has no Bluetooth entries"
    if rfkill list bluetooth 2>/dev/null | grep -qi 'blocked: yes'; then
      warning "at least one Bluetooth rfkill entry is blocked"
    else
      ok "Bluetooth rfkill entries are not blocked"
    fi
  else
    warning "rfkill is missing"
  fi
}

print_adapter_report() {
  section "Adapter"
  if ! bluetoothctl_available; then
    warning "bluetoothctl or system D-Bus is unavailable"
    return
  fi

  local controllers
  controllers="$(bluetoothctl list 2>/dev/null || true)"
  if grep -q '^Controller ' <<<"$controllers"; then
    ok "adapter present"
    printf '%s\n' "$controllers" | sed 's/^/INFO    /'
  else
    error "no Bluetooth adapter reported by bluetoothctl"
    return
  fi

  local address alias powered pairable discoverable discovering
  address="$(bluetooth_property "Controller" | awk '{print $1}')"
  alias="$(bluetooth_property "Alias")"
  powered="$(bluetooth_property "Powered")"
  pairable="$(bluetooth_property "Pairable")"
  discoverable="$(bluetooth_property "Discoverable")"
  discovering="$(bluetooth_property "Discovering")"

  info "controller address: ${address:-unknown}"
  info "current alias: ${alias:-unknown}"
  bool_status "powered" "$powered"
  bool_status "pairable" "$pairable"
  bool_status "discoverable" "$discoverable"
  info "discovering: ${discovering:-unknown}"

  info "supported UUIDs/profiles reported by BlueZ:"
  if bluetooth_show | grep 'UUID:' >/dev/null; then
    bluetooth_show | grep 'UUID:' | sed 's/^/INFO    /'
  else
    warning "no UUID/profile lines reported by bluetoothctl show"
  fi
}

print_controller_capabilities() {
  section "Controller capabilities"
  if have_command btmgmt; then
    run_with_timeout 5 btmgmt info 2>/dev/null | sed -n '1,120p' | sed 's/^/INFO    /' || warning "btmgmt info failed or timed out"
  else
    warning "btmgmt is missing"
  fi
}

print_dbus_objects() {
  section "D-Bus objects"
  if system_bus_available; then
    if busctl --system list 2>/dev/null | grep -q 'org.bluez'; then
      ok "org.bluez is present on system D-Bus"
      busctl --system tree org.bluez 2>/dev/null | sed -n '1,140p' | sed 's/^/INFO    /' || warning "could not inspect org.bluez tree"
      info "AgentManager1 is expected at /org/bluez; default agent status is per-client and not persistently exposed."
    else
      warning "org.bluez is not present on system D-Bus"
    fi
  else
    warning "system D-Bus is unavailable"
  fi
}

print_agent_status() {
  section "Pairing agent"
  if system_bus_available && busctl --system list 2>/dev/null | grep -q 'org.bluez'; then
    if busctl --system introspect org.bluez /org/bluez org.bluez.AgentManager1 >/dev/null 2>&1; then
      ok "org.bluez.AgentManager1 is available"
      info "default-agent state is owned by the bluetoothctl/client process and is not exposed as a stable persistent property"
    else
      warning "org.bluez.AgentManager1 introspection failed"
    fi
  else
    warning "cannot inspect AgentManager1 without org.bluez on system D-Bus"
  fi
}

save_previous_state() {
  mkdir -p "$STATE_DIR"
  chmod 0755 "$STATE_DIR"
  {
    printf 'PREVIOUS_ALIAS=%q\n' "$(bluetooth_property "Alias")"
    printf 'PREVIOUS_POWERED=%q\n' "$(bluetooth_property "Powered")"
    printf 'PREVIOUS_PAIRABLE=%q\n' "$(bluetooth_property "Pairable")"
    printf 'PREVIOUS_DISCOVERABLE=%q\n' "$(bluetooth_property "Discoverable")"
    printf 'SAVED_AT=%q\n' "$(date -Is)"
  } >"$STATE_FILE"
  chmod 0644 "$STATE_FILE"
  ok "saved previous adapter state to $STATE_FILE"
}

print_manual_hfp_notes() {
  section "HFP notes"
  info "BlueZ handles pairing, adapter state, Device1, Profile1, and SDP/profile plumbing."
  info "HFP Hands-Free behavior normally also needs a backend such as PipeWire native HFP/HSP or oFono."
  info "Android is expected to be Audio Gateway; PhoneBridge must appear as Hands-Free."
  info "This script does not edit bluetoothd.conf or force HFP roles."
  info "If Android pairs but does not show call audio, capture bluetoothctl show, busctl tree org.bluez, WirePlumber backend config, and oFono state."
}

check_bluetooth() {
  section "PhoneBridge Bluetooth readiness report"
  info "read-only check; no Bluetooth state will be changed"
  print_bluetoothd_version
  print_rfkill
  print_adapter_report
  print_controller_capabilities
  print_dbus_objects
  print_agent_status
  print_plugins
  print_manual_hfp_notes
}

apply_bluetooth() {
  local assume_yes="$1"
  section "Bluetooth apply"
  require_root_for_service_changes
  confirm_apply "$assume_yes"

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

  if bluetoothctl_available; then
    save_previous_state
    info "setting adapter state for temporary Android pairing"
    bluetoothctl power on >/dev/null 2>&1 || warning "bluetoothctl power on failed"
    bluetoothctl system-alias "$PHONEBRIDGE_ALIAS" >/dev/null 2>&1 || bluetoothctl alias "$PHONEBRIDGE_ALIAS" >/dev/null 2>&1 || warning "setting alias failed"
    bluetoothctl pairable-timeout "$DISCOVERABLE_TIMEOUT_SECONDS" >/dev/null 2>&1 || true
    bluetoothctl pairable on >/dev/null 2>&1 || warning "bluetoothctl pairable on failed"
    bluetoothctl discoverable-timeout "$DISCOVERABLE_TIMEOUT_SECONDS" >/dev/null 2>&1 || true
    bluetoothctl discoverable on >/dev/null 2>&1 || warning "bluetoothctl discoverable on failed"
    ok "requested alias '$PHONEBRIDGE_ALIAS' and temporary pairable/discoverable mode for ${DISCOVERABLE_TIMEOUT_SECONDS}s"
  else
    warning "cannot set adapter state without bluetoothctl and system D-Bus"
  fi

  info "no permanent bluetoothd.conf changes were made"
  info "reversal: inspect $STATE_FILE if you need the previous alias/state"
  print_adapter_report
  print_manual_hfp_notes
}

main() {
  local mode="--check"
  local assume_yes=false
  while (($# > 0)); do
    case "$1" in
      --check | --apply)
        mode="$1"
        shift
        ;;
      --yes)
        assume_yes=true
        shift
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
  done

  if [[ "$mode" == "--apply" ]]; then
    apply_bluetooth "$assume_yes"
  else
    check_bluetooth
  fi
}

main "$@"
