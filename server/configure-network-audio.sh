#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_PORT=4713
DEFAULT_ACL="127.0.0.1"
DOWNLINK_SINK_NAME="phonebridge_network_downlink"
UPLINK_SOURCE_NAME="phonebridge_network_uplink"

info() { printf 'INFO    %s\n' "$1"; }
ok() { printf 'OK      %s\n' "$1"; }
warning() { printf 'WARNING %s\n' "$1"; }
error() { printf 'ERROR   %s\n' "$1" >&2; }
section() { printf '\n== %s ==\n' "$1"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--check|--listen|--connect-peer HOST|--unload|--acl CIDR|--port PORT|--yes|--help]

Modes:
  --check              Inspect PipeWire/Pulse compatibility state. No changes. Default.
  --listen             Load a local Pulse-compatible TCP listener for a trusted LAN.
                       Run this on the PC that should receive/play audio or expose a mic.
  --connect-peer HOST  Load tunnel sink/source endpoints to a peer running --listen.
                       Run this on the Raspberry Pi.
  --unload             Unload PhoneBridge network audio modules from this host.
  --acl CIDR           IP ACL for --listen. Example: 192.168.1.0/24. Default: $DEFAULT_ACL.
  --port PORT          Pulse-compatible TCP port. Default: $DEFAULT_PORT.
  --yes                Skip interactive confirmation for modes that change PipeWire state.
  --help               Show this help.

This script uses PipeWire's PulseAudio compatibility layer through pactl. It does not create
permanent PipeWire/WirePlumber configuration files.
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

require_pactl() {
  if ! have_command pactl; then
    error "pactl is required; install pulseaudio-utils"
    return 1
  fi
  if ! pactl info >/dev/null 2>&1; then
    error "pactl cannot reach the PipeWire/Pulse server for this user"
    return 1
  fi
}

confirm_apply() {
  local assume_yes="$1"
  local message="$2"
  if [[ "$assume_yes" == "true" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    error "this mode requires confirmation; re-run with --yes if intentional"
    return 1
  fi
  printf '%s Continue? [y/N] ' "$message"
  local answer
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

check_audio() {
  section "Network audio check"
  require_pactl

  info "Pulse-compatible server:"
  pactl info 2>/dev/null | sed 's/^/INFO    /'

  info "loaded PhoneBridge modules:"
  if pactl list short modules | grep -E "phonebridge|module-native-protocol-tcp|module-tunnel-(sink|source)" >/dev/null 2>&1; then
    pactl list short modules | grep -E "phonebridge|module-native-protocol-tcp|module-tunnel-(sink|source)" | sed 's/^/INFO    /'
  else
    info "no PhoneBridge/tunnel TCP modules detected"
  fi

  info "sinks:"
  pactl list short sinks 2>/dev/null | sed 's/^/INFO    /' || true
  info "sources:"
  pactl list short sources 2>/dev/null | sed 's/^/INFO    /' || true
}

load_listener() {
  local acl="$1"
  local port="$2"
  local assume_yes="$3"

  section "Load network audio listener"
  require_pactl
  confirm_apply "$assume_yes" "This will expose this user's PipeWire/Pulse server on TCP port $port for ACL $acl."

  local module_id
  module_id="$(pactl load-module module-native-protocol-tcp "port=$port" "auth-ip-acl=$acl" "auth-anonymous=1")"
  ok "loaded module-native-protocol-tcp as module $module_id"
  warning "TCP audio is intended for a trusted LAN only; restrict --acl to the peer subnet or host"
  check_audio
}

connect_peer() {
  local peer="$1"
  local port="$2"
  local assume_yes="$3"

  section "Connect network audio peer"
  require_pactl
  confirm_apply "$assume_yes" "This will create local tunnel endpoints to tcp:$peer:$port."

  local sink_module source_module
  sink_module="$(pactl load-module module-tunnel-sink "server=tcp:$peer:$port" "sink_name=$DOWNLINK_SINK_NAME" "sink_properties=device.description=PhoneBridge_Network_Downlink")"
  ok "loaded downlink tunnel sink '$DOWNLINK_SINK_NAME' as module $sink_module"

  source_module="$(pactl load-module module-tunnel-source "server=tcp:$peer:$port" "source_name=$UPLINK_SOURCE_NAME" "source_properties=device.description=PhoneBridge_Network_Uplink")"
  ok "loaded uplink tunnel source '$UPLINK_SOURCE_NAME' as module $source_module"

  info "next routing step: use wpctl/pavucontrol/helvum to route Android call downlink to $DOWNLINK_SINK_NAME and $UPLINK_SOURCE_NAME back into the HFP uplink"
  check_audio
}

unload_phonebridge_modules() {
  local assume_yes="$1"

  section "Unload PhoneBridge network audio modules"
  require_pactl
  confirm_apply "$assume_yes" "This will unload modules whose arguments contain phonebridge_network."

  local ids
  ids="$(pactl list short modules | awk '/phonebridge_network/ {print $1}')"
  if [[ -z "$ids" ]]; then
    warning "no phonebridge_network modules found"
    return 0
  fi

  local module_id
  while IFS= read -r module_id; do
    [[ -n "$module_id" ]] || continue
    pactl unload-module "$module_id"
    ok "unloaded module $module_id"
  done <<<"$ids"
}

main() {
  local mode="--check"
  local peer=""
  local acl="$DEFAULT_ACL"
  local port="$DEFAULT_PORT"
  local assume_yes=false

  while (($# > 0)); do
    case "$1" in
      --check | --listen | --unload)
        mode="$1"
        shift
        ;;
      --connect-peer)
        mode="--connect-peer"
        peer="${2:-}"
        if [[ -z "$peer" ]]; then
          error "--connect-peer requires a host or IP"
          return 2
        fi
        shift 2
        ;;
      --acl)
        acl="${2:-}"
        if [[ -z "$acl" ]]; then
          error "--acl requires a CIDR or host"
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
      --yes)
        assume_yes=true
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
    --check)
      check_audio
      ;;
    --listen)
      load_listener "$acl" "$port" "$assume_yes"
      ;;
    --connect-peer)
      connect_peer "$peer" "$port" "$assume_yes"
      ;;
    --unload)
      unload_phonebridge_modules "$assume_yes"
      ;;
  esac
}

main "$@"
