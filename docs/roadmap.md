# Roadmap

## v0.1 Diagnostic System

- Create repository skeleton.
- Provide install and dependency listing helpers.
- Check Bluetooth hardware visibility.
- Check BlueZ service and tools.
- Check PipeWire service and tools.
- Check WirePlumber service and tools.
- Check oFono service and tools.
- Produce readable logs and diagnostics.

## v0.2 Clean Installation

- Harden dependency detection.
- Install required packages without changing configuration files.
- Report unsupported platforms clearly.

## v0.3 Bluetooth Pairing

- Add controlled discoverable/pairable mode.
- Document Android pairing flow.
- Avoid leaving the device discoverable indefinitely.

## v0.4 Android Sees Server as Hands-Free Device

- Validate advertised Bluetooth roles.
- Confirm Android sees PhoneBridge as call-audio capable.
- Capture required BlueZ and oFono state.

## v0.5 Local Bidirectional HFP Audio

- Route microphone and speaker audio locally through PipeWire.
- Verify call audio in both directions.
- Document codec and device limitations.

## v0.6 Local PipeWire Audio Exposure

- Expose stable PipeWire nodes where possible.
- Document routing controls and policy interactions.
- Prepare repeatable debug captures.

## v0.7 Network Audio Transport Preparation

- Define network transport requirements.
- Compare viable Linux audio network approaches.
- Prepare interfaces for a later network streaming implementation.

Network streaming is not part of v0.1.
