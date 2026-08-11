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

Any device that runs Go: Windows, macOS, Linux, Raspberry Pi, Android via
Termux. The UI is a web page, so it works in any browser, including phones.

## What clipboard types are supported?

Text in v0.1, images in v0.2, files later. See the [roadmap](roadmap.md).

## What if two devices copy at the same time?

The newest copy wins, by timestamp. Devices are not perfectly in sync during
that window, and that is acceptable: the system is eventually consistent and
never loops.

## Is it secure?

Yes by design: end-to-end encrypted between paired devices, TLS with pinned
fingerprints, pairing codes mixed into key derivation. Details in
[security.md](security.md).

## How much resources does it use?

A few MB of RAM per device, ~0% CPU when idle, tens of KB of disk. The whole
thing is one small binary.

## How do I remove a device?

Open the UI on any paired device, click remove on that device's entry. It can
no longer connect, and its entry is deleted locally.

## What happens to my history?

It lives in memory on each device (50 items by default) and is gone on
restart until v0.4 adds optional encrypted local history.

## Can I use it behind a corporate network?

Depends. Corporate networks often block mDNS discovery; the manual IP pairing
fallback (roadmap) covers that. Direct device-to-device traffic may also be
blocked by strict firewalls. Home networks are fine.

## It is open source. Who maintains it?

The maintainers of this repository. See [contributing.md](contributing.md)
for how to help and how to report issues.
