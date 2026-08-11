# Security

ClipShare is designed so that the people who run it are the only people who
can read the data in it. This page states the threat model, what we do, and
what we never do.

## Design stance

- No cloud, no accounts, no telemetry, no analytics, no third-party SDKs.
- Clipboard content only travels device to device over the LAN, encrypted.
- All secrets live on your devices, in files only your user can read.
- The project is open source. The crypto is standard library only (Go's
  `crypto/` packages), so it can be audited by anyone.

## Threat model

In scope (we protect against):

- A stranger on the same Wi-Fi capturing traffic.
- Rogue apps on your LAN trying to connect as a device.
- An attacker with the ability to sniff, not alter, first-pairing traffic
  (the pairing code protects against that, see below).

Out of scope (assumed trusted):

- Physical access to your device while unlocked.
- Malware already running on your device with your user permissions.
- The operator of your router or network admin (same LAN, same trust level).

## Encryption

- Pairing: ECDH (P-256) key exchange hardened by the pairing code. An
  attacker who records the pairing exchange but does not know the code
  cannot derive the pairing key (the code is never sent, it is mixed into
  the key derivation and proven with an HMAC).
- In transit: every message payload is AES-256-GCM encrypted with a session
  key derived from ECDH + HKDF. The sender's device id is bound into the
  authenticated data, so a message cannot be replayed onto another device.
  After pairing, a stranger on the network sees only ciphertext.
- At rest: the identity keypair and device list are stored locally. The
  clipboard history in the UI is held in memory only (see Roadmap for
  encrypted history).
- TLS on the wire is planned for v1 hardening; application-layer encryption
  is the v0.1 guarantee.

## Pairing code rules

- 6 characters, unambiguous alphabet (no O/0, I/1).
- Single use, 2 minute expiry, rate limited (5 tries per 10 minutes).
- The code never crosses the network; it is only typed by a human.

## Data stored

Per device, locally:

- Identity keypair (private key never leaves the device)
- Device list with public keys and TLS fingerprints
- Small clipboard history (in memory by default)

Nothing is stored anywhere else. Deleting the data folder removes every trace.

## Compliance notes

- **Self-hosted**: you are the data controller and processor. ClipShare the
  project holds nothing: no accounts, no clipboard data, no usage stats.
- **GDPR-friendly**: no personal data leaves the LAN. If you delete the data
  folder, your clipboard history is gone. There is no remote copy to request
  deletion from.
- **No trackers**: no fingerprinting, no analytics, no crash reporting to
  third parties.

## Reporting vulnerabilities

Email the maintainer (see CONTRIBUTING) or open a security issue privately on
GitHub. Do not create a public issue for an active vulnerability. We aim to
respond within 48 hours.

## Verification checklist (for reviewers)

- [ ] Pairing code participates in key derivation and is proven via HMAC
- [ ] All messages from unpaired peers are rejected
- [ ] Message payloads are AES-256-GCM encrypted with ECDH-derived keys
- [ ] Encrypted payloads bind the sender device id as authenticated data
- [ ] No clipboard content is ever logged
- [ ] History is bounded (50 items) and purgeable
