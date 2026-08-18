# FAQ

## What is ClipShare?

A shared clipboard for devices you own. Copy on one device, paste on the
others, all over your local network. No cloud involved.

## How is this different from a cloud clipboard (KDE Connect, Windows Cloud Clipboard, etc.)?

Those route your clipboard through a cloud service or require an account, and
your data passes through (or is stored on) servers you do not control.
ClipShare sends clipboard items directly between your devices, encrypted,
over your own LAN. When the network is off, nothing syncs and nothing is
stored anywhere else.

## Do I need an account?

No. You pair devices with a short code, once. That is it.

## Does my clipboard data leave my network?

No. Devices sync directly over the LAN. Remote sync is only planned as an
opt-in, encrypted relay that cannot read the content.

## Does it work over the internet?

Not yet. Both devices need to be on the same LAN. See the roadmap for the
opt-in relay.

## Which platforms are supported?

Real native apps: Windows, macOS and Linux on desktop, Android (and iOS
later). Same app everywhere, no browser needed.

## What clipboard types are supported?

Text and images now, files later. Images are resized to 1600 px on the wire.
See the [roadmap](roadmap.md).

## What if two devices copy at the same time?

The newest copy wins, by timestamp. Devices are not perfectly in sync during
that window, and that is acceptable: the system is eventually consistent and
never loops.

## Is it secure?

Yes by design: end-to-end encrypted between paired devices, TLS with pinned
fingerprints, pairing codes mixed into key derivation. Details in
[security.md](security.md).

## How much resources does it use?

A normal-size native app: a few tens of MB of RAM on desktop, less when
backgrounded, ~0% CPU when idle, and tiny disk usage (keys, settings, a
small history file). No browser engine sitting around.

## How do I remove a device?

Open the app on any paired device, tap remove on that device's entry. It can
no longer connect, and its entry is deleted locally.

## What happens to my history?

It lives in memory on each device (50 items by default) and is gone on
restart until v0.4 adds optional encrypted local history.

## I want even less than an app. Is there a terminal version?

Yes. An optional terminal client does the same sync with no UI at all: one
small binary, `pair` once, `watch` and it runs. See the [setup](setup.md)
page.

## Can I use it behind a corporate network?

Depends. Corporate networks often block mDNS discovery; the manual IP pairing
fallback (roadmap) covers that. Direct device-to-device traffic may also be
blocked by strict firewalls. Home networks are fine.

## It is open source. Who maintains it?

The maintainers of this repository. See [contributing.md](contributing.md)
for how to help and how to report issues.
