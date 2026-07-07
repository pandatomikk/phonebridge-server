# PhoneBridge Research: HFP/HSP Roles

Research date: 2026-07-07.

## HFP Roles

HFP is asymmetric:

- Audio Gateway (AG): the device with telephony service and call state.
- Hands-Free (HF): the accessory that presents speaker, microphone, and call controls.

For PhoneBridge:

- Android is the AG because it owns GSM and VoIP calls.
- Raspberry Pi must be the HF because it should look like a car hands-free kit.
- PhoneBridge's primary profile target is HFP Hands-Free (`hfp_hf`).
- HSP should be kept as a fallback/compatibility profile, not the main design.

## BlueZ Role Data

BlueZ Profile API lists predefined UUIDs:

```text
HFP AG: 0000111f-0000-1000-8000-00805f9b34fb
HFP HS: 0000111e-0000-1000-8000-00805f9b34fb
HSP AG: 00001112-0000-1000-8000-00805f9b34fb
HSP HS: 00001108-0000-1000-8000-00805f9b34fb
```

BlueZ uses `HS` naming for the headset/hands-free side in the predefined UUID list. WirePlumber
uses role names `hfp_hf`, `hfp_ag`, `hsp_hs`, and `hsp_ag`.

## Android Expectations

Documented fact:

- HFP defines an Audio Gateway side and a Hands-Free side.
- BlueZ and WirePlumber expose both HFP HF and HFP AG role names.

Working assumption:

- Android phones normally act as HFP Audio Gateway when pairing to car kits/headsets.
- Therefore the Raspberry Pi must advertise/enable the HFP Hands-Free side and must not be
  designed as the primary Audio Gateway.

This must be validated on real Android versions because vendors can differ in Bluetooth behavior,
especially for VoIP call routing.

## Control and Audio Channels

HFP has two distinct paths:

```text
Service-level control:
Android AG <-> Bluetooth RFCOMM/AT commands <-> Raspberry HF backend

Audio:
Android AG <-> Bluetooth SCO/eSCO <-> Raspberry audio backend <-> PipeWire
```

Call control includes answer, hangup, call state, voice recognition flags, indicators, and feature
negotiation. oFono exposes call state/control via its Handsfree and VoiceCall APIs.

## A2DP Is Not Call Audio

A2DP is high-quality one-way or mostly media-oriented audio. It is not the correct profile for
bidirectional phone call audio. A2DP may appear when Android connects for music playback, but
PhoneBridge's car-kit behavior depends on HFP/HSP, not A2DP.

## HSP Position

HSP is older and simpler than HFP. It can provide headset-style bidirectional audio, but it lacks
the richer hands-free call-control model expected by car kits. PhoneBridge should keep HSP in the
research scope only as a compatibility fallback.

Decision:

- Primary: HFP Hands-Free (`hfp_hf`)
- Fallback research item: HSP Headset (`hsp_hs`)
- Not primary: A2DP

## Sources

- BlueZ Profile API: https://bluez.readthedocs.io/en/latest/profile-api/
- BlueZ Device API: https://bluez.readthedocs.io/en/latest/device-api/
- WirePlumber Bluetooth roles: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
- oFono Handsfree API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/handsfree-api.txt
- oFono VoiceCall API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/voicecall-api.txt
