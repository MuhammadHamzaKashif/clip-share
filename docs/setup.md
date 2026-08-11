# Setup

ClipShare is self-hosted: you run one copy per device, on your own machines.
Nothing is installed elsewhere, nothing runs in a cloud you do not control.

## Requirements

- Any device that runs Go 1.22+ (Windows, macOS, Linux, Raspberry Pi, Android
  via Termux)
- All devices on the same LAN (for now)
- mDNS allowed on the network (home routers allow it; corporate networks may
  block it, that is fine, then discovery can fall back to manual IPs later)

## Build from source

```sh
git clone https://github.com/MuhammadHamzaKashif/clip-share.git
cd clip-share
go build -o clipshare ./cmd/clipd
```

That is the whole thing. A few MB, no dependencies to install.

## Run it for the first time

```sh
./clipshare
```

On first run clipd:

1. Generates an identity keypair and a device name (you can rename it later).
2. Starts the discovery service and the web UI.
3. Prints the local UI address, usually `http://localhost:PORT`.

Open that address in a browser. Bookmark it.

## Pair your second device

1. Run clipshare on the second device the same way.
2. Open its UI, click "Pair device", pick the first device from the list that
   appears, and enter the pairing code the first device shows.
3. Done. Both devices now trust each other. Repeat for every device you want
   in the shared clipboard.

Paired devices show up in the UI. Remove a device anytime; it can no longer
connect.

## Config

Everything lives in `clipshare.yaml` next to the binary (or
`~/.config/clipshare/`). Defaults work out of the box, but you can set:

- `port` - web UI port
- `autoconnect` - connect to paired devices on start, default off, or set
  "on" if you always want instant sync
- `devicename` - how the device shows up to others
- `apply-on-receive` - write synced items into the local OS clipboard, or
  only keep them in the UI history
- `history` - how many items to keep in the UI (default 50, 0 to disable)

## Running 24/7 (recommended)

The syncing device should stay on. Pick the one that is always powered:

- **Windows**: run clipshare as a startup task, minimize to tray.
- **macOS**: add a launchd agent or a login item.
- **Linux**: systemd unit, see below.
- **Raspberry Pi / always-on box**: systemd, run headless, no screen needed.

```ini
# /etc/systemd/system/clipshare.service
[Unit]
Description=ClipShare daemon
After=network-online.target

[Service]
ExecStart=/home/pi/clipshare
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## Sizing notes

- Memory: single-digit MB per daemon.
- CPU: idle at ~0%, only active for a moment during a copy.
- Disk: keypair plus a small history file, tens of KB, grows slowly with
  image items.
