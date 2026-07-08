# Bluetooth Pairing Procedure

This phase only prepares Bluetooth discovery and pairing. It does not implement HFP audio,
PipeWire routing, network transport, RTP, WebRTC, scrcpy, or KDE Connect integration.

## Goal

Success for this phase:

```text
Android Settings
  -> Bluetooth
  -> PhoneBridge
  -> Connected for Calls
```

If Android can pair but does not show call support, the remaining blocker is HFP Hands-Free profile
advertisement/backend support. Do not guess a fix; collect diagnostics first.

## Fresh Raspberry Pi Procedure

1. Install dependencies:

```bash
sudo ./server/install.sh --install
```

2. Run the diagnostic:

```bash
./server/check-system.sh
```

3. Prepare Bluetooth safely:

```bash
sudo ./server/configure-bluetooth.sh --apply
```

This starts/enables `bluetooth.service`, powers the controller on, sets the alias to `PhoneBridge`,
and requests temporary pairable/discoverable mode. It does not edit `bluetoothd.conf`.

4. Open a reversible discovery window:

```bash
./server/pair-phone.sh --discoverable
```

Keep the terminal open while pairing. The helper starts a foreground `bluetoothctl` pairing agent.
If it shows an `[agent] Confirm passkey` prompt, type `yes` in the terminal and confirm the same
code on Android. Do not type the numeric passkey unless `bluetoothctl` explicitly asks for it.

5. On Android:

```text
Settings -> Bluetooth -> Pair new device -> PhoneBridge
```

6. Verify:

```bash
./server/pair-phone.sh --check
./scripts/debug.sh > phonebridge-bluetooth-report.md
```

On Android, check whether the paired device says call audio or connected for calls.

## Pairing Guide

For manual pairing support:

```bash
./server/pair-phone.sh --pair
```

The helper prints the relevant `bluetoothctl` commands and current paired-device status. Keep the
manual `bluetoothctl` session open while pairing from Android. Use `agent DisplayYesNo`; if prompted
with `[agent] Confirm passkey`, type `yes`, then trust the phone after pairing succeeds.

## Removing a Phone

```bash
./server/pair-phone.sh --remove
```

The helper lists paired devices and asks which one to remove.

## HFP Discovery Findings

Known facts:

- BlueZ handles adapters, pairing, device objects, D-Bus APIs, and profile registration plumbing.
- Android is expected to be the HFP Audio Gateway because it owns GSM and VoIP calls.
- PhoneBridge must appear as the HFP Hands-Free side, like a car kit.
- BlueZ alone does not provide a complete HFP call/audio backend; the modern Linux stack usually
  involves PipeWire/WirePlumber native HFP/HSP support and/or oFono.

Current phase decision:

- Do not edit `bluetoothd.conf`.
- Do not force HFP roles from scripts.
- Do not implement audio.
- Use diagnostics to determine whether Android sees call support after basic pairing.

If Android does not show call support:

- collect `./scripts/debug.sh`
- inspect `bluetoothctl show` UUIDs
- inspect `busctl --system tree org.bluez`
- inspect WirePlumber Bluetooth backend configuration
- inspect oFono availability
- document the exact blocker before changing configuration
