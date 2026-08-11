# Roadmap

Simple milestones, each one shippable on its own. Text first, images next,
files after. Everything stays peer-to-peer and self-hosted.

## v0.1 - text sync (current target)

The core loop works end to end on real apps.

- [x] Docs: architecture, setup, protocol, security, design
- [ ] App skeleton: Flutter app, theme, device name flow
- [ ] mDNS discovery, manual IP fallback
- [ ] Pairing with 6-char codes
- [ ] Clipboard watching (text), hash dedupe
- [ ] Encrypted sync between two devices
- [ ] App UI: device list, pair, start/stop, recent items
- [ ] Tray icon + start at login (desktop)
- [ ] Terminal client: `pair` + `watch`, same protocol, minimal binary
- [ ] Windows + Linux + Android builds (macOS and iOS need signing setup,
      they follow in v0.2)

**Done when:** copy a URL on the PC, paste it on the phone, both on the same
Wi-Fi.

## v0.2 - images, plus the Apple platforms

- [ ] Image clipboard items (PNG), resize/compress on the wire
- [ ] Thumbnails in the history
- [ ] Size limits and quota guardrails
- [ ] macOS + iOS builds, signing and notarization setup

**Done when:** screenshot on the laptop shows up on the phone, readable and
fast.

## v0.3 - files (later)

- [ ] File items with chunked transfer and resume
- [ ] Receive folder handling and conflict naming
- [ ] Progress in the UI

**Done when:** drop a file on one device, get it on another.

## v0.4 - making it comfortable

- [ ] Encrypted local history persisted to disk
- [ ] Pinned items (never rotate out of history)
- [ ] Notifications on receive with quick actions
- [ ] Device rename, first-run polish

## v1.0 - hardening

- [ ] Protocol v1 freeze
- [ ] Full audit of crypto + review checklist from security doc
- [ ] Signed installers for Windows, macOS, Linux packages, Play Store /
      App Store pages
- [ ] Test matrix: mixed OS devices, high copy rates, flaky Wi-Fi

## Beyond v1

- Optional encrypted relay for devices on different networks (phone on
  mobile data), with content unreadable by the relay
- Clipboard history search
- Snippets: saved, pinned, reusable items

## Guiding constraints, always

- Peer-to-peer by default, no data leaving the LAN by default
- No accounts, no telemetry, no cloud, no lock-in
- Every feature earns its place: if it adds complexity without daily value,
  it waits
