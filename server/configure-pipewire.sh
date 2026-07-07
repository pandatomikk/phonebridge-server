#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_CONFIG_DIR="${HOME}/.config/phonebridge-server"
PROJECT_CONFIG_LABEL="~/.config/phonebridge-server"

info() { printf 'INFO    %s\n' "$1"; }
ok() { printf 'OK      %s\n' "$1"; }
warning() { printf 'WARNING %s\n' "$1"; }
error() { printf 'ERROR   %s\n' "$1" >&2; }
section() { printf '\n== %s ==\n' "$1"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--check|--apply|--help]

Modes:
  --check   Inspect PipeWire/WirePlumber state. No system changes. Default.
  --apply   Enable/start user PipeWire services where possible and create a disabled
            project notes directory at $PROJECT_CONFIG_LABEL.
  --help    Show this help.

This script does not overwrite PipeWire or WirePlumber configuration.
EOF
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

user_bus_available() {
  have_command busctl && busctl --user list >/dev/null 2>&1
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

show_nodes() {
  if have_command wpctl; then
    info "wpctl status:"
    wpctl status 2>/dev/null | sed -n '1,160p' | sed 's/^/INFO    /' || warning "wpctl status failed"
  else
    warning "wpctl is missing"
  fi

  if have_command pw-cli; then
    info "PipeWire nodes:"
    pw-cli ls Node 2>/dev/null | sed -n '1,120p' | sed 's/^/INFO    /' || warning "pw-cli ls Node failed"
  else
    warning "pw-cli is missing"
  fi

  if have_command pactl; then
    info "PulseAudio-compatible PipeWire server info:"
    pactl info 2>/dev/null | sed 's/^/INFO    /' || warning "pactl info failed"
  else
    warning "pactl is missing; install pipewire-pulse for compatibility diagnostics"
  fi
}

check_bluetooth_modules() {
  local found=0
  for dir in /usr/lib/pipewire-0.3 /usr/lib/*/pipewire-0.3 /usr/share/pipewire /usr/share/wireplumber; do
    if [[ -d "$dir" ]] && find "$dir" -iname '*bluez*' -o -iname '*bluetooth*' 2>/dev/null | grep -q .; then
      info "Bluetooth-related PipeWire/WirePlumber files found under $dir"
      found=1
    fi
  done
  if ((found == 0)); then
    warning "Bluetooth-related PipeWire/WirePlumber modules were not detected in standard paths"
  fi
}

check_pipewire() {
  section "PipeWire check"

  for command_name in pipewire pw-cli wpctl wireplumber; do
    if have_command "$command_name"; then
      ok "command '$command_name' found"
    else
      warning "command '$command_name' missing"
    fi
  done

  if have_command systemctl; then
    for service in pipewire.service pipewire-pulse.service wireplumber.service; do
      if systemctl --user is-active --quiet "$service" 2>/dev/null; then
        ok "user $service is active"
      else
        warning "user $service is not active"
      fi
    done
  else
    warning "systemctl is missing"
  fi

  show_nodes
  check_bluetooth_modules
}

apply_pipewire() {
  section "PipeWire apply"

  if have_command systemctl && user_bus_available; then
    run_or_warn "enabled user pipewire.service" systemctl --user enable pipewire.service
    run_or_warn "started user pipewire.service" systemctl --user start pipewire.service
    run_or_warn "enabled user pipewire-pulse.service" systemctl --user enable pipewire-pulse.service
    run_or_warn "started user pipewire-pulse.service" systemctl --user start pipewire-pulse.service
    run_or_warn "enabled user wireplumber.service" systemctl --user enable wireplumber.service
    run_or_warn "started user wireplumber.service" systemctl --user start wireplumber.service
  else
    warning "user systemd/D-Bus is unavailable; cannot start user PipeWire services"
  fi

  mkdir -p "$PROJECT_CONFIG_DIR"
  if [[ ! -f "$PROJECT_CONFIG_DIR/README.md" ]]; then
    cat >"$PROJECT_CONFIG_DIR/README.md" <<'EOF'
# PhoneBridge local configuration notes

This directory is reserved for future disabled-by-default PipeWire/WirePlumber snippets.
No active audio routing is installed by v0.1.
EOF
    ok "created disabled project config notes at $PROJECT_CONFIG_DIR/README.md"
  else
    ok "project config notes already exist"
  fi

  info "manual next steps: inspect wpctl status, confirm Bluetooth HFP nodes during a real call"
  show_nodes
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
    apply_pipewire
  else
    check_pipewire
  fi
}

main "$@"
