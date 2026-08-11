# Protocol v0

This describes the wire protocol between devices. It is versioned
(`X-ClipShare-Version`) and may change until v1.

## Discovery

- mDNS service type `_clipshare._tcp`
- TXT records: `name=<device name>`, `ver=0`, `key=<sha256 of TLS public key>`
- Devices refresh their announcement every 5 minutes; gone after 3 misses.
- No mDNS available? Pairing still works with a manually entered IP, syncing
  works over direct IP too (roadmap item, see internal notes).

## Pairing

Goal: two devices establish a shared secret and pin each other's TLS keys,
without a server.

1. Device A shows a 6-character pairing code (A-Z, no confusing chars).
2. Device B opens its UI, enters the code.
3. B connects to A over TLS (self-signed cert), sends `pair_request` with its
   public key.
4. Both devices derive a session secret: `HKDF(E(ECDH), code)`.
5. A shows a confirm screen with a fingerprint of B's key; B shows the same.
   Human verifies (optional, but recommended on first pairing).
6. Both store each other's public key and TLS fingerprint, marked trusted.
7. Done. Codes are single-use and expire after 2 minutes.

Unpaired devices are never accepted for clipboard traffic, only for pairing.

## Transport

- WebSocket over TLS (wss), self-signed certs generated at first run.
- The TLS key fingerprint is pinned to the trusted device list after
  pairing. First connection to a newly paired device verifies the
  fingerprint the code flow recorded.
- All messages are JSON, UTF-8, framed as WebSocket text messages.

## Messages

| Message            | Direction     | Fields |
| ------------------ | ------------- | ------ |
| `hello`            | both          | `name`, `ver`, `device_id` |
| `pair_request`     | B -> A        | `device_id`, `pubkey` |
| `pair_confirm`     | both          | `code`, `fingerprint` |
| `clipboard_update` | A -> B        | `item_id`, `kind`, `payload`, `ts` |
| `clipboard_ack`    | B -> A        | `item_id` |
| `ping` / `pong`    | both          | - |

### `clipboard_update`

- `item_id`: sha256 of the raw clipboard content, hex. Used for dedupe.
- `kind`: `text` now, `image` in v0.2, `file` later.
- `payload`: text as-is; image as base64 (PNG); files later as chunks.
- `ts`: unix ms when the source device saw the copy.
- Sender signs the message with its private key; receivers verify before
  applying.

## Sync semantics

- Watch OS clipboard, hash new content, skip if it equals the last item or an
  item already seen (dedupe by `item_id`).
- Broadcast to all connected, paired devices.
- Receiver applies only if `item_id` is unknown and the signature checks out.
- No echo: the sender ignores acks with its own `item_id`; loops are
  impossible by construction (sender never applies updates it sent).
- Ordering: per-device, per-connection, WebSocket is ordered. Cross-device
  conflicts (two copies at once) resolve to the newest `ts`.

## Limits (v0)

- Text items: 1 MB
- Image items: 20 MB (v0.2)
- History: last 50 items per device
