#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
ERRORS=0
WARNINGS=0

info() { printf 'INFO    %s\n' "$1"; }
ok() { printf 'OK      %s\n' "$1"; }
warning() { WARNINGS=$((WARNINGS + 1)); printf 'WARNING %s\n' "$1"; }
error() { ERRORS=$((ERRORS + 1)); printf 'ERROR   %s\n' "$1"; }
section() { printf '\n== %s ==\n' "$1"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--help]

Run a read-only PhoneBridge Server diagnostic.

Exit code:
  0  no blocking errors were found; warnings may still be present
  1  at least one blocking prerequisite is missing
  2  invalid command-line option
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

run_capture() {
  local output
  if output="$("$@" 2>/dev/null)"; then
    printf '%s\n' "$output"
    return 0
  fi
  return 1
}

package_version() {
  local package_name="$1"
  if have_command dpkg-query; then
    dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null || true
  fi
}

command_check() {
  local command_name="$1"
  local package_hint="$2"
  local severity="${3:-error}"

  if have_command "$command_name"; then
    ok "command '$command_name' found"
  elif [[ "$severity" == "warning" ]]; then
    warning "command '$command_name' missing (package hint: $package_hint)"
  else
    error "command '$command_name' missing (package hint: $package_hint)"
  fi
}

system_bus_available() {
  have_command busctl && busctl --system list >/dev/null 2>&1
}

user_bus_available() {
  have_command busctl && busctl --user list >/dev/null 2>&1
}

systemd_available() {
  have_command systemctl && systemctl --version >/dev/null 2>&1
}

system_service_state() {
  local service_name="$1"
  local severity="${2:-error}"

  if ! systemd_available; then
    error "systemd/systemctl is not available; cannot inspect $service_name"
    return
  fi

  if ! systemctl list-unit-files "$service_name" >/dev/null 2>&1; then
    if [[ "$severity" == "warning" ]]; then
      warning "$service_name is not known to systemd"
    else
      error "$service_name is not known to systemd"
    fi
    return
  fi

  if systemctl is-active --quiet "$service_name" 2>/dev/null; then
    ok "$service_name is active"
  elif systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
    warning "$service_name is enabled but not active"
  else
    if [[ "$severity" == "warning" ]]; then
      warning "$service_name is installed but not active"
    else
      error "$service_name is installed but not active"
    fi
  fi
}

user_service_state() {
  local service_name="$1"
  local severity="${2:-warning}"

  if ! systemd_available; then
    error "systemd/systemctl is not available; cannot inspect user service $service_name"
    return
  fi

  if ! systemctl --user list-unit-files "$service_name" >/dev/null 2>&1; then
    if [[ "$severity" == "error" ]]; then
      error "user service $service_name is not known for this user"
    else
      warning "user service $service_name is not known for this user"
    fi
    return
  fi

  if systemctl --user is-active --quiet "$service_name" 2>/dev/null; then
    ok "user service $service_name is active"
  elif [[ "$severity" == "error" ]]; then
    error "user service $service_name exists but is not active"
  else
    warning "user service $service_name exists but is not active"
  fi
}

check_os() {
  section "OS and platform"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    info "OS: ${PRETTY_NAME:-unknown}"
    info "ID: ${ID:-unknown}; VERSION_ID: ${VERSION_ID:-unknown}; VERSION_CODENAME: ${VERSION_CODENAME:-unknown}"

    case "${ID:-unknown}:${VERSION_CODENAME:-}" in
      debian:trixie | debian:forky | raspbian:bookworm | raspberrypi:bookworm)
        ok "target Debian/Raspberry Pi family detected"
        ;;
      debian:* | raspbian:* | raspberrypi:*)
        warning "Debian-family system detected, but target is Debian 13+ or Raspberry Pi OS Bookworm"
        ;;
      *)
        warning "unsupported OS family for PhoneBridge target stack"
        ;;
    esac
  else
    error "/etc/os-release is not readable"
  fi

  info "kernel: $(uname -srmo 2>/dev/null || uname -a)"

  if [[ -r /proc/device-tree/model ]]; then
    info "hardware model: $(tr -d '\0' </proc/device-tree/model)"
  elif [[ -r /sys/firmware/devicetree/base/model ]]; then
    info "hardware model: $(tr -d '\0' </sys/firmware/devicetree/base/model)"
  else
    warning "Raspberry Pi model file not found; this may be a non-Pi system"
  fi
}

check_system_services() {
  section "System services and D-Bus"
  command_check uname coreutils error
  command_check journalctl systemd warning
  command_check systemctl systemd error
  command_check busctl systemd error
  command_check lsusb usbutils warning
  command_check lspci pciutils warning

  if systemd_available; then
    ok "systemd is available"
  else
    error "systemd is not available"
  fi

  if system_bus_available; then
    ok "system D-Bus is reachable"
  else
    error "system D-Bus is not reachable"
  fi

  if user_bus_available; then
    ok "user D-Bus is reachable"
  else
    warning "user D-Bus is not reachable; PipeWire user services may be unavailable"
  fi
}

check_user() {
  section "Current user"
  info "user: $(id -un) ($(id -u))"
  info "groups: $(id -nG)"

  for group_name in audio bluetooth pulse pipewire plugdev; do
    if id -nG | tr ' ' '\n' | grep -qx "$group_name"; then
      ok "user is in '$group_name' group"
    else
      if getent group "$group_name" >/dev/null 2>&1; then
        warning "user is not in existing '$group_name' group"
      else
        info "group '$group_name' does not exist on this system"
      fi
    fi
  done
}

check_bluetooth_hardware() {
  section "Bluetooth hardware"

  local found=0
  if have_command lsusb; then
    info "USB Bluetooth candidates:"
    if lsusb 2>/dev/null | grep -Ei 'bluetooth|wireless|radio|csr|broadcom|realtek|intel' | sed 's/^/INFO    /'; then
      found=1
    else
      warning "no obvious USB Bluetooth adapter found in lsusb"
    fi
  else
    warning "lsusb is missing"
  fi

  if have_command lspci; then
    info "PCI Bluetooth/wireless candidates:"
    if lspci 2>/dev/null | grep -Ei 'bluetooth|wireless|wi-fi|wlan|802\.11' | sed 's/^/INFO    /'; then
      found=1
    else
      warning "no obvious PCI Bluetooth/wireless adapter found in lspci"
    fi
  else
    warning "lspci is missing"
  fi

  if [[ -d /sys/class/bluetooth ]] && find /sys/class/bluetooth -mindepth 1 -maxdepth 1 2>/dev/null | grep -q .; then
    ok "kernel exposes Bluetooth devices under /sys/class/bluetooth"
    find /sys/class/bluetooth -mindepth 1 -maxdepth 1 -exec basename {} \; 2>/dev/null | sed 's/^/INFO    /' || true
    found=1
  else
    warning "no Bluetooth devices exposed under /sys/class/bluetooth"
  fi

  if ((found == 0)); then
    error "no Bluetooth adapter evidence found"
  fi
}

check_bluetooth() {
  section "Bluetooth and BlueZ"
  command_check bluetoothctl bluez error
  command_check btmgmt bluez warning
  command_check rfkill rfkill warning
  command_check hciconfig bluez-tools warning

  local bluez_version
  bluez_version="$(package_version bluez)"
  if [[ -n "$bluez_version" ]]; then
    ok "BlueZ package version: $bluez_version"
  else
    error "BlueZ package is not installed or version is not detectable"
  fi

  system_service_state bluetooth.service error

  if have_command rfkill; then
    if rfkill list bluetooth >/dev/null 2>&1; then
      info "rfkill Bluetooth state:"
      rfkill list bluetooth | sed 's/^/INFO    /'
      if rfkill list bluetooth | grep -qi 'blocked: yes'; then
        error "at least one Bluetooth rfkill entry is blocked; run sudo rfkill unblock bluetooth or sudo ./server/configure-bluetooth.sh --apply"
      else
        ok "Bluetooth rfkill entries are not blocked"
      fi
    else
      warning "rfkill does not list Bluetooth entries"
    fi
  fi

  if have_command bluetoothctl && system_bus_available; then
    local controllers
    controllers="$(run_capture bluetoothctl list || true)"
    if printf '%s\n' "$controllers" | grep -q '^Controller '; then
      ok "Bluetooth controller detected"
      printf '%s\n' "$controllers" | sed 's/^/INFO    /'
      info "default controller state:"
      local show_output powered power_state
      show_output="$(bluetoothctl show 2>/dev/null || true)"
      printf '%s\n' "$show_output" | sed 's/^/INFO    /'
      powered="$(printf '%s\n' "$show_output" | sed -n 's/^[[:space:]]*Powered: //p' | head -n 1)"
      power_state="$(printf '%s\n' "$show_output" | sed -n 's/^[[:space:]]*PowerState: //p' | head -n 1)"
      if [[ "$powered" != "yes" ]]; then
        if [[ "$power_state" == *blocked* ]]; then
          error "Bluetooth controller is powered off because it is blocked by rfkill"
        else
          warning "Bluetooth controller is not powered on"
        fi
      fi
    else
      error "no Bluetooth controller detected by bluetoothctl"
    fi
  else
    warning "skipping bluetoothctl controller inspection because command or system D-Bus is unavailable"
  fi
}

check_pipewire() {
  section "PipeWire"
  command_check pipewire pipewire error
  command_check pw-cli pipewire-bin error
  command_check pw-dump pipewire-bin warning
  command_check wpctl wireplumber error
  command_check pactl pulseaudio-utils warning

  local version
  version="$(package_version pipewire)"
  if [[ -n "$version" ]]; then
    ok "PipeWire package version: $version"
  else
    error "PipeWire package is not installed or version is not detectable"
  fi

  user_service_state pipewire.service warning
  user_service_state pipewire-pulse.service warning

  if have_command pw-cli; then
    if pw-cli info 0 >/dev/null 2>&1; then
      ok "PipeWire core is reachable"
      info "PipeWire audio nodes:"
      pw-cli ls Node 2>/dev/null | sed -n '1,80p' | sed 's/^/INFO    /'
    else
      warning "pw-cli is installed but cannot reach a PipeWire core for this user"
    fi
  fi

  if have_command wpctl; then
    if wpctl status >/dev/null 2>&1; then
      ok "wpctl can read PipeWire/WirePlumber status"
      wpctl status 2>/dev/null | sed -n '1,120p' | sed 's/^/INFO    /'
    else
      warning "wpctl cannot read PipeWire/WirePlumber status"
    fi
  fi
}

check_wireplumber() {
  section "WirePlumber"
  command_check wireplumber wireplumber error

  local version
  version="$(package_version wireplumber)"
  if [[ -n "$version" ]]; then
    ok "WirePlumber package version: $version"
  else
    error "WirePlumber package is not installed or version is not detectable"
  fi

  user_service_state wireplumber.service warning

  local config_hits=0
  for dir in /usr/share/wireplumber /etc/wireplumber "${HOME}/.config/wireplumber"; do
    if [[ -d "$dir" ]]; then
      if grep -R "bluez5.roles\|bluez5.hfphsp-backend" "$dir" >/dev/null 2>&1; then
        config_hits=$((config_hits + 1))
        info "Bluetooth policy keys found under $dir"
      fi
    fi
  done
  if ((config_hits == 0)); then
    warning "WirePlumber Bluetooth role/backend config keys were not found in standard paths"
  fi
}

check_ofono() {
  section "oFono"
  command_check ofonod ofono error

  local version
  version="$(package_version ofono)"
  if [[ -n "$version" ]]; then
    ok "oFono package version: $version"
  else
    error "oFono package is not installed or version is not detectable"
  fi

  system_service_state ofono.service error

  if system_bus_available; then
    if busctl --system list 2>/dev/null | grep -q 'org.ofono'; then
      ok "org.ofono is present on the system D-Bus"
      info "oFono object tree:"
      busctl --system tree org.ofono 2>/dev/null | sed -n '1,80p' | sed 's/^/INFO    /' || true
    else
      warning "org.ofono is not present on the system D-Bus"
    fi
  else
    warning "system D-Bus unavailable; skipping oFono D-Bus inspection"
  fi
}

check_profiles() {
  section "Bluetooth profile visibility"

  if have_command bluetoothctl && system_bus_available; then
    local show_output
    show_output="$(run_capture bluetoothctl show || true)"
    if printf '%s\n' "$show_output" | grep -q 'UUID:'; then
      info "local controller advertised UUIDs:"
      printf '%s\n' "$show_output" | grep 'UUID:' | sed 's/^/INFO    /'
    else
      warning "no local Bluetooth UUIDs detected from bluetoothctl show"
    fi
  else
    warning "cannot inspect Bluetooth profiles without bluetoothctl and system D-Bus"
  fi
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

  section "PhoneBridge Server diagnostic"
  info "read-only diagnostic; no system configuration will be changed"

  check_os
  check_system_services
  check_user
  check_bluetooth_hardware
  check_bluetooth
  check_pipewire
  check_wireplumber
  check_ofono
  check_profiles

  section "Summary"
  printf 'INFO    warnings: %d\n' "$WARNINGS"
  printf 'INFO    errors: %d\n' "$ERRORS"

  if ((ERRORS > 0)); then
    return 1
  fi
}

main "$@"
