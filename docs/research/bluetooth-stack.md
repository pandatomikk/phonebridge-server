# PhoneBridge Research: Modern Linux Bluetooth Stack

Research date: 2026-07-07.

## BlueZ

BlueZ is the official Linux Bluetooth stack. On Debian 13, the `bluez` package is version
`5.82-1.1` and includes the Bluetooth daemon and tools.

BlueZ responsibilities:

- Bluetooth controller state: powered, pairable, discoverable.
- Device discovery and device objects.
- Pairing and trust via agent APIs.
- SDP/profile registration through `ProfileManager1`.
- A2DP media endpoint and transport management through the Media API.
- HFP/HSP service-level profile plumbing, depending on registered roles/backends.

Important APIs:

- `org.bluez.Adapter1`: adapter state and discovery.
- `org.bluez.AgentManager1`: pairing agent registration.
- `org.bluez.Device1`: pair/connect/connect-profile operations.
- `org.bluez.ProfileManager1`: custom profile registration.
- `org.bluez.Media1` and `org.bluez.MediaTransport1`: media endpoints and transport fds.

## D-Bus

D-Bus is the control plane. BlueZ and oFono live on the system bus. PipeWire and WirePlumber are
usually per-user services, so their normal runtime control plane depends on the user session and
user D-Bus/systemd state.

For PhoneBridge this means there are two operational contexts:

- system services: `bluetooth.service`, `ofono.service`
- user audio session: `pipewire.service`, `wireplumber.service`

A headless Raspberry Pi must still provide a stable PipeWire user session if the audio graph is
owned by a user service.

## PipeWire

PipeWire is the multimedia graph. On Debian 13, the `pipewire` package is version `1.4.2-1`.
Debian describes it as a server and user-space API for multimedia pipelines, source/sink exposure,
consumption, and graph processing.

In the Bluetooth path, PipeWire does not pair phones. It receives Bluetooth audio devices/nodes
from the BlueZ monitor/backend path and exposes them as normal PipeWire nodes.

## WirePlumber

WirePlumber is PipeWire's session and policy manager. Its Bluetooth monitor configuration includes
the BlueZ roles:

```text
a2dp_sink a2dp_source bap_sink bap_source hsp_hs hsp_ag hfp_hf hfp_ag
```

The documented default role list includes A2DP sink/source, BAP sink/source, HFP HF, and HFP AG.
It does not include `hsp_hs`/`hsp_ag` by default in the cited WirePlumber 0.5 docs. HSP is older
and should be treated as a compatibility fallback, not the primary target.

WirePlumber also selects the HFP/HSP backend via `bluez5.hfphsp-backend`, documented values:
`any`, `none`, `hsphfpd`, `ofono`, `native`. The cited documentation says the default is `native`.

## oFono

oFono is a telephony D-Bus service. It still matters for HFP because it exposes APIs for:

- Handsfree features and AG properties.
- VoiceCall answer/hangup/state.
- Handsfree audio cards and SCO fd acquisition.

In a PipeWire setup, oFono can be an HFP backend that handles telephony semantics while PipeWire
handles the audio graph.

## Responsibility Matrix

| Function | BlueZ | PipeWire | WirePlumber | oFono | D-Bus |
| --- | --- | --- | --- | --- | --- |
| Pairing | primary | no | policy may observe | no | control transport |
| HFP role advertisement | primary/profile registration | backend consumer | config/policy | backend participant | control transport |
| HSP | profile support | backend consumer | config/policy | possible backend participant | control transport |
| A2DP | media transport | audio endpoint/node | policy | no | control transport |
| SCO audio fd | low-level BT path | consumes audio | policy | can acquire/provide fd | fd/control passing |
| Microphone routing | no | primary graph | primary policy | no direct routing | control transport |
| Call control | profile/control transport | no | policy only | primary telephony API | control transport |

## Existing Project Summary

BlueZ:

- Primary Linux Bluetooth stack.
- Owns adapter/device/profile/media D-Bus APIs.
- Should remain the base for pairing and profile exposure.

PipeWire:

- Primary modern Linux audio graph.
- Should own audio nodes, virtual sources/sinks, and future integration with network audio.
- Should replace PulseAudio-specific audio server assumptions.

WirePlumber:

- Policy manager for PipeWire.
- Owns practical Bluetooth role/backend policy through the BlueZ monitor configuration.
- Must be inspected before changing any Bluetooth audio behavior.

oFono:

- Telephony-oriented D-Bus service.
- Still relevant because it exposes HFP hands-free, voice call, and hands-free audio card APIs.
- Candidate backend for HFP call state and SCO fd acquisition.

hsphfpd:

- WirePlumber still documents `hsphfpd` as one possible HFP/HSP backend.
- Current public project status was not confirmed during this research pass; probable role is a
  historical/specialized HSP/HFP daemon rather than the first implementation target.
- It should be treated as a compatibility research item, not a v0.1 dependency.

ofono-handsfree:

- No clearly maintained standalone project was identified in this research pass.
- The reliable source is oFono's own Handsfree and HandsfreeAudio D-Bus API documentation.
- Any external `ofono-handsfree` examples should be treated as implementation examples only, not
  as authoritative architecture.

Maintained HFP implementation candidates:

- Distribution BlueZ + PipeWire + WirePlumber with `native` HFP/HSP backend.
- Distribution BlueZ + PipeWire + WirePlumber with `ofono` HFP/HSP backend.

PhoneBridge should test these maintained distribution paths before considering a custom daemon.

## Facts, Assumptions, Risks, Decisions

Facts:

- BlueZ owns pairing, adapters, devices, profiles, and media transports.
- D-Bus is the control plane for BlueZ and oFono.
- WirePlumber documents selectable Bluetooth HFP/HSP backends.

Assumptions:

- Distribution-provided BlueZ/WirePlumber/PipeWire integration is the safest first target.
- Android should be tested as HFP Audio Gateway against a Raspberry Pi HFP Hands-Free role.

Risks:

- HFP backend defaults may differ by distro or package version.
- Bluetooth controllers may expose inconsistent SCO/eSCO behavior.

Decisions:

- Do not write a custom BlueZ profile daemon in v0.1/v0.2.
- Diagnose stack state before changing Bluetooth configuration.

Tests on real Raspberry Pi:

- Compare onboard Bluetooth and a known-good USB Bluetooth adapter.
- Capture `btmon` traces for pairing and call setup.
- Record active WirePlumber HFP/HSP backend behavior.

## Sources

- Debian BlueZ package: https://packages.debian.org/trixie/bluez
- Debian PipeWire package: https://packages.debian.org/trixie/pipewire
- Debian WirePlumber package: https://packages.debian.org/trixie/wireplumber
- Debian oFono package: https://packages.debian.org/trixie/ofono
- BlueZ Adapter API: https://bluez.readthedocs.io/en/latest/adapter-api/
- BlueZ Agent API: https://bluez.readthedocs.io/en/latest/agent-api/
- BlueZ Device API: https://bluez.readthedocs.io/en/latest/device-api/
- BlueZ Profile API: https://bluez.readthedocs.io/en/latest/profile-api/
- BlueZ Media API: https://bluez.readthedocs.io/en/latest/media-api/
- WirePlumber Bluetooth configuration: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
- oFono APIs: https://git.kernel.org/pub/scm/network/ofono/ofono.git/tree/doc/
