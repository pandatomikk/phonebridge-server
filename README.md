# PhoneBridge Server

PhoneBridge Server is an experimental Linux service project for Raspberry Pi OS Bookworm and
Debian 13+. Its goal is to turn a small Linux machine into a Bluetooth call-audio gateway for an
Android phone.

The project is intentionally audio-only. It does not replace scrcpy or KDE Connect, and it does
not handle screen sharing, notifications, SMS, file sync, or phone control.

## Target Architecture

```text
Android Phone
  -> Bluetooth HFP/HSP
  -> PhoneBridge Server
  -> BlueZ + PipeWire + WirePlumber + oFono
  -> local audio
  -> later: network audio transport to a Linux PC
```

The main implementation targets a modern BlueZ, PipeWire, WirePlumber, and oFono stack.
PulseAudio-era documentation can be useful historical background, but PulseAudio is not the primary
implementation target.

## Current Scope

Version 0.1 is a clean repository skeleton and system diagnostic baseline:

- list or install expected Debian packages
- check Bluetooth hardware and kernel support
- check BlueZ
- check PipeWire
- check WirePlumber
- check oFono
- produce readable diagnostics
- document the next implementation steps

Network audio streaming is explicitly out of scope for this initial version. v0.1 does not yet
make Android route call audio through the server; it prepares diagnostics and guarded setup helpers.

## Repository Layout

```text
docs/       Design notes and implementation roadmap
server/     Install, uninstall, and component configuration helpers
scripts/    Debug and log collection helpers
systemd/    Future service unit documentation
```

## Quick Start

Run a diagnostic without changing system configuration:

```bash
./server/check-system.sh
```

List packages required by the target stack:

```bash
./server/install.sh --list
./server/install.sh --check
```

Install packages on Debian/Raspberry Pi OS:

```bash
sudo ./server/install.sh --install
```

The configuration scripts are conservative. They inspect the system by default and require an
explicit `--apply` flag before making supported changes.

Useful diagnostic commands:

```bash
./server/configure-bluetooth.sh --check
./server/configure-pipewire.sh --check
./server/configure-ofono.sh --check
./scripts/debug.sh
./scripts/logs.sh --since "10 min ago" --lines 120
```

`--apply` modes only perform conservative service-start or temporary pairing-window actions. They
do not write active HFP audio routing and do not install network streaming.

## Roadmap

- v0.1 diagnostic foundation
- v0.2 clean installation flow
- v0.3 Bluetooth pairing flow
- v0.4 Android sees the server as a hands-free device
- v0.5 local bidirectional HFP audio
- v0.6 local PipeWire audio exposure
- v0.7 network audio transport preparation

## Documentation

- [Architecture](docs/architecture.md)
- [Roadmap](docs/roadmap.md)
- [Bluetooth notes](docs/bluetooth.md)
- [Audio notes](docs/audio.md)
- [Research notes](docs/research/decision-log.md)
- [Server scripts](server/README.md)
- [systemd notes](systemd/README.md)
