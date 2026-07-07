# Architecture

PhoneBridge Server is a Linux-side Bluetooth audio gateway for Android phones.

## Boundaries

PhoneBridge Server handles audio only:

- Bluetooth hands-free/headset profiles
- local Linux audio routing
- future network audio transport preparation

PhoneBridge Server does not handle:

- Android screen mirroring
- notifications
- SMS
- phone control
- contact sync
- file transfer

Those are intentionally left to tools such as scrcpy, KDE Connect, or other dedicated software.

## Target Stack

```text
Android Phone
  -> Bluetooth HFP/HSP
  -> BlueZ
  -> oFono
  -> PipeWire
  -> WirePlumber
  -> local audio devices
```

BlueZ provides the Bluetooth host stack. oFono is expected to participate in HFP/HSP modem and
hands-free integration. PipeWire owns the audio graph, and WirePlumber manages policy and routing.

## Initial Platform

The first supported systems are:

- Raspberry Pi OS Bookworm
- Debian 13+
- PipeWire as the active audio server
- WirePlumber as the PipeWire session manager
- BlueZ as the Bluetooth stack
- oFono for HFP/HSP integration

## Design Principles

- Prefer current PipeWire and WirePlumber behavior over PulseAudio compatibility paths.
- Keep system changes explicit and reversible.
- Make diagnostics useful before attempting automation.
- Avoid enabling insecure Bluetooth behavior automatically.
- Keep every script runnable on its own.

## Future Audio Network Layer

Network audio transport is planned after local HFP/HSP audio works reliably. Version 0.7 should
prepare that work, but v0.1 does not implement it.
