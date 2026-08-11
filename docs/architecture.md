# Architecture

ClipShare is peer-to-peer, like LocalSend. There is no central server. Every
device runs the same small binary and talks directly to the other devices you
paired with.

```
   +----------+   mDNS find peers   +----------+
   |  laptop  | <-----------------> |    PC    |
   |  clipd   |                     |  clipd   |
   +----------+                     +----------+
        ^  ^                              ^  ^
        |  | encrypted clipboard sync     |  |
        |  +---------------------+--------+  |
        |                        |           |
   +----+----+             +----+----+       |
   |  phone  |             |  Pi    |       |
   |  clipd  |             |  clipd |       |
   +---------+             +--------+       |
                                            (all on the same LAN)
```

## Components

- **clipd** - the daemon. One Go binary. Watches the local clipboard,
  discovers peers, syncs clipboard items, serves the web UI.
- **Local web UI** - a single-page app served by clipd on
  `http://localhost:PORT`. Use it to pair devices, see connected devices,
  start/stop syncing, and view the recent clipboard items. Works from the
  phone's browser too, so no native app is needed for v0.
- **Identity store** - a local file (keypair + device list + pairing secrets).
  Stays on the device, never leaves it.
- **Discovery** - mDNS (zeroconf). Devices announce themselves as
  `_clipshare._tcp` on the LAN. When a device comes online it finds the others
  automatically. No config, no server.
- **Pairing** - one short code shown on a device, typed into another. After
  pairing, the two devices trust each other permanently until removed.
- **Sync engine** - watches the clipboard, dedupes by hash, broadcasts new
  items to connected devices over an encrypted channel.

## Why Go

- Single static binary, a few MB, tiny memory and CPU footprint. Fits the
  minimal-resources requirement.
- Standard library covers HTTP, TLS, WebSocket, crypto, JSON. Few
  dependencies, easy to audit.
- Cross-compiles to Windows, macOS, Linux, and ARM boards with one command.

## Why P2P over a hosted server

A hosted relay adds hops and latency and stores your data. On the LAN, devices
are a few milliseconds apart and clipboard content never leaves your network.
Remote sync (phone on mobile data) is a later milestone, likely via an
optional encrypted relay, never through a service that can read the content.

## Directory layout (planned)

```
clip-share/
  cmd/clipd/        main entrypoint
  internal/
    discovery/      mDNS
    pairing/        pairing code flow
    sync/           sync engine and dedupe
    crypto/         keys, encrypt/decrypt
    clipboard/      OS clipboard watching
    web/            embedded web UI
  docs/             public docs
  docs-internal/    internal notes, not committed
```

## Data flow, one copy

1. clipd on device A notices the OS clipboard changed.
2. It hashes the content, checks it is not already synced.
3. It encrypts and sends `clipboard_update` to every connected, paired
   device over the encrypted channel.
4. Device B verifies the sender, decrypts, and writes it to its own
   clipboard, which also updates the OS clipboard if allowed.
5. Device B sends an ack. No echo back to A (dedupe), no loop.
