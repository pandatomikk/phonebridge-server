# systemd

This directory is reserved for future PhoneBridge Server unit files.

No systemd unit is installed in v0.1. The project must first validate:

- the required BlueZ state
- the required oFono state
- local PipeWire and WirePlumber routing
- safe startup and shutdown behavior

Future units should:

- avoid running privileged code unless required
- document every capability and permission
- keep service restart behavior conservative
- separate diagnostics from long-running service behavior
