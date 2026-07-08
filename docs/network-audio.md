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

The default tunnel format is `s16le`, mono, `16000Hz`, with `80ms` target latency. This matches
typical HFP wideband speech better than the PipeWire/Pulse default `48000Hz` stereo tunnel and
avoids unnecessary resampling for calls.

To tune it manually:

```bash
./server/configure-network-audio.sh --connect-peer <PC_IP_OR_HOSTNAME> --rate 16000 --channels 1 --latency-ms 80
```

Inspect them with:

```bash
./server/configure-network-audio.sh --check
wpctl status
```

## Routing

After the tunnel endpoints exist, route the call audio in PipeWire:

- Android/HFP playback node -> `phonebridge_network_downlink`
- `phonebridge_network_uplink` -> Android/HFP capture/uplink node

During an active call on the Raspberry Pi, run:

```bash
./server/configure-network-audio.sh --route-call
```

This moves current `pactl` sink inputs to `phonebridge_network_downlink` and current source outputs
to `phonebridge_network_uplink`.

To avoid running a command for each call, keep a watcher running on the Raspberry Pi after
`--connect-peer`:

```bash
./server/configure-network-audio.sh --watch-route
```

The watcher checks every two seconds and moves Bluetooth `bluez_*` call streams to the network
endpoints when they appear.

## User Service

After the tunnel flow is validated, install the watcher as a systemd user service on the Raspberry
Pi:

```bash
./server/install-network-audio-service.sh --peer <PC_IP_OR_HOSTNAME> --enable --start --status
```

The service uses the same default tunnel format: `16000Hz`, mono, `80ms`.

This writes:

- `~/.config/systemd/user/phonebridge-network-audio.service`
- `~/.config/phonebridge-server/network-audio.env`

The service runs:

```bash
./server/configure-network-audio.sh --serve-peer <PC_IP_OR_HOSTNAME>
```

It ensures the tunnel endpoints exist, then keeps the call-routing watcher active.

To inspect or restart it:

```bash
systemctl --user status phonebridge-network-audio.service
systemctl --user restart phonebridge-network-audio.service
journalctl --user -u phonebridge-network-audio.service -f
```

For a headless Raspberry Pi where the service must run before an interactive login, enable user
lingering once:

```bash
sudo loginctl enable-linger "$USER"
```

For manual testing, inspect the active stream IDs:

```bash
pactl list short sink-inputs
pactl list short source-outputs
```

Then move them explicitly:

```bash
pactl move-sink-input <SINK_INPUT_ID> phonebridge_network_downlink
pactl move-source-output <SOURCE_OUTPUT_ID> phonebridge_network_uplink
```

You can also use `wpctl`, `pavucontrol`, `helvum`, or `qpwgraph` to inspect and link the nodes.

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
