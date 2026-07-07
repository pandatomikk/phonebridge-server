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

inspect_ofono() {
  log "Inspecting oFono state..."

  if have_command systemctl && systemctl is-active --quiet ofono.service 2>/dev/null; then
    ok "ofono.service is active"
  else
    warn "ofono.service is not active"
  fi

  if have_command busctl; then
    if busctl --system list 2>/dev/null | grep -q 'org.ofono'; then
      ok "org.ofono is visible on the system D-Bus"
    else
      warn "org.ofono is not visible on the system D-Bus"
    fi
  else
    warn "busctl is missing"
  fi
}

apply_configuration() {
  log "No oFono configuration is applied in v0.1."
  log "Future versions will add guarded HFP/HSP integration settings after validation."
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--apply|--help]

Without --apply, inspect oFono state only.
--apply is accepted for future compatibility, but v0.1 does not modify oFono settings.
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

  inspect_ofono

  if [[ "$APPLY" == true ]]; then
    apply_configuration
  else
    log "Dry run only. Use --apply when a future version provides safe configuration changes."
  fi
}

main "$@"
