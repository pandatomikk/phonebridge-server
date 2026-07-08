#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_PORT=4713
DEFAULT_ACL="127.0.0.1"
DEFAULT_RATE=16000
DEFAULT_CHANNELS=1
DEFAULT_LATENCY_MS=80
DEFAULT_UPLINK_LATENCY_MS=160
DEFAULT_RECORD_SECONDS=10
DEFAULT_UPLINK_VOLUME="100%"
DOWNLINK_SINK_NAME="phonebridge_network_downlink"
UPLINK_SOURCE_NAME="phonebridge_network_uplink"

info() { printf 'INFO    %s\n' "$1"; }
ok() { printf 'OK      %s\n' "$1"; }
warning() { printf 'WARNING %s\n' "$1"; }
error() { printf 'ERROR   %s\n' "$1" >&2; }
section() { printf '\n== %s ==\n' "$1"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--check|--listen|--connect-peer HOST|--serve-peer HOST|--route-call|--watch-route|--record-uplink FILE|--unload|--acl CIDR|--port PORT|--rate HZ|--channels N|--latency-ms MS|--uplink-latency-ms MS|--uplink-volume PERCENT|--remote-source NAME|--seconds N|--yes|--help]

Modes:
  --check              Inspect PipeWire/Pulse compatibility state. No changes. Default.
  --listen             Load a local Pulse-compatible TCP listener for a trusted LAN.
                       Run this on the PC that should receive/play audio or expose a mic.
  --connect-peer HOST  Load tunnel sink/source endpoints to a peer running --listen.
                       Run this on the Raspberry Pi.
  --serve-peer HOST    Ensure tunnel endpoints to a peer exist, then keep routing calls.
                       Intended for the systemd user service on the Raspberry Pi.
  --route-call         Move current active call streams to PhoneBridge tunnel endpoints.
                       Run this on the Raspberry Pi during an active HFP call.
  --watch-route        Keep running and route new Bluetooth call streams as they appear.
                       Run this on the Raspberry Pi after --connect-peer.
  --record-uplink FILE Record uplink audio received from the PC tunnel to a WAV file.
  --unload             Unload PhoneBridge network audio modules from this host.
  --acl CIDR           IP ACL for --listen. Example: 192.168.1.0/24. Default: $DEFAULT_ACL.
  --port PORT          Pulse-compatible TCP port. Default: $DEFAULT_PORT.
  --rate HZ            Tunnel sample rate. Default: $DEFAULT_RATE for HFP wideband speech.
  --channels N         Tunnel channel count. Default: $DEFAULT_CHANNELS for mono HFP audio.
  --latency-ms MS      Downlink tunnel target latency. Default: $DEFAULT_LATENCY_MS.
  --uplink-latency-ms MS
                       Uplink tunnel target latency. Default: $DEFAULT_UPLINK_LATENCY_MS.
  --uplink-volume PERCENT
                       Source volume for uplink tunnel. Default: $DEFAULT_UPLINK_VOLUME.
  --remote-source NAME Remote PC source name for uplink. Default: peer default source.
  --seconds N          Recording duration for --record-uplink. Default: $DEFAULT_RECORD_SECONDS.
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

require_parec() {
  if ! have_command parec; then
    error "parec is required; install pulseaudio-utils"
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

endpoint_exists() {
  local kind="$1"
  local name="$2"

  case "$kind" in
    sink)
      pactl list short sinks | awk '{print $2}' | grep -qx "$name"
      ;;
    source)
      pactl list short sources | awk '{print $2}' | grep -qx "$name"
      ;;
    *)
      return 2
      ;;
  esac
}

endpoint_id() {
  local kind="$1"
  local name="$2"

  case "$kind" in
    sink)
      pactl list short sinks | awk -v name="$name" '$2 == name {print $1; exit}'
      ;;
    source)
      pactl list short sources | awk -v name="$name" '$2 == name {print $1; exit}'
      ;;
    *)
      return 2
      ;;
  esac
}

set_uplink_volume() {
  local volume="$1"

  if endpoint_exists source "$UPLINK_SOURCE_NAME"; then
    pactl set-source-volume "$UPLINK_SOURCE_NAME" "$volume"
    ok "set $UPLINK_SOURCE_NAME volume to $volume"
  fi
}

sink_input_matches_call() {
  local stream_id="$1"
  pactl list sink-inputs |
    awk -v id="$stream_id" '
      $1 == "Sink" && $2 == "Input" && $3 == "#" id {in_block=1; found=0; next}
      $1 == "Sink" && $2 == "Input" && in_block {exit found ? 0 : 1}
      in_block && /bluez_input|bluez_output|bluez5/ {found=1}
      END {exit found ? 0 : 1}
    '
}

source_output_matches_call() {
  local stream_id="$1"
  pactl list source-outputs |
    awk -v id="$stream_id" '
      $1 == "Source" && $2 == "Output" && $3 == "#" id {in_block=1; found=0; next}
      $1 == "Source" && $2 == "Output" && in_block {exit found ? 0 : 1}
      in_block && /bluez_input|bluez_output|bluez5/ {found=1}
      END {exit found ? 0 : 1}
    '
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
  local rate="$3"
  local channels="$4"
  local downlink_latency_ms="$5"
  local uplink_latency_ms="$6"
  local uplink_volume="$7"
  local remote_source="$8"
  local assume_yes="$9"

  section "Connect network audio peer"
  require_pactl
  confirm_apply "$assume_yes" "This will create local tunnel endpoints to tcp:$peer:$port."

  local sink_module source_module
  sink_module="$(pactl load-module module-tunnel-sink "server=tcp:$peer:$port" "sink_name=$DOWNLINK_SINK_NAME" "format=s16le" "rate=$rate" "channels=$channels" "latency_msec=$downlink_latency_ms" "sink_properties=device.description=PhoneBridge_Network_Downlink")"
  ok "loaded downlink tunnel sink '$DOWNLINK_SINK_NAME' as module $sink_module"

  local source_args=("server=tcp:$peer:$port" "source_name=$UPLINK_SOURCE_NAME" "format=s16le" "rate=$rate" "channels=$channels" "latency_msec=$uplink_latency_ms" "source_properties=device.description=PhoneBridge_Network_Uplink")
  if [[ -n "$remote_source" ]]; then
    source_args+=("source=$remote_source")
  fi
  source_module="$(pactl load-module module-tunnel-source "${source_args[@]}")"
  ok "loaded uplink tunnel source '$UPLINK_SOURCE_NAME' as module $source_module"
  set_uplink_volume "$uplink_volume"

  info "next routing step: use wpctl/pavucontrol/helvum to route Android call downlink to $DOWNLINK_SINK_NAME and $UPLINK_SOURCE_NAME back into the HFP uplink"
  check_audio
}

ensure_peer_connected() {
  local peer="$1"
  local port="$2"
  local rate="$3"
  local channels="$4"
  local downlink_latency_ms="$5"
  local uplink_latency_ms="$6"
  local uplink_volume="$7"
  local remote_source="$8"

  section "Ensure network audio peer"
  require_pactl

  local sink_module source_module
  if endpoint_exists sink "$DOWNLINK_SINK_NAME"; then
    ok "downlink sink '$DOWNLINK_SINK_NAME' already exists"
  else
    sink_module="$(pactl load-module module-tunnel-sink "server=tcp:$peer:$port" "sink_name=$DOWNLINK_SINK_NAME" "format=s16le" "rate=$rate" "channels=$channels" "latency_msec=$downlink_latency_ms" "sink_properties=device.description=PhoneBridge_Network_Downlink")"
    ok "loaded downlink tunnel sink '$DOWNLINK_SINK_NAME' as module $sink_module"
  fi

  if endpoint_exists source "$UPLINK_SOURCE_NAME"; then
    ok "uplink source '$UPLINK_SOURCE_NAME' already exists"
  else
    local source_args=("server=tcp:$peer:$port" "source_name=$UPLINK_SOURCE_NAME" "format=s16le" "rate=$rate" "channels=$channels" "latency_msec=$uplink_latency_ms" "source_properties=device.description=PhoneBridge_Network_Uplink")
    if [[ -n "$remote_source" ]]; then
      source_args+=("source=$remote_source")
    fi
    source_module="$(pactl load-module module-tunnel-source "${source_args[@]}")"
    ok "loaded uplink tunnel source '$UPLINK_SOURCE_NAME' as module $source_module"
  fi
  set_uplink_volume "$uplink_volume"
}

route_active_call() {
  local assume_yes="$1"
  local show_summary="${2:-true}"

  if [[ "$show_summary" == "true" ]]; then
    section "Route active call"
  fi
  require_pactl
  if [[ "$show_summary" == "true" ]]; then
    confirm_apply "$assume_yes" "This will move current Bluetooth call streams to $DOWNLINK_SINK_NAME and $UPLINK_SOURCE_NAME."
  fi

  if ! endpoint_exists sink "$DOWNLINK_SINK_NAME"; then
    error "sink '$DOWNLINK_SINK_NAME' was not found; run --connect-peer first"
    return 1
  fi
  if ! endpoint_exists source "$UPLINK_SOURCE_NAME"; then
    error "source '$UPLINK_SOURCE_NAME' was not found; run --connect-peer first"
    return 1
  fi

  local sink_inputs source_outputs stream_id target_sink_id target_source_id current_target_id
  target_sink_id="$(endpoint_id sink "$DOWNLINK_SINK_NAME")"
  target_source_id="$(endpoint_id source "$UPLINK_SOURCE_NAME")"
  sink_inputs="$(pactl list short sink-inputs)"
  source_outputs="$(pactl list short source-outputs)"

  if [[ -z "$sink_inputs" ]]; then
    if [[ "$show_summary" == "true" ]]; then
      warning "no sink-inputs found; start an active call first"
    fi
  else
    while IFS=$'\t' read -r stream_id current_target_id _; do
      [[ -n "$stream_id" ]] || continue
      if [[ "$current_target_id" == "$target_sink_id" ]]; then
        continue
      fi
      if ! sink_input_matches_call "$stream_id"; then
        continue
      fi
      pactl move-sink-input "$stream_id" "$DOWNLINK_SINK_NAME"
      ok "moved sink-input $stream_id to $DOWNLINK_SINK_NAME"
    done <<<"$sink_inputs"
  fi

  if [[ -z "$source_outputs" ]]; then
    if [[ "$show_summary" == "true" ]]; then
      warning "no source-outputs found; start an active call first"
    fi
  else
    while IFS=$'\t' read -r stream_id current_target_id _; do
      [[ -n "$stream_id" ]] || continue
      if [[ "$current_target_id" == "$target_source_id" ]]; then
        continue
      fi
      if ! source_output_matches_call "$stream_id"; then
        continue
      fi
      pactl move-source-output "$stream_id" "$UPLINK_SOURCE_NAME"
      ok "moved source-output $stream_id to $UPLINK_SOURCE_NAME"
    done <<<"$source_outputs"
  fi

  if [[ "$show_summary" == "true" ]]; then
    check_audio
  fi
}

watch_route() {
  local assume_yes="$1"

  section "Watch and route calls"
  require_pactl
  confirm_apply "$assume_yes" "This will keep running and route Bluetooth call streams to PhoneBridge network endpoints."

  if ! endpoint_exists sink "$DOWNLINK_SINK_NAME"; then
    error "sink '$DOWNLINK_SINK_NAME' was not found; run --connect-peer first"
    return 1
  fi
  if ! endpoint_exists source "$UPLINK_SOURCE_NAME"; then
    error "source '$UPLINK_SOURCE_NAME' was not found; run --connect-peer first"
    return 1
  fi

  ok "watching for Bluetooth call streams; press Ctrl+C to stop"
  while true; do
    route_active_call true false || true
    sleep 2
  done
}

record_uplink() {
  local output_file="$1"
  local seconds="$2"
  local rate="$3"
  local channels="$4"

  section "Record network uplink"
  require_pactl
  require_parec

  if ! endpoint_exists source "$UPLINK_SOURCE_NAME"; then
    error "source '$UPLINK_SOURCE_NAME' was not found; run --connect-peer first"
    return 1
  fi

  info "recording $seconds seconds from $UPLINK_SOURCE_NAME to $output_file"
  info "speak into the PC microphone now"
  parec --device="$UPLINK_SOURCE_NAME" --file-format=wav --format=s16le --rate="$rate" --channels="$channels" "$output_file" &
  local record_pid="$!"
  sleep "$seconds"
  kill "$record_pid" >/dev/null 2>&1 || true
  wait "$record_pid" >/dev/null 2>&1 || true
  ok "wrote $output_file"
}

serve_peer() {
  local peer="$1"
  local port="$2"
  local rate="$3"
  local channels="$4"
  local downlink_latency_ms="$5"
  local uplink_latency_ms="$6"
  local uplink_volume="$7"
  local remote_source="$8"

  ensure_peer_connected "$peer" "$port" "$rate" "$channels" "$downlink_latency_ms" "$uplink_latency_ms" "$uplink_volume" "$remote_source"
  watch_route true
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
  local rate="$DEFAULT_RATE"
  local channels="$DEFAULT_CHANNELS"
  local downlink_latency_ms="$DEFAULT_LATENCY_MS"
  local uplink_latency_ms="$DEFAULT_UPLINK_LATENCY_MS"
  local uplink_volume="$DEFAULT_UPLINK_VOLUME"
  local remote_source=""
  local record_file=""
  local record_seconds="$DEFAULT_RECORD_SECONDS"
  local assume_yes=false

  while (($# > 0)); do
    case "$1" in
      --check | --listen | --route-call | --watch-route | --unload)
        mode="$1"
        shift
        ;;
      --record-uplink)
        mode="--record-uplink"
        record_file="${2:-}"
        if [[ -z "$record_file" ]]; then
          error "--record-uplink requires an output file"
          return 2
        fi
        shift 2
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
      --serve-peer)
        mode="--serve-peer"
        peer="${2:-}"
        if [[ -z "$peer" ]]; then
          error "--serve-peer requires a host or IP"
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
        downlink_latency_ms="${2:-}"
        if [[ ! "$downlink_latency_ms" =~ ^[0-9]+$ ]]; then
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
      --uplink-volume)
        uplink_volume="${2:-}"
        if [[ ! "$uplink_volume" =~ ^[0-9]+%?$ ]]; then
          error "--uplink-volume requires a numeric percentage such as 125%"
          return 2
        fi
        [[ "$uplink_volume" == *% ]] || uplink_volume="${uplink_volume}%"
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
      --seconds)
        record_seconds="${2:-}"
        if [[ ! "$record_seconds" =~ ^[0-9]+$ ]]; then
          error "--seconds requires a numeric value"
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
      connect_peer "$peer" "$port" "$rate" "$channels" "$downlink_latency_ms" "$uplink_latency_ms" "$uplink_volume" "$remote_source" "$assume_yes"
      ;;
    --serve-peer)
      serve_peer "$peer" "$port" "$rate" "$channels" "$downlink_latency_ms" "$uplink_latency_ms" "$uplink_volume" "$remote_source"
      ;;
    --route-call)
      route_active_call "$assume_yes"
      ;;
    --watch-route)
      watch_route "$assume_yes"
      ;;
    --record-uplink)
      record_uplink "$record_file" "$record_seconds" "$rate" "$channels"
      ;;
    --unload)
      unload_phonebridge_modules "$assume_yes"
      ;;
  esac
}

main "$@"
