# PhoneBridge Research: PipeWire and WirePlumber Audio Path

Research date: 2026-07-07.

## Bluetooth Audio Flow

Incoming call audio:

```text
Android call audio
  -> Android HFP AG
  -> Bluetooth SCO/eSCO
  -> BlueZ controller/host stack
  -> HFP backend, likely oFono/native PipeWire backend
  -> PipeWire Bluetooth node
  -> WirePlumber policy links
  -> local sink, virtual source, recorder, or future network bridge
```

Reverse microphone audio:

```text
Linux microphone or virtual source
  -> PipeWire node
  -> WirePlumber policy links
  -> PipeWire Bluetooth node
  -> HFP backend SCO/eSCO stream
  -> BlueZ/controller
  -> Android HFP AG
  -> GSM/VoIP call uplink
```

## Bluetooth Monitor and SPA Plugins

WirePlumber has a Bluetooth monitor configuration for BlueZ devices. PipeWire uses SPA plugins as
loadable objects/factories. The SPA documentation describes plugins as dynamically loadable objects
that can be inspected and instantiated at runtime.

For PhoneBridge, the important practical consequence is:

- Bluetooth devices should become PipeWire objects.
- PhoneBridge should inspect PipeWire nodes instead of parsing BlueZ state alone.
- The runtime truth for audio routing is the PipeWire graph, not just `bluetoothctl`.

## HFP/HSP Backend

WirePlumber documents `bluez5.hfphsp-backend` with values:

```text
any, none, hsphfpd, ofono, native
```

The cited docs list `native` as the default. `ofono` remains available and may be required on some
systems or for specific call-control/audio-card behavior. PhoneBridge should diagnose which backend
is active before attempting behavior changes.

## Virtual Nodes, Sinks, and Sources

PipeWire can create virtual routing elements:

- `libpipewire-module-loopback` can pass capture to playback and can create virtual sinks/sources.
- `libpipewire-module-filter-chain` can create a processing graph and can also be exposed as a
  virtual sink/source.

This is important for v0.6/v0.7 because PhoneBridge can later create stable virtual endpoints:

- `phonebridge-call-downlink`: Android caller audio exposed locally.
- `phonebridge-call-uplink`: microphone audio sent back to Android.

Names above are recommendations, not implementation.

## Can PipeWire Expose Bluetooth Microphone as Normal Microphone?

Yes, when the Bluetooth HFP/HSP device is correctly integrated, PipeWire can expose capture/playback
nodes that ordinary PipeWire-aware clients see as sources/sinks. The exact node availability depends
on successful HFP role negotiation, SCO establishment, backend support, and WirePlumber policy.

Important limitation:

- Seeing a Bluetooth device in BlueZ is not enough.
- PipeWire must receive usable audio nodes.
- The SCO path must be established during a call or test audio state.

## Sources

- WirePlumber Bluetooth configuration: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
- PipeWire SPA plugins: https://docs.pipewire.org/page_spa_plugins.html
- PipeWire loopback module: https://docs.pipewire.org/page_module_loopback.html
- PipeWire filter-chain module: https://docs.pipewire.org/page_module_filter_chain.html
- PipeWire modules overview: https://docs.pipewire.org/page_modules.html
- BlueZ Media API: https://bluez.readthedocs.io/en/latest/media-api/
