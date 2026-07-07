# PhoneBridge Research: Architecture

Research date: 2026-07-07.

## Goal

PhoneBridge Server should make a Raspberry Pi appear to an Android phone as a Bluetooth
Hands-Free device, similar to a car kit. The project scope is Bluetooth HFP/HSP call audio only:
no screen sharing, ADB, scrcpy, KDE Connect, notifications, SMS, or phone control beyond what is
required for HFP call/audio state.

## High-level Stack

```text
Android phone
  HFP Audio Gateway role
  GSM/VoIP call audio + call state
        |
        | Bluetooth BR/EDR
        | RFCOMM control + SCO/eSCO audio
        v
BlueZ on Raspberry Pi
  pairing, adapter state, SDP/profile registration, device lifecycle
        |
        | system D-Bus
        v
oFono and/or PipeWire Bluetooth backend
  HFP service-level connection, call state, SCO acquisition
        |
        | PipeWire graph objects
        v
PipeWire + WirePlumber
  audio nodes, routing policy, virtual source/sink creation
        |
        v
local apps now, network audio bridge later
```

## Component Responsibilities

| Area | Primary component | Notes |
| --- | --- | --- |
| Adapter power, discoverable/pairable mode | BlueZ | `org.bluez.Adapter1` exposes `Powered`, `Discoverable`, `Pairable`, and timeouts. |
| Pairing and trust | BlueZ | `org.bluez.AgentManager1` and `org.bluez.Device1.Pair()` handle pairing and agent prompts. |
| Profile registration | BlueZ | `org.bluez.ProfileManager1.RegisterProfile()` registers UUIDs including HFP/HSP roles. |
| A2DP media transport | BlueZ + PipeWire | BlueZ Media API exposes A2DP endpoints/transports; PipeWire consumes them as audio devices. |
| HFP/HSP role selection | WirePlumber config + backend | WirePlumber `bluez5.roles` includes `hfp_hf`, `hfp_ag`, `hsp_hs`, `hsp_ag`. |
| HFP call state/control | oFono or native backend | oFono exposes Handsfree and VoiceCall D-Bus APIs; PipeWire/WirePlumber can use `native`, `ofono`, or `hsphfpd` backends. |
| SCO/eSCO audio fd | oFono or backend integration | oFono HandsfreeAudioCard can `Acquire()` a SCO fd and codec. |
| Audio graph | PipeWire | PipeWire exposes Bluetooth audio as graph nodes for clients. |
| Routing policy | WirePlumber | WirePlumber monitors BlueZ devices and applies policy to PipeWire nodes. |
| IPC | D-Bus | BlueZ and oFono are system D-Bus services; PipeWire session services use user D-Bus/systemd user session. |

## Communication Model

Documented facts:

- BlueZ exposes D-Bus APIs under `org.bluez` for adapters, devices, agents, media, and profiles.
- BlueZ Profile API has predefined UUIDs for HFP AG, HFP HS, HSP AG, and HSP HS.
- BlueZ Media API allows applications to register media endpoints and acquire transport file descriptors.
- oFono exposes `org.ofono.Handsfree`, `org.ofono.HandsfreeAudioManager`, and `org.ofono.VoiceCall`.
- WirePlumber's Bluetooth monitor config controls BlueZ roles and HFP/HSP backend selection.

Working assumptions for PhoneBridge:

- The Raspberry Pi should advertise the HFP Hands-Free side (`hfp_hf`) to Android.
- Android is the HFP Audio Gateway because it owns the cellular/VoIP call and routes call audio to
  a hands-free accessory.
- PhoneBridge should first rely on the distribution PipeWire/WirePlumber/BlueZ/oFono integration
  before writing a custom BlueZ Profile1 implementation.

## Risks

- The user PipeWire session may not exist on a headless Raspberry Pi.
- Android may expose different HFP behavior for GSM and VoIP calls.
- The BlueZ/PipeWire/WirePlumber HFP backend may differ between Debian 13 and Raspberry Pi OS.

## Decisions

- Use modern BlueZ, PipeWire, WirePlumber, oFono, and D-Bus as the target architecture.
- Keep v0.1/v0.2 limited to diagnostics, installation, pairing preparation, and documentation.
- Do not implement custom HFP role logic until real-device traces prove what is needed.

## Tests on Real Raspberry Pi

- Confirm `bluetoothctl show` exposes an adapter and stable controller state.
- Confirm a PipeWire user session exists after reboot without a desktop login.
- Pair Android and capture BlueZ, WirePlumber, PipeWire, and oFono state before and during a call.

## Sources

- BlueZ Adapter API: https://bluez.readthedocs.io/en/latest/adapter-api/
- BlueZ Agent API: https://bluez.readthedocs.io/en/latest/agent-api/
- BlueZ Device API: https://bluez.readthedocs.io/en/latest/device-api/
- BlueZ Profile API: https://bluez.readthedocs.io/en/latest/profile-api/
- BlueZ Media API: https://bluez.readthedocs.io/en/latest/media-api/
- WirePlumber Bluetooth configuration: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
- PipeWire loopback module: https://docs.pipewire.org/page_module_loopback.html
- oFono Handsfree API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/handsfree-api.txt
- oFono Handsfree Audio API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/handsfree-audio-api.txt
- oFono VoiceCall API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/voicecall-api.txt
