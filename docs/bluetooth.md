# Bluetooth Notes

PhoneBridge Server targets Bluetooth HFP/HSP behavior for Android phones.

HFP is the primary target because Android should see the server as a Hands-Free device, like a car
kit. HSP remains a fallback research item. A2DP is media audio and is not the correct profile for
bidirectional call audio.

## Components

- BlueZ provides Linux Bluetooth controller, pairing, discovery, and profile plumbing.
- oFono is expected to support hands-free profile integration.
- PipeWire and WirePlumber consume and route audio once Bluetooth audio devices exist.

## v0.1 Checks

The current diagnostic scripts check:

- whether Bluetooth tools are installed
- whether the Bluetooth kernel module is loaded
- whether a Bluetooth controller is visible
- whether `bluetooth.service` exists and is active
- whether `bluetoothctl` can report controllers
- whether rfkill blocks Bluetooth
- whether the controller is pairable/discoverable

## Safety

Bluetooth discoverable and pairable modes can expose the device to nearby phones and computers.
The v0.1 scripts do not enable those modes automatically.

`server/configure-bluetooth.sh --apply` may request temporary pairable/discoverable mode, but it
does not write permanent BlueZ configuration and does not force HFP roles.

## Pairing Phase

This phase prepares only:

- BlueZ service startup
- adapter powered on
- alias `PhoneBridge`
- temporary pairable/discoverable mode
- Android pairing diagnostics

It does not configure HFP audio or PipeWire routing.

Use:

```bash
sudo ./server/configure-bluetooth.sh --apply
./server/pair-phone.sh --discoverable
```

If Android pairs but does not show "Connected for Calls", the likely unresolved area is HFP
Hands-Free profile advertisement/backend support. Capture `./scripts/debug.sh` before changing
BlueZ, WirePlumber, or oFono configuration.

Future configuration helpers should:

- require an explicit `--apply` flag
- explain exactly what will change
- prefer time-limited discoverable mode
- avoid weakening pairing security

## Useful Manual Commands

```bash
bluetoothctl list
bluetoothctl show
systemctl status bluetooth.service
journalctl -u bluetooth.service
```
