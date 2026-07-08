# Network Audio Transport

This phase starts after local Android HFP/HSP audio is visible in PipeWire on the Raspberry Pi.

The first transport path uses PipeWire's PulseAudio compatibility layer because it is simple to
test and reversible with `pactl`:

```text
Android call downlink
  -> Raspberry Pi HFP PipeWire node
  -> phonebridge_network_downlink tunnel sink
  -> LAN TCP
  -> Linux PC PipeWire/Pulse listener
  -> PC speakers/headset

Linux PC microphone
  -> Linux PC PipeWire/Pulse listener
  -> LAN TCP
  -> phonebridge_network_uplink tunnel source on Raspberry Pi
  -> Raspberry Pi HFP PipeWire node
  -> Android call uplink
```

## Security Boundary

The helper uses `module-native-protocol-tcp` with anonymous authentication and an IP ACL. This is
for a trusted LAN only. Restrict `--acl` to the Raspberry Pi host address or the smallest practical
subnet.

Do not expose port `4713` to untrusted networks.

## PC Receiver

Install `pactl` if needed:

```bash
sudo apt install pulseaudio-utils
```

On the Linux PC, allow the Raspberry Pi to connect. Replace the ACL with the Pi IP or LAN subnet:

```bash
./server/configure-network-audio.sh --listen --acl 192.168.1.0/24
```

This loads a temporary PipeWire/Pulse TCP listener for the current user. It does not write permanent
configuration files.

## Raspberry Pi Client

On the Raspberry Pi, connect to the PC:

```bash
./server/configure-network-audio.sh --connect-peer <PC_IP_OR_HOSTNAME>
```

This creates two local PipeWire/Pulse endpoints:

- `phonebridge_network_downlink`: a sink for Android call audio going to the PC
- `phonebridge_network_uplink`: a source for PC microphone audio coming back to the Pi

Inspect them with:

```bash
./server/configure-network-audio.sh --check
wpctl status
```

## Routing

After the tunnel endpoints exist, route the call audio in PipeWire:

- Android/HFP playback node -> `phonebridge_network_downlink`
- `phonebridge_network_uplink` -> Android/HFP capture/uplink node

For early manual testing, use `wpctl`, `pavucontrol`, `helvum`, or `qpwgraph` to inspect and link
the nodes. Permanent automatic routing should wait until the exact HFP node names are captured from
real calls.

## Cleanup

On the Raspberry Pi:

```bash
./server/configure-network-audio.sh --unload
```

On the PC, unload the listener from the current session by finding the module ID:

```bash
pactl list short modules | grep module-native-protocol-tcp
pactl unload-module <MODULE_ID>
```

## Next Implementation Step

Capture these outputs during an active call:

```bash
wpctl status
pactl list short sinks
pactl list short sources
pw-cli ls Node
```

Then add a dedicated routing helper that links the observed HFP nodes to
`phonebridge_network_downlink` and `phonebridge_network_uplink`.
