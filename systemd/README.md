# systemd

This directory contains systemd templates for PhoneBridge Server helpers.

## Current Units

`phonebridge-network-audio.service.in`:

- template for a systemd user service
- runs `configure-network-audio.sh --serve-peer`
- ensures the PipeWire/Pulse network tunnel endpoints exist
- keeps the Bluetooth call-routing watcher active
- installed by `server/install-network-audio-service.sh`

Install on the Raspberry Pi with:

```bash
./server/install-network-audio-service.sh --peer <PC_IP_OR_HOSTNAME> --enable --start --status
```

## Remaining Planned Units

Other units should wait until the project validates:

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
