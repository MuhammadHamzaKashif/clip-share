# Setup

ClipShare is self-hosted: you install the app on each device you own.
Nothing is installed elsewhere, nothing runs in a cloud you do not control.

## Requirements

- **Desktop**: Windows 10+, macOS 11+, or Linux (any distro with a
  compatible Flutter build)
- **Mobile**: Android 8+, iOS 13+ (iOS builds ship once we have a Mac build
  setup)
- All devices on the same LAN (for now)
- mDNS allowed on the network (home routers allow it; corporate networks may
  block it, then discovery falls back to manual IPs later)

## Install

Grab the app for each platform from the releases page (or build from source,
see Contributing):

- Windows: installer or portable zip
- macOS: DMG
- Linux: AppImage / deb
- Android: APK

Install it on every device you want in the shared clipboard. That is the
whole install. No server, no accounts, no extra packages.

## First run

1. The app asks for a device name (you can rename it later). Something like
   "my laptop" helps you recognize devices in the list.
2. It generates its identity keys and starts looking for other devices on
   the network.
3. It sits in the tray (desktop) or in the background (mobile). Open the
   window to see what it found.

## Pair your devices

1. On device A, open the app, press "Pair device". A 6-character code shows.
2. On device B, open the app, press "Pair device", type A's code, confirm
   the fingerprint shown on both screens.
3. Done. A and B trust each other now. Repeat for every device you want in
   the shared clipboard.

Paired devices show up in the app. Remove a device anytime; it can no longer
connect.

## Sync

- Default: sync starts manually with the "Start sync" button.
- Want it automatic? Turn on "Start sync at launch" in settings. From then
  on the app connects to paired devices the moment it starts, no clicks.

## Settings

- `Device name`
- `Start sync at launch` - auto-connect on start (default off)
- `Start at login` - desktop only; app starts hidden in the tray
- `Apply received items` - write synced items into the local OS clipboard,
  or only keep them in the app history
- `History size` - how many items to keep (default 50, 0 to disable)

## Terminal client (optional)

Prefer the bare minimum over any UI? Install the terminal client instead of
or next to the app.

```sh
# download the binary for your OS from the releases page, then:
clipshare pair          # shows your code or lets you enter one
clipshare watch         # run in the terminal: syncs in the foreground
clipshare watch --quiet # background-friendly: no output, exit codes only
```

Same pairing, same devices, same encryption as the app. It prints a line
when a new item arrives. Both can run on the same machine; the hash dedupe
keeps them from echoing each other.

## Firewall / network notes

- Allow the app through the firewall on private networks (the installer
  usually asks; Windows: make sure the network is set to "private").
- If devices are not visible, check the router: AP isolation (often on
  guest networks) blocks device-to-device traffic and must be off.
- Phone finding the desktop but not the other way? Check the local network
  permission for the app in the OS privacy settings.

## Running 24/7 (recommended)

The syncing device should stay on. Pick the one that is always powered, turn
on "Start at login", and it quietly does the job from the tray.

## Sizing notes

- Memory: a normal-size native app; a few tens of MB on desktop while open,
  less when backgrounded. No browser engine in sight. The terminal client is
  a few MB of RAM, single digits.
- CPU: ~0% when idle, active only for a moment during a copy.
- Disk: identity keys, settings and a small history file; tens of KB before
  image items, still small after.
