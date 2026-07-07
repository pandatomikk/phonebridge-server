#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

readonly REQUIRED_PACKAGES=(
  bluez
  bluetooth
  pipewire
  pipewire-pulse
  wireplumber
  ofono
  dbus
  jq
  usbutils
  pciutils
  rfkill
)

readonly OPTIONAL_PACKAGES=(
  bluez-tools
)

info() { printf 'INFO    %s\n' "$1"; }
ok() { printf 'OK      %s\n' "$1"; }
warning() { printf 'WARNING %s\n' "$1"; }
error() { printf 'ERROR   %s\n' "$1" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--list|--check|--install|--yes|--help]

Options:
  --list     List planned packages. No system changes.
  --check    Show missing required and optional packages. No system changes.
  --install  Install missing required packages with apt-get. Requires root.
  --yes      Allow --install on a non-target Debian-family OS.
  --help     Show this help.

The script does not modify configuration files.
Default: --list
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    error "installation requires root; re-run with sudo"
    return 1
  fi
}

package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

package_available() {
  apt-cache show "$1" >/dev/null 2>&1
}

supported_os() {
  [[ -r /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${VERSION_CODENAME:-}" in
    debian:trixie | debian:forky | raspbian:bookworm | raspberrypi:bookworm)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ensure_apt() {
  if ! have_command apt-get || ! have_command apt-cache || ! have_command dpkg-query; then
    error "apt-get, apt-cache, and dpkg-query are required; this installer targets Debian/Raspberry Pi OS"
    return 1
  fi
}

print_packages() {
  info "Required packages:"
  printf '  %s\n' "${REQUIRED_PACKAGES[@]}"
  info "Optional packages installed only if available:"
  printf '  %s\n' "${OPTIONAL_PACKAGES[@]}"
}

missing_required_packages() {
  local package_name
  for package_name in "${REQUIRED_PACKAGES[@]}"; do
    if ! package_installed "$package_name"; then
      printf '%s\n' "$package_name"
    fi
  done
}

available_optional_packages() {
  local package_name
  for package_name in "${OPTIONAL_PACKAGES[@]}"; do
    if package_available "$package_name"; then
      printf '%s\n' "$package_name"
    else
      warning "optional package '$package_name' is not available from current apt sources"
    fi
  done
}

check_packages() {
  ensure_apt
  local missing
  missing="$(missing_required_packages)"
  if [[ -z "$missing" ]]; then
    ok "all required packages are installed"
  else
    warning "missing required packages:"
    printf '%s\n' "$missing" | sed 's/^/  /'
  fi

  info "optional package availability:"
  available_optional_packages | sed 's/^/  available: /'
}

install_packages() {
  ensure_apt
  require_root

  local allow_unsupported="$1"
  if ! supported_os && [[ "$allow_unsupported" != "true" ]]; then
    error "unsupported OS target; use --yes with --install only if you accept this risk"
    return 1
  fi

  local missing
  missing="$(missing_required_packages)"
  if [[ -z "$missing" ]]; then
    ok "all required packages are already installed"
  else
    info "updating apt metadata"
    apt-get update
    info "installing missing required packages"
    # shellcheck disable=SC2086
    apt-get install -y $missing
  fi

  local optional
  optional="$(available_optional_packages || true)"
  if [[ -n "$optional" ]]; then
    info "installing available optional packages"
    # shellcheck disable=SC2086
    apt-get install -y $optional
  fi

  ok "installation step complete"
  info "no configuration files were modified"
  info "run ./server/check-system.sh next"
}

main() {
  local mode="--list"
  local allow_unsupported=false

  while (($# > 0)); do
    case "$1" in
      --list | --check | --install)
        mode="$1"
        shift
        ;;
      --yes)
        allow_unsupported=true
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

  case "$mode" in
    --list)
      print_packages
      ;;
    --check)
      check_packages
      ;;
    --install)
      install_packages "$allow_unsupported"
      ;;
  esac
}

main "$@"
