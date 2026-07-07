# Audio Notes

PhoneBridge Server targets PipeWire and WirePlumber as the local Linux audio stack.

## Target Components

- PipeWire owns the audio graph.
- WirePlumber manages device policy and routing.
- oFono participates in HFP/HSP integration.
- BlueZ exposes Bluetooth audio devices and profile state.

Expected call-audio direction:

```text
Android call downlink -> Bluetooth SCO/eSCO -> BlueZ/HFP backend -> PipeWire node -> local app
Linux microphone/source -> PipeWire node -> BlueZ/HFP backend -> Bluetooth SCO/eSCO -> Android uplink
```

## PulseAudio

PulseAudio documentation may be useful as historical context, especially for older HFP/HSP
guides. It is not the main implementation target for this project.

## v0.1 Checks

The diagnostic scripts check:

- `pipewire` command availability
- `pw-cli` command availability
- user-level `pipewire.service`
- user-level `wireplumber.service`
- `wpctl status` when available
- `ofonod` and `ofono.service`

Future versions may create stable PipeWire virtual sources/sinks, but v0.1 does not install active
audio routing.

## Open Questions

- Exact oFono configuration required on Raspberry Pi OS Bookworm and Debian 13+.
- Whether platform firmware packages differ by Raspberry Pi model.
- How Android devices expose HFP/HSP behavior across versions.
- How to create stable PipeWire node names for later routing.
