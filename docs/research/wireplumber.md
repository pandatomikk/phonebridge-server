# PhoneBridge Research: WirePlumber

Research date: 2026-07-07.

## Role

WirePlumber is the PipeWire session and policy manager. For PhoneBridge it is the component that
turns low-level Bluetooth audio availability into usable PipeWire routing policy.

Documented facts:

- WirePlumber has a BlueZ monitor configuration.
- The documented Bluetooth role list includes `a2dp_sink`, `a2dp_source`, `bap_sink`,
  `bap_source`, `hfp_hf`, and `hfp_ag`.
- HSP role names `hsp_hs` and `hsp_ag` are available but are not in the documented default role
  list.
- The documented HFP/HSP backend values are `any`, `none`, `hsphfpd`, `ofono`, and `native`.
- The cited WirePlumber documentation lists `native` as the default backend.

Working assumptions:

- PhoneBridge should first observe the distribution default backend rather than forcing one.
- `ofono` may still be needed on some target systems for complete HFP call state and SCO behavior.
- Any backend choice must be validated on real Android hardware.

## Responsibilities

WirePlumber should be responsible for:

- detecting BlueZ devices through the Bluetooth monitor
- applying Bluetooth profile policy
- selecting or exposing the active profile where supported
- linking PipeWire capture/playback nodes according to policy
- keeping virtual endpoints usable once PhoneBridge adds them later

WirePlumber should not be responsible for:

- pairing UI
- permanent BlueZ adapter security policy
- Android call implementation
- network transport

## PhoneBridge Relevance

PhoneBridge v0.1 diagnostics should report:

- WirePlumber package version
- `wireplumber.service` state
- whether Bluetooth configuration keys are present
- effective Bluetooth roles/backend when this can be discovered
- PipeWire nodes exposed during Android pairing and during a real call

## Risks

- Documentation may describe upstream defaults while the target distro ships patched defaults.
- Selecting `ofono` or `native` prematurely may hide the backend that actually works on the Pi.
- Policy changes can affect all Bluetooth audio devices for the user session.

## Decisions

- v0.1/v0.2 must not force `bluez5.roles` or `bluez5.hfphsp-backend`.
- Backend choice remains a documented decision pending real-device traces.

## Tests on Real Raspberry Pi

- Locate effective WirePlumber configuration paths.
- Compare `native` and `ofono` backend behavior only in a controlled later test.
- Confirm whether HFP HF appears to Android without custom WirePlumber snippets.

## Sources

- WirePlumber Bluetooth configuration: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
- PipeWire modules overview: https://docs.pipewire.org/page_modules.html
- PipeWire SPA plugins: https://docs.pipewire.org/page_spa_plugins.html
