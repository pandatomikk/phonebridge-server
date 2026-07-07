# PhoneBridge Research: oFono

Research date: 2026-07-07.

## Why oFono Still Matters

oFono is a telephony service with D-Bus APIs for hands-free features, call state, and hands-free
audio. Even with PipeWire as the audio graph, HFP needs more than PCM routing:

- feature negotiation
- call indicators
- answer/hangup/control commands
- SCO/eSCO audio connection acquisition
- codec indication, currently CVSD and mSBC in the oFono Handsfree Audio API

PipeWire/WirePlumber can handle audio nodes and routing, but the telephony state machine is a
separate problem. oFono is one available implementation of that layer.

## Relevant APIs

`org.ofono.Handsfree`:

- properties for AG-supported features
- voice recognition state
- in-band ringing state
- battery/subscriber indicators

`org.ofono.VoiceCall`:

- `Answer()`
- `Hangup()`
- call `State`
- disconnect reasons

`org.ofono.HandsfreeAudioManager` and `org.ofono.HandsfreeAudioCard`:

- `Register()` an audio agent with supported codecs
- `GetCards()` to enumerate attached devices
- `Connect()` to establish SCO audio
- `Acquire()` to establish SCO audio and return the fd and codec
- card `Type` is documented as `gateway` or `handsfree`

## Relation to PipeWire

When the HFP/HSP backend is set to `ofono`, PipeWire/WirePlumber can rely on oFono for the HFP
telephony/audio-card side. PipeWire then represents the resulting audio as graph nodes.

When the backend is `native`, PipeWire/WirePlumber may bypass oFono for some use cases. The native
backend must be tested on the target distributions before choosing it as the default PhoneBridge
path.

## Could oFono Be Replaced?

Documented fact:

- WirePlumber currently documents multiple HFP/HSP backends: `native`, `ofono`, and `hsphfpd`.

Working assumption:

- oFono can eventually be replaced if PipeWire's native backend fully covers PhoneBridge's needed
  role: HFP HF against Android AG, SCO audio, call indicators/control, and stable PipeWire nodes.

Recommendation:

- v0.1 should detect oFono and backend capabilities.
- v0.2/v0.3 should test both `native` and `ofono` on real Debian 13 and Raspberry Pi OS Bookworm
  before committing to one backend.

## Sources

- oFono project: https://git.kernel.org/pub/scm/network/ofono/ofono.git/about/
- oFono Handsfree API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/handsfree-api.txt
- oFono Handsfree Audio API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/handsfree-audio-api.txt
- oFono VoiceCall API: https://git.kernel.org/pub/scm/network/ofono/ofono.git/plain/doc/voicecall-api.txt
- WirePlumber HFP/HSP backend docs: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
