#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

readonly PACKAGES=(
  bluez
  bluetooth
  pipewire
  pipewire-bin
  wireplumber
  ofono
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

list_packages() {
  log "Packages installed by or relevant to PhoneBridge Server:"
  printf '  %s\n' "${PACKAGES[@]}"
  log ""
  log "Uninstall is not run by default because these packages may be used by the desktop."
}

remove_packages() {
  require_root

  if ! have_command apt-get; then
    printf 'apt-get was not found. This uninstaller targets Debian/Raspberry Pi OS.\n' >&2
    return 1
  fi

  log "Removing selected PhoneBridge Server packages..."
  apt-get remove -y "${PACKAGES[@]}"
  log "Package removal completed. Review apt output for packages kept due to dependencies."
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--list|--remove|--help]

Options:
  --list    List packages without changing the system.
  --remove  Remove packages with apt-get. Requires root.
  --help    Show this help.

Default: --list
EOF
}

main() {
  case "${1:---list}" in
    --list)
      list_packages
      ;;
    --remove)
      remove_packages
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
