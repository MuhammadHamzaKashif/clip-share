# Roadmap

Simple milestones, each one shippable on its own. Text first, images next,
files after. Everything stays peer-to-peer and self-hosted.

## v0.1 - text sync (current target)

The core loop works end to end on real apps.

- [x] Docs: architecture, setup, protocol, security, design
- [x] App skeleton: Flutter app, theme, device name flow
- [x] mDNS discovery, manual IP fallback (manual IP not yet)
- [x] Pairing with 6-char codes
- [x] Clipboard watching (text), hash dedupe
- [x] Encrypted sync between two devices (AES-GCM over ECDH keys)
- [x] App UI: device list, pair, start/stop, recent items
- [x] Tray icon + start at login (desktop; tray via a small OS helper for now,
      native tray plugin planned with signing work)
- [x] Terminal client: `pair` + `watch`, same protocol, minimal binary
- [x] Windows build (Linux and Android builds follow; macOS/iOS need
      signing setup)
- [x] Android build (signed APK at app/build/app/outputs/flutter-apk/)

**Done when:** copy a URL on the PC, paste it on the phone, both on the same
Wi-Fi.

## v0.2 - images, plus the Apple platforms

- [x] Image clipboard items (PNG), resize/compress on the wire
- [x] Thumbnails in the history
- [x] Size limits and quota guardrails
- [ ] macOS + iOS builds, signing and notarization setup

**Done when:** screenshot on the laptop shows up on the phone, readable and
fast. (Windows side done; Linux/macOS image clipboard support is limited by
platform tooling and follows with the builds.)

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
