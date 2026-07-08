# Server Scripts

The scripts in this directory are standalone Bash helpers for installation, diagnostics, and
future guarded configuration.

All scripts use `set -euo pipefail` and should be safe to run independently.

## Scripts

```text
install.sh              List, check, or install target Debian packages
uninstall.sh            List packages and provide an explicit uninstall path
check-system.sh         Run the v0.1 diagnostic checks
configure-bluetooth.sh  Inspect or later configure BlueZ behavior
pair-phone.sh           Temporary discoverable mode and Android pairing helper
configure-pipewire.sh   Inspect or later configure PipeWire/WirePlumber behavior
configure-ofono.sh      Inspect or later configure oFono behavior
configure-network-audio.sh  Temporary PipeWire/Pulse TCP tunnel helpers
install-network-audio-service.sh  Install the network audio routing user service
```

## Conservative Defaults

Configuration scripts inspect the system by default. They do not modify system configuration
unless an explicit `--apply` flag is provided.

The v0.1 `--apply` path is intentionally limited and mostly reports what is not implemented yet.
This keeps the project from enabling unsafe Bluetooth behavior before the required settings are
well understood.

`--apply` commands require confirmation. Use `--yes` only for deliberate automation.

## Common Commands

```bash
./server/check-system.sh
./server/install.sh --list
./server/install.sh --check
sudo ./server/install.sh --install
./server/configure-bluetooth.sh --check
./server/pair-phone.sh --check
./server/pair-phone.sh --discoverable
./server/pair-phone.sh --trust
./server/configure-pipewire.sh --check
./server/configure-ofono.sh --check
./server/configure-network-audio.sh --check
./server/install-network-audio-service.sh --status
./scripts/logs.sh --since "10 min ago" --lines 120
```
