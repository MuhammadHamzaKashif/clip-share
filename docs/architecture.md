# Architecture

ClipShare is peer-to-peer. There is no central server. Every device runs the
same app and talks directly to the other devices you paired with, over your
own network.

```
   +----------+   mDNS find peers   +----------+
   |  laptop  | <-----------------> |    PC    |
   |  app     |                     |  app     |
   +----------+                     +----------+
        ^  ^                              ^  ^
        |  | encrypted clipboard sync     |  |
        |  +---------------------+--------+  |
        |                        |           |
   +----+----+             +----+----+       |
   |  phone  |             |  Pi    |       |
   |  app    |             |  app   |       |
   +---------+             +--------+       |
                                            (all on the same LAN)
```

## The app

One codebase, one app, real native builds for every platform:

- **Windows, macOS, Linux**: a desktop app with a system tray icon. Lives in
  the tray, syncs in the background, shows a small window when you open it.
- **Android, iOS**: native mobile apps, same codebase.
- The app holds everything: UI, clipboard watching, discovery, pairing,
  sync, crypto. No daemon, no helper process, nothing extra to install.

## Components

- **App UI** - the clipboard screen: your device name, paired/connected
  devices, pair button, start/stop sync, recent items. Same design language
  on desktop and mobile, adapted to each screen.
- **Tray (desktop)** - icon in the system tray. Open the window, toggle sync,
  quit. Optionally starts hidden at login so it syncs without any window.
- **Discovery** - mDNS (zeroconf). Devices announce themselves as
  `_clipshare._tcp` on the LAN. When a device comes online it finds the
  others automatically. No config, no server.
- **Pairing** - one short code shown on a device, typed into another. After
  pairing, the two devices trust each other permanently until removed.
- **Sync engine** - watches the clipboard, dedupes by hash, broadcasts new
  items to connected devices over an encrypted channel.
- **Identity store** - a local file (keypair + device list + pairing
  secrets). Stays on the device, never leaves it.
- **Clipboard bridge** - per-OS glue between the app and the system
  clipboard: watching for changes and writing items back.

## The terminal client

A separate, optional tool for people who want the absolute minimum: a tiny
terminal program that does the same clipboard sync, no UI at all.

- One small static binary (a few MB), single-digit MB of RAM, ~0% CPU idle.
- Sits in the terminal or runs as a background process; same pairing, same
  encryption, same protocol as the app.
- No window, no tray, no browser. It watches the clipboard, syncs, prints a
  line when something arrives.
- Installed only if wanted; it is never required by the app and the two
  coexist fine on one machine (they share the same wire protocol and the
  dedupe keeps them from echoing each other).

## Why this shape

- **One codebase, six platforms.** Desktop tray apps and mobile apps are
  built once, not per OS. UI, sync and crypto logic are shared, so behavior
  is identical everywhere.
- **Native, not a browser.** A real app with a tray icon, system
  notifications and clipboard access. No browser tab, no port, no page to
  keep open.
- **Light enough.** A release build is a normal-size app; idle CPU is ~0% and
  it sleeps quietly in the tray. Nothing like a browser engine sitting
  around.
- **Few dependencies.** The networking, TLS and crypto we need come from
  well-maintained packages; everything else is app code.

## Resource friendliness

Keeping the app as light as the UI allows is a standing requirement:

- Only ship release builds; the debug engine is for development only.
- No heavy third-party plugins beyond the few we need (clipboard, tray,
  discovery). Each new dependency is argued for first.
- No bundled fonts, no bundled assets beyond icons. System fonts only.
- Images in the history are held as small thumbnails, never as full-size
  buffers.
- One background isolate for sync work; nothing runs when the app is not
  syncing.
- The terminal client exists precisely for users who want even less: no UI
  runtime at all.

## Why P2P over a hosted server

A hosted relay adds hops and latency and stores your data. On the LAN,
devices are a few milliseconds apart and clipboard content never leaves your
network. Sync over the internet is a later milestone, likely via an optional
encrypted relay that cannot read the content.

## Directory layout (planned)

```
clip-share/
  app/                  the Flutter app, all platforms
    lib/
      ui/               screens, widgets, theme
      discovery/        mDNS
      pairing/          pairing code flow
      sync/             sync engine and dedupe
      crypto/           keys, encrypt/decrypt
      platform/         clipboard + tray bridges per OS
      models/           shared types
    android/  ios/  windows/  macos/  linux/
  cli/                  the optional terminal client
  docs/                 public docs
  docs-internal/        internal notes, not committed
```

## Data flow, one copy

1. The app on device A notices the OS clipboard changed.
2. It hashes the content, checks it is not already synced.
3. It encrypts and sends `clipboard_update` to every connected, paired
   device over the encrypted channel.
4. Device B verifies the sender, decrypts, and writes it to its own
   clipboard, which also updates the OS clipboard if allowed.
5. Device B sends an ack. No echo back to A (dedupe), no loop.
