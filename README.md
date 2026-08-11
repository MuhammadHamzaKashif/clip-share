# ClipShare

A shared clipboard for all your devices. Copy on one, paste on all of them.

No cloud, no accounts, no data leaving your network. Each device runs a tiny
Go daemon, finds your other devices over the LAN, and syncs what you copy.
Think LocalSend, but just for the clipboard.

## Why

You sit with a laptop, a PC and a phone on the same desk. You copy a link on
the PC, a token on the laptop, a code on the phone. Emailing yourself is slow,
cloud clipboards spy on your data. ClipShare just syncs the clipboard between
devices you own, directly, no middleman.

## Features

- Text sync in v0.1, images in v0.2, files later
- Pair with a short code, only your devices connect
- End-to-end encrypted between devices
- Auto-connect on start, or sync only when you press start
- One small binary per device, web UI included
- Self-hosted, runs on anything that runs Go

## Quick start

Coming with v0.1. For now, see [Setup](docs/setup.md) for what's planned.

## Docs

- [Architecture](docs/architecture.md) - how it fits together
- [Setup](docs/setup.md) - install and run it yourself
- [Protocol](docs/protocol.md) - the wire protocol
- [Security](docs/security.md) - threat model and encryption
- [Design](docs/design.md) - UI and UX direction
- [Roadmap](docs/roadmap.md) - what ships when
- [FAQ](docs/faq.md) - common questions
- [Contributing](docs/contributing.md) - help out

## License

[MIT](LICENSE)
