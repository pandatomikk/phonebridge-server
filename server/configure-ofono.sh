#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

info() { printf 'INFO    %s\n' "$1"; }
ok() { printf 'OK      %s\n' "$1"; }
warning() { printf 'WARNING %s\n' "$1"; }
error() { printf 'ERROR   %s\n' "$1" >&2; }
section() { printf '\n== %s ==\n' "$1"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--check|--apply|--help]

Modes:
  --check   Inspect oFono service, D-Bus objects, and recent logs. No changes. Default.
  --apply   Enable and start ofono.service. No configuration files are changed.
  --help    Show this help.
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

system_bus_available() {
  have_command busctl && busctl --system list >/dev/null 2>&1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    error "--apply needs root to enable/start ofono.service"
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

show_ofono_objects() {
  if system_bus_available && busctl --system list 2>/dev/null | grep -q 'org.ofono'; then
    ok "org.ofono is visible on system D-Bus"
    info "oFono object tree:"
    busctl --system tree org.ofono 2>/dev/null | sed -n '1,120p' | sed 's/^/INFO    /' || true
  else
    warning "org.ofono is not visible on system D-Bus"
  fi
}

show_recent_logs() {
  if have_command journalctl; then
    info "recent ofono.service logs:"
    journalctl -u ofono.service -n 80 --no-pager 2>/dev/null | sed 's/^/INFO    /' || warning "could not read ofono logs"
  else
    warning "journalctl is missing"
  fi
}

check_ofono() {
  section "oFono check"

  if have_command ofonod; then
    ok "ofonod command found"
  else
    warning "ofonod command missing"
  fi

  if have_command systemctl && systemctl is-active --quiet ofono.service 2>/dev/null; then
    ok "ofono.service is active"
  else
    warning "ofono.service is not active"
  fi

  show_ofono_objects
  show_recent_logs
}

apply_ofono() {
  section "oFono apply"
  require_root

  if ! have_command systemctl; then
    error "systemctl is required"
    return 1
  fi

  run_or_warn "enabled ofono.service" systemctl enable ofono.service
  run_or_warn "started ofono.service" systemctl start ofono.service
  info "no oFono configuration files were modified"
  info "next step: pair Android and inspect org.ofono objects during HFP connection"
  show_ofono_objects
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
    apply_ofono
  else
    check_ofono
  fi
}

main "$@"
