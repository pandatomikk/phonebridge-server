# PhoneBridge Research: Technical Risks

Research date: 2026-07-07.

## Android Compatibility

Risk: Android behavior differs by vendor, Android version, and whether the call is GSM or VoIP.

Impact: The phone may pair but not route VoIP call audio to HFP, or may prefer A2DP for media and
only activate HFP during cellular calls.

Mitigation: Test at least two Android vendors and both GSM and VoIP calls. Log BlueZ, oFono,
PipeWire, and WirePlumber during pairing, connection, and call start.

## Wrong HFP Role

Risk: Configuring the Raspberry Pi as HFP AG instead of HFP HF.

Impact: Android will not treat the Raspberry Pi as a car kit/headset.

Mitigation: Default research decision is `hfp_hf` for PhoneBridge. Validate advertised UUIDs and
Android pairing UI.

## SCO/eSCO Routing

Risk: The RFCOMM control connection succeeds but SCO/eSCO audio does not establish or does not reach
PipeWire.

Impact: Call state exists but there is no usable audio.

Mitigation: Add diagnostics for SCO fd acquisition, codec, PipeWire node creation, and active links.

## Backend Differences

Risk: WirePlumber's documented default backend is `native`, while older guidance often expects
`ofono`. Distribution defaults may differ.

Impact: Instructions that work on one system may fail on another.

Mitigation: v0.1 must report active package versions and effective WirePlumber Bluetooth settings.
Do not hard-code backend assumptions.

## Raspberry Pi Bluetooth Controller Limitations

Risk: Pi onboard Bluetooth or firmware may have SCO/eSCO quirks, especially under Wi-Fi coexistence
or USB power constraints.

Impact: pairing works but call audio is unstable, narrowband only, delayed, or absent.

Mitigation: Test onboard adapter and one known-good USB Bluetooth adapter. Capture `btmon` traces
when audio setup fails.

Additional Raspberry Pi limits to validate:

- shared 2.4 GHz Wi-Fi/Bluetooth coexistence
- power supply stability under USB Bluetooth dongles
- firmware/kernel differences between Pi models
- headless user-session behavior for PipeWire

## PipeWire Session Availability on Headless Systems

Risk: PipeWire and WirePlumber are user services, but a headless gateway may not have a stable login
session.

Impact: BlueZ/oFono run, but no PipeWire graph exists for audio.

Mitigation: Define a dedicated service user and document how its systemd user session is kept alive
before implementing long-running audio routing.

## PulseAudio Tutorial Drift

Risk: Old tutorials configure PulseAudio modules that are obsolete or conflict with PipeWire.

Impact: Misconfiguration, duplicate audio servers, wrong Bluetooth backend.

Mitigation: Treat PulseAudio tutorials as historical context only. Translate concepts to PipeWire:

| Old PulseAudio concept | PipeWire-era equivalent |
| --- | --- |
| `pulseaudio-module-bluetooth` | PipeWire/WirePlumber BlueZ monitor and Bluetooth SPA plugins |
| `module-loopback` | `libpipewire-module-loopback` or `pw-loopback` |
| PulseAudio source/sink names | PipeWire node names and media classes |
| PulseAudio default sink/source | WirePlumber policy and PipeWire metadata |
| `pactl` inspection | `wpctl`, `pw-cli`, `pw-dump` |

## Package Version Drift

Risk: Debian 13, Raspberry Pi OS Bookworm, and backports may carry different BlueZ/PipeWire/
WirePlumber behavior.

Impact: Research based on current upstream docs may not exactly match installed packages.

Mitigation: v0.1 diagnostics should record package versions and effective configuration paths.

## Sources

- BlueZ Profile API: https://bluez.readthedocs.io/en/latest/profile-api/
- BlueZ Media API: https://bluez.readthedocs.io/en/latest/media-api/
- WirePlumber Bluetooth configuration: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
- PipeWire loopback module: https://docs.pipewire.org/page_module_loopback.html
- oFono Handsfree Audio API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/handsfree-audio-api.txt
- Debian package metadata: https://packages.debian.org/trixie/
