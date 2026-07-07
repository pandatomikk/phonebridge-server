# Contributing

PhoneBridge Server is experimental infrastructure for Bluetooth HFP/HSP call audio on Linux.

## Scope

Keep contributions focused on:

- BlueZ, PipeWire, WirePlumber, and oFono diagnostics
- cautious Bluetooth pairing helpers
- local PipeWire call-audio exposure
- future network audio transport preparation

Do not add screen sharing, notifications, SMS, clipboard sync, scrcpy integration, or KDE Connect
integration.

## Safety

- Do not enable permanent discoverable Bluetooth mode by default.
- Do not overwrite system configuration without an explicit opt-in path.
- Keep scripts idempotent where possible.
- Keep diagnostics read-only.

## Shell Scripts

Scripts should use:

- `#!/usr/bin/env bash`
- `set -euo pipefail`
- clear functions
- `--help`
- readable `INFO`, `OK`, `WARNING`, and `ERROR` output

Run before submitting changes:

```bash
bash -n server/*.sh scripts/*.sh
./server/install.sh --list
./server/install.sh --check
./server/check-system.sh
```
