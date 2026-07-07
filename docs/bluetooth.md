# Bluetooth Notes

PhoneBridge Server targets Bluetooth HFP/HSP behavior for Android phones.

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

## Safety

Bluetooth discoverable and pairable modes can expose the device to nearby phones and computers.
The v0.1 scripts do not enable those modes automatically.

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
