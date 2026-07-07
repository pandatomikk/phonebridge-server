#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

readonly REQUIRED_PACKAGES=(
  bluez
  bluetooth
  pipewire
  pipewire-bin
  wireplumber
  ofono
  dbus
)

log() {
  printf '%s\n' "$1"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    printf 'This action requires root. Re-run with sudo.\n' >&2
    return 1
  fi
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

print_packages() {
  log "PhoneBridge Server target packages:"
  printf '  %s\n' "${REQUIRED_PACKAGES[@]}"
}

install_packages() {
  require_root

  if ! have_command apt-get; then
    printf 'apt-get was not found. This installer targets Debian/Raspberry Pi OS.\n' >&2
    return 1
  fi

  log "Updating package metadata with apt-get update..."
  apt-get update

  log "Installing PhoneBridge Server target packages..."
  apt-get install -y "${REQUIRED_PACKAGES[@]}"

  log "Package installation completed."
  log "Run ./server/check-system.sh as the target desktop/audio user next."
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--list|--install|--help]

Options:
  --list     List required packages without changing the system.
  --install  Install required packages with apt-get. Requires root.
  --help     Show this help.

Default: --list
EOF
}

main() {
  case "${1:---list}" in
    --list)
      print_packages
      ;;
    --install)
      install_packages
      ;;
    -h | --help)
      usage
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      return 2
      ;;
  esac
}

main "$@"
