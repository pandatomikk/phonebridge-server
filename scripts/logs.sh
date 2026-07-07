#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SINCE="10 min ago"
FOLLOW=false

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--since TIME] [--follow] [--help]

Options:
  --since TIME  journalctl time expression. Default: "$SINCE"
  --follow      Follow logs after printing existing entries.
  --help        Show this help.

Examples:
  $SCRIPT_NAME --since "10 min ago"
  $SCRIPT_NAME --since today --follow
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

section() {
  printf '\n== %s ==\n' "$1"
}

journal_args() {
  local args=(--since "$SINCE" --no-pager -q)
  if [[ "$FOLLOW" == true ]]; then
    args+=(--follow)
  fi
  printf '%s\0' "${args[@]}"
}

print_journal() {
  local title="$1"
  shift
  section "$title"
  if ! have_command journalctl; then
    printf 'WARNING journalctl is unavailable\n'
    return
  fi

  local -a args
  mapfile -d '' -t args < <(journal_args)
  journalctl "$@" "${args[@]}" || printf 'WARNING could not read %s logs\n' "$title"
}

print_dmesg_bluetooth() {
  section "dmesg Bluetooth"
  if ! have_command dmesg; then
    printf 'WARNING dmesg is unavailable\n'
    return
  fi
  dmesg --ctime 2>/dev/null | grep -Ei 'bluetooth|btusb|hci|sco|rfkill' || printf 'INFO no Bluetooth dmesg lines found\n'
}

follow_journals() {
  section "following system and user journals"
  if ! have_command journalctl; then
    printf 'WARNING journalctl is unavailable\n'
    return 1
  fi

  printf 'INFO press Ctrl-C to stop following logs\n'
  journalctl -q --since "$SINCE" --follow -u bluetooth.service -u ofono.service &
  local system_pid=$!
  journalctl -q --user --since "$SINCE" --follow \
    -u pipewire.service \
    -u pipewire-pulse.service \
    -u wireplumber.service &
  local user_pid=$!

  wait "$system_pid" "$user_pid" || true
}

main() {
  while (($# > 0)); do
    case "$1" in
      --since)
        if [[ -z "${2:-}" ]]; then
          printf '--since requires a value\n' >&2
          return 2
        fi
        SINCE="$2"
        shift 2
        ;;
      --follow)
        FOLLOW=true
        shift
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

  local follow_requested="$FOLLOW"
  FOLLOW=false
  print_journal "bluetooth.service" -u bluetooth.service
  print_journal "ofono.service" -u ofono.service
  print_journal "user pipewire.service" --user -u pipewire.service
  print_journal "user pipewire-pulse.service" --user -u pipewire-pulse.service
  print_journal "user wireplumber.service" --user -u wireplumber.service
  print_dmesg_bluetooth

  if [[ "$follow_requested" == true ]]; then
    follow_journals
  fi
}

main "$@"
