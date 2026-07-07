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

user_bus_available() {
  have_command busctl && busctl --user list >/dev/null 2>&1
}

inspect_pipewire() {
  log "Inspecting PipeWire/WirePlumber state..."

  if have_command systemctl; then
    if systemctl --user is-active --quiet pipewire.service 2>/dev/null; then
      ok "user pipewire.service is active"
    else
      warn "user pipewire.service is not active"
    fi

    if systemctl --user is-active --quiet wireplumber.service 2>/dev/null; then
      ok "user wireplumber.service is active"
    else
      warn "user wireplumber.service is not active"
    fi
  else
    warn "systemctl is missing"
  fi

  if have_command wpctl; then
    if user_bus_available; then
      wpctl status || warn "wpctl status failed"
    else
      warn "user D-Bus is not reachable; skipping wpctl status"
    fi
  else
    warn "wpctl is missing"
  fi
}

apply_configuration() {
  log "No PipeWire or WirePlumber configuration is applied in v0.1."
  log "Future versions will add explicit local audio routing helpers."
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--apply|--help]

Without --apply, inspect PipeWire/WirePlumber state only.
--apply is accepted for future compatibility, but v0.1 does not modify audio settings.
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

  inspect_pipewire

  if [[ "$APPLY" == true ]]; then
    apply_configuration
  else
    log "Dry run only. Use --apply when a future version provides safe configuration changes."
  fi
}

main "$@"
