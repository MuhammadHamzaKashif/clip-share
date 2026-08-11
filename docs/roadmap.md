# Roadmap

Simple milestones, each one shippable on its own. Text first, images next,
files after. Everything stays minimal and self-hosted.

## v0.1 - text sync (current target)

The core loop works end to end.

- [x] Docs: architecture, setup, protocol, security, design
- [ ] clipd skeleton: identity, config, web UI
- [ ] mDNS discovery, manual IP fallback
- [ ] Pairing with 6-char codes
- [ ] Clipboard watching (text), hash dedupe
- [ ] Encrypted sync between two devices
- [ ] Web UI: device list, pair, start/stop, recent items
- [ ] Windows + macOS + Linux builds

**Done when:** copy a URL on the PC, paste it on the phone, both on the same
Wi-Fi.

## v0.2 - images

- [ ] Image clipboard items (PNG), resize/compress on the wire
- [ ] Thumbnails in the UI history
- [ ] Size limits and quota guardrails
- [ ] Image items on phones via the web UI

**Done when:** screenshot on the laptop shows up on the phone, readable and
fast.

## v0.3 - files (later)

- [ ] File items with chunked transfer and resume
- [ ] Receive folder handling and conflict naming
- [ ] Progress in the UI

**Done when:** drag a file in a browser tab on one device, get it on another.

## v0.4 - making it comfortable

- [ ] Encrypted local history persisted to disk
- [ ] Pinned items (never rotate out of history)
- [ ] Notifications on receive (OS-level)
- [ ] First-run name selection, device rename

## v1.0 - hardening

- [ ] Protocol v1 freeze
- [ ] Full audit of crypto + review checklist from security doc
- [ ] Windows installer, macOS bundle, Linux packages
- [ ] Test matrix: mixed OS devices, high copy rates, flaky Wi-Fi

## Beyond v1

- Optional encrypted relay for devices on different networks (phone on
  mobile data), with content unreadable by the relay
- Android/iOS native apps wrapping the same protocol
- Clipboard history search

## Guiding constraints, always

- A single binary, minimal resources, no data leaving the LAN by default
- No accounts, no telemetry, no cloud, no lock-in
- Every feature earns its place: if it adds complexity without daily value,
  it waits
