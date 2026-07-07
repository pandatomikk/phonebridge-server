# systemd

This directory is reserved for future PhoneBridge Server unit files.

No systemd unit is installed in v0.1. The project must first validate:

- the required BlueZ state
- the required oFono state
- local PipeWire and WirePlumber routing
- safe startup and shutdown behavior

## Planned Units

`phonebridge-server.service`:

- future umbrella service for long-running PhoneBridge orchestration
- should start only after the stack requirements are validated

`phonebridge-pairing.service`:

- future short-lived helper for controlled Bluetooth pairing windows
- should never leave the adapter discoverable indefinitely

`phonebridge-audio.service`:

- future audio routing service after local HFP audio is proven
- should manage local PipeWire endpoints, not network streaming in v0.1

Future units should:

- avoid running privileged code unless required
- document every capability and permission
- keep service restart behavior conservative
- separate diagnostics from long-running service behavior
