# PhoneBridge Research: Decision Log

Research date: 2026-07-07.

## Decisions

### D1: PhoneBridge targets HFP Hands-Free, not Audio Gateway

Status: accepted for v0.1 research.

Reasoning:

- Android owns cellular/VoIP telephony and therefore maps to HFP Audio Gateway.
- A car kit/headset maps to HFP Hands-Free.
- WirePlumber exposes `hfp_hf` and `hfp_ag`; PhoneBridge should select/validate `hfp_hf`.

References:

- BlueZ Profile API: https://bluez.readthedocs.io/en/latest/profile-api/
- WirePlumber Bluetooth configuration: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html

### D2: Do not implement a custom BlueZ Profile1 daemon first

Status: accepted for v0.1.

Reasoning:

- BlueZ, PipeWire, WirePlumber, and oFono already contain the expected integration points.
- A custom Profile1 daemon would need to correctly implement HFP control, AT command behavior,
  SCO acquisition, and policy integration.
- The first version should diagnose existing stack capability before replacing it.

References:

- BlueZ Profile API: https://bluez.readthedocs.io/en/latest/profile-api/
- oFono Handsfree API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/handsfree-api.txt

### D3: Treat A2DP as separate and secondary

Status: accepted for v0.1.

Reasoning:

- A2DP is media audio and not the correct path for bidirectional call audio.
- It may appear during Android pairing, but PhoneBridge's core feature is HFP call audio.

References:

- BlueZ Media API: https://bluez.readthedocs.io/en/latest/media-api/
- WirePlumber Bluetooth roles: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html

### D4: Detect both native and oFono HFP/HSP backends

Status: accepted for v0.1.

Reasoning:

- WirePlumber documents `native` as the default HFP/HSP backend.
- oFono remains documented and exposes useful telephony/SCO APIs.
- The correct production choice depends on target distribution behavior and Android compatibility.

References:

- WirePlumber Bluetooth backend config: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
- oFono Handsfree Audio API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/handsfree-audio-api.txt

### D5: Expose stable PipeWire virtual endpoints later

Status: proposed for v0.6/v0.7, not v0.1 implementation.

Reasoning:

- PipeWire loopback and filter-chain can create virtual sinks/sources.
- Stable named nodes will make local testing and future network transport cleaner.

References:

- PipeWire loopback module: https://docs.pipewire.org/page_module_loopback.html
- PipeWire filter-chain module: https://docs.pipewire.org/page_module_filter_chain.html

## Recommended v0.1 Architecture

No audio implementation yet. v0.1 should be a diagnostic and evidence-gathering release:

```text
PhoneBridge v0.1 diagnostics
  -> collect OS/package versions
  -> inspect BlueZ adapter/device/profile state
  -> inspect WirePlumber Bluetooth role/backend configuration
  -> inspect PipeWire nodes and links
  -> inspect oFono D-Bus availability, handsfree cards, call objects
  -> report whether the system can plausibly act as HFP HF
```

Recommended package baseline:

- `bluez`
- `pipewire`
- `pipewire-pulse`
- `pipewire-bin`
- `wireplumber`
- `ofono`
- `dbus`
- `jq`
- `usbutils`
- `pciutils`
- `rfkill`
- optional for deeper diagnostics: `bluez-test-tools`, `btmon` provider package if split by distro

Recommended next research validation:

1. Pair one Android phone to Raspberry Pi with only standard BlueZ/WirePlumber services.
2. Confirm Android sees Raspberry Pi as call-audio capable, not just media audio.
3. During a real call, capture `bluetoothctl`, `btmon`, `busctl org.ofono`, `wpctl status`,
   `pw-cli ls Node`, and journal logs.
4. Compare WirePlumber `native` vs `ofono` backend on Debian 13 and Raspberry Pi OS Bookworm.
5. Only after successful HFP HF audio appears in PipeWire, design stable virtual nodes for local
   and future network exposure.
