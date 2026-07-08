#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME="phonebridge-network-audio.service"
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
PROJECT_CONFIG_DIR="${HOME}/.config/phonebridge-server"
SERVICE_TEMPLATE="$ROOT_DIR/systemd/$SERVICE_NAME.in"
SERVICE_FILE="$USER_SYSTEMD_DIR/$SERVICE_NAME"
ENV_FILE="$PROJECT_CONFIG_DIR/network-audio.env"

info() { printf 'INFO    %s\n' "$1"; }
ok() { printf 'OK      %s\n' "$1"; }
warning() { printf 'WARNING %s\n' "$1"; }
error() { printf 'ERROR   %s\n' "$1" >&2; }
section() { printf '\n== %s ==\n' "$1"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME --peer HOST [--port PORT] [--rate HZ] [--channels N] [--latency-ms MS] [--uplink-latency-ms MS] [--remote-source NAME] [--enable] [--start] [--status]
       $SCRIPT_NAME --status
       $SCRIPT_NAME --uninstall

Options:
  --peer HOST   PC host/IP running the PhoneBridge network audio listener.
  --port PORT   Listener port. Default: 4713.
  --rate HZ     Tunnel sample rate. Default: 16000.
  --channels N  Tunnel channel count. Default: 1.
  --latency-ms MS
                Downlink tunnel target latency. Default: 80.
  --uplink-latency-ms MS
                Uplink tunnel target latency. Default: 160.
  --remote-source NAME
                PC source name to use for uplink. Default: PC default source.
  --enable      Enable the user service at login.
  --start       Start or restart the user service now.
  --status      Show user service status after changes.
  --uninstall   Disable and remove the installed user service file.
  --help        Show this help.

This installs a systemd user service for the current user. It does not require root.
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

require_systemctl() {
  if ! have_command systemctl; then
    error "systemctl is required"
    return 1
  fi
}

install_service() {
  local peer="$1"
  local port="$2"
  local rate="$3"
  local channels="$4"
  local latency_ms="$5"
  local uplink_latency_ms="$6"
  local remote_source="$7"

  section "Install network audio user service"
  require_systemctl

  if [[ ! -f "$SERVICE_TEMPLATE" ]]; then
    error "service template not found: $SERVICE_TEMPLATE"
    return 1
  fi

  local remote_source_args=""
  if [[ -n "$remote_source" ]]; then
    remote_source_args="--remote-source $remote_source"
  fi

  mkdir -p "$USER_SYSTEMD_DIR" "$PROJECT_CONFIG_DIR"
  sed \
    -e "s|@PROJECT_DIR@|$ROOT_DIR|g" \
    -e "s|@REMOTE_SOURCE_ARGS@|$remote_source_args|g" \
    "$SERVICE_TEMPLATE" >"$SERVICE_FILE"
  {
    printf 'PHONEBRIDGE_PEER_HOST=%q\n' "$peer"
    printf 'PHONEBRIDGE_PORT=%q\n' "$port"
    printf 'PHONEBRIDGE_RATE=%q\n' "$rate"
    printf 'PHONEBRIDGE_CHANNELS=%q\n' "$channels"
    printf 'PHONEBRIDGE_LATENCY_MS=%q\n' "$latency_ms"
    printf 'PHONEBRIDGE_UPLINK_LATENCY_MS=%q\n' "$uplink_latency_ms"
  } >"$ENV_FILE"

  ok "installed $SERVICE_FILE"
  ok "wrote $ENV_FILE"
  systemctl --user daemon-reload
  ok "reloaded user systemd"
}

enable_service() {
  section "Enable network audio user service"
  require_systemctl
  systemctl --user enable "$SERVICE_NAME"
  ok "enabled $SERVICE_NAME"
}

start_service() {
  section "Start network audio user service"
  require_systemctl
  systemctl --user restart "$SERVICE_NAME"
  ok "restarted $SERVICE_NAME"
}

status_service() {
  section "Network audio user service status"
  require_systemctl
  systemctl --user status "$SERVICE_NAME" --no-pager || true
}

uninstall_service() {
  section "Uninstall network audio user service"
  require_systemctl
  systemctl --user disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE"
  systemctl --user daemon-reload
  ok "removed $SERVICE_FILE"
  info "kept config file: $ENV_FILE"
}

main() {
  local peer=""
  local port="4713"
  local rate="16000"
  local channels="1"
  local latency_ms="80"
  local uplink_latency_ms="160"
  local remote_source=""
  local do_enable=false
  local do_start=false
  local do_status=false
  local do_uninstall=false

  while (($# > 0)); do
    case "$1" in
      --peer)
        peer="${2:-}"
        if [[ -z "$peer" ]]; then
          error "--peer requires a host or IP"
          return 2
        fi
        shift 2
        ;;
      --port)
        port="${2:-}"
        if [[ ! "$port" =~ ^[0-9]+$ ]]; then
          error "--port requires a numeric port"
          return 2
        fi
        shift 2
        ;;
      --rate)
        rate="${2:-}"
        if [[ ! "$rate" =~ ^[0-9]+$ ]]; then
          error "--rate requires a numeric sample rate"
          return 2
        fi
        shift 2
        ;;
      --channels)
        channels="${2:-}"
        if [[ ! "$channels" =~ ^[0-9]+$ ]]; then
          error "--channels requires a numeric channel count"
          return 2
        fi
        shift 2
        ;;
      --latency-ms)
        latency_ms="${2:-}"
        if [[ ! "$latency_ms" =~ ^[0-9]+$ ]]; then
          error "--latency-ms requires a numeric value"
          return 2
        fi
        shift 2
        ;;
      --uplink-latency-ms)
        uplink_latency_ms="${2:-}"
        if [[ ! "$uplink_latency_ms" =~ ^[0-9]+$ ]]; then
          error "--uplink-latency-ms requires a numeric value"
          return 2
        fi
        shift 2
        ;;
      --remote-source)
        remote_source="${2:-}"
        if [[ -z "$remote_source" ]]; then
          error "--remote-source requires a source name"
          return 2
        fi
        shift 2
        ;;
      --enable)
        do_enable=true
        shift
        ;;
      --start)
        do_start=true
        shift
        ;;
      --status)
        do_status=true
        shift
        ;;
      --uninstall)
        do_uninstall=true
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

  if [[ "$do_uninstall" == "true" ]]; then
    uninstall_service
    return 0
  fi

  if [[ -n "$peer" ]]; then
    install_service "$peer" "$port" "$rate" "$channels" "$latency_ms" "$uplink_latency_ms" "$remote_source"
  elif [[ "$do_status" != "true" ]]; then
    error "--peer is required unless using --status or --uninstall"
    usage >&2
    return 2
  fi

  if [[ "$do_enable" == "true" ]]; then
    enable_service
  fi
  if [[ "$do_start" == "true" ]]; then
    start_service
  fi
  if [[ "$do_status" == "true" ]]; then
    status_service
  fi
}

main "$@"
