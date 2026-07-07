# Server Scripts

The scripts in this directory are standalone Bash helpers for installation, diagnostics, and
future guarded configuration.

All scripts use `set -euo pipefail` and should be safe to run independently.

## Scripts

```text
install.sh              List or install target Debian packages
uninstall.sh            List packages and provide an explicit uninstall path
check-system.sh         Run the v0.1 diagnostic checks
configure-bluetooth.sh  Inspect or later configure BlueZ behavior
configure-pipewire.sh   Inspect or later configure PipeWire/WirePlumber behavior
configure-ofono.sh      Inspect or later configure oFono behavior
```

## Conservative Defaults

Configuration scripts inspect the system by default. They do not modify system configuration
unless an explicit `--apply` flag is provided.

The v0.1 `--apply` path is intentionally limited and mostly reports what is not implemented yet.
This keeps the project from enabling unsafe Bluetooth behavior before the required settings are
well understood.

## Common Commands

```bash
./server/check-system.sh
./server/install.sh --list
sudo ./server/install.sh --install
./server/configure-bluetooth.sh
./server/configure-pipewire.sh
./server/configure-ofono.sh
```
