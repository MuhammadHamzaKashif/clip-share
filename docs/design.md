# Design

ClipShare should feel invisible. It lives in the corner of your workflow and
only appears when you copy something. The UI is a single web page served by
each device, usable from any browser, including the phone.

## Principles

- **Quiet.** No splash screens, no onboarding wizards. First run shows three
  things: your device name, the pair button, and the list of connected
  devices.
- **Fast.** The page is one HTML file with inline CSS and JS, no framework,
  no network calls beyond the local daemon. Loads in milliseconds even on a
  phone.
- **Honest.** A clipboard tool that asks for permissions or shows ads is
  suspicious. The UI states plainly what is connected and what was synced.
- **Minimal, not bare.** Follows the taste standards: whitespace over
  decoration, two or three neutral tones plus one accent, readable
  typography, no gradients, no heavy shadows, no emoji as icons.

## Layout (v0)

```
+-----------------------------------------------+
|  ClipShare                  [device name] [..] |
|  connected: laptop, pc, phone        (4 dots)  |
|                                               |
|  [ Pair device ]        [ Start sync / stop ] |
|                                               |
|  Recent clipboard items                       |
|  +-----------------------------------------+  |
|  | 07:42  laptop   https://example.com/..  |  |
|  | 07:40  phone    some code snippet        |  |
|  | 07:35  pc       image (42 KB)            |  |
|  +-----------------------------------------+  |
|                                               |
|  this device:  on  |  history: 50 items       |
+-----------------------------------------------+
```

## Colors

- Light mode: near-white background, near-black text, one muted accent
  (e.g. a desaturated indigo or teal).
- Dark mode: near-black background, near-white text, same accent slightly
  lifted. Auto-detects the system preference, no toggle needed in v0.
- Status colors used sparingly: green for connected, amber for starting.

## Typography

- System font stack (UI system fonts), no webfont downloads, keeps it light.
- Base 16 px, line height 1.5. Headings tight (1.2), tracked slightly.
- Numbers, timestamps and device names in a monospace face for scannability.

## Interaction

- Pairing: one screen, type the code, press pair. Confirm fingerprint.
- Start sync: one button. Auto-connect is a settings toggle for people who
  want zero interaction.
- A synced item is copied back by tapping it (applies to the OS clipboard if
  allowed).
- Every action gives feedback in under 150 ms, locally. Nothing on the page
  waits on the network except the device list refresh.

## Non-goals (v0)

- No native mobile app yet; the web UI covers it.
- No animations beyond simple fades. Motion is a signal, not decoration.
- No settings maze: the config file is the power-user escape hatch, the UI
  stays at five controls or fewer.
