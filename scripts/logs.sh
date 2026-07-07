#!/usr/bin/env bash
set -euo pipefail

LINES="${LINES:-120}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--lines N|--help]

Print recent logs for Bluetooth, oFono, PipeWire, and WirePlumber.
Default line count: $LINES
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

print_logs() {
  local title="$1"
  shift

  printf '\n== %s ==\n' "$title"
  "$@" || printf 'WARN  could not read logs for %s\n' "$title"
}

main() {
  while (($# > 0)); do
    case "$1" in
      --lines)
        if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ ]]; then
          printf '--lines requires a positive integer\n' >&2
          return 2
        fi
        LINES="$2"
        shift 2
        ;;
      -h | --help)
        usage
        return 0
        ;;
      *)
        printf 'Unknown option: %s\n' "$1" >&2
        usage >&2
        return 2
        ;;
    esac
  done

  if ! have_command journalctl; then
    printf 'journalctl is required to read service logs.\n' >&2
    return 1
  fi

  print_logs "bluetooth.service" journalctl -u bluetooth.service -n "$LINES" --no-pager
  print_logs "ofono.service" journalctl -u ofono.service -n "$LINES" --no-pager
  print_logs "user pipewire.service" journalctl --user -u pipewire.service -n "$LINES" --no-pager
  print_logs "user wireplumber.service" journalctl --user -u wireplumber.service -n "$LINES" --no-pager
}

main "$@"
