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

## v0.2 BlueZ Configuration

- Document required BlueZ options for HFP/HSP experiments.
- Add guarded configuration helpers.
- Keep all configuration changes explicit.
- Preserve backups before modifying system files.

## v0.3 Raspberry Pi Discoverable

- Add a controlled discoverable/pairable mode helper.
- Document how long discoverable mode should remain active.
- Avoid leaving the device discoverable indefinitely by default.

## v0.4 Android Sees Raspberry Pi as Hands-Free Device

- Validate advertised Bluetooth roles.
- Document Android pairing flow.
- Capture required BlueZ and oFono state.

## v0.5 Local Bidirectional HFP Audio

- Route microphone and speaker audio locally through PipeWire.
- Verify call audio in both directions.
- Document codec and device limitations.

## v0.6 Local PipeWire Audio Exposure

- Expose stable PipeWire nodes where possible.
- Document routing controls and policy interactions.
- Prepare repeatable debug captures.

## v0.7 Network Audio Preparation

- Define transport requirements.
- Compare viable Linux audio network approaches.
- Prepare interfaces for a later network streaming implementation.

Network streaming is not part of v0.1.
