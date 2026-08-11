# Design

ClipShare should feel invisible. On desktop it lives in the tray and only
shows a window when you want it. On mobile it is a small app that waits in
the background. It appears when you copy something.

## Principles

- **Quiet.** No splash screens, no onboarding wizards. First run asks for a
  device name, then shows three things: your device, the pair button, and
  the list of connected devices.
- **Fast.** The app opens instantly. The main screen shows connected devices
  and recent items with no loading spinners; the local state is always
  there, network state updates in the background.
- **Honest.** A clipboard tool that asks for extra permissions or shows ads
  is suspicious. The app states plainly what is connected and what was
  synced.
- **Minimal, not bare.** Whitespace over decoration, two or three neutral
  tones plus one accent, readable typography, no gradients, no heavy
  shadows, no emoji as icons.

## Desktop layout (v0)

A small, resizable window. Tray icon with a menu: open window, toggle sync,
quit. Closing the window hides to the tray; real quit is via the tray.

```
+-----------------------------------------------+
|  ClipShare                       [device name] |
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
|  sync: on  |  history: 50 items               |
+-----------------------------------------------+
```

## Mobile layout (v0)

Same information, one screen, thumb-friendly rows. Tapping a recent item
copies it back to the clipboard. The device list is top-level, not buried in
a menu.

```
+----------------------+
|  ClipShare       [..] |
|  laptop     connected |
|  pc         connected |
|  phone      this      |
|  [ Pair ]  [ sync on ]|
|                      |
|  Recent items        |
|  07:42 laptop  URL    |
|  07:40 phone  code    |
+----------------------+
```

## Tray (desktop)

- Icon only, no text, monochrome-friendly so it works with dark taskbars.
- Menu: Open, Start/Stop sync, Settings, Quit.
- Start at login: a setting, so the app is there when you boot without
  asking anything.

## Colors

- Light mode: near-white background, near-black text, one muted accent
  (e.g. a desaturated indigo or teal).
- Dark mode: near-black background, near-white text, same accent slightly
  lifted. Follows the system theme, no toggle needed in v0.
- Status colors used sparingly: green for connected, amber for starting.

## Typography

- System fonts only, no bundled webfonts. Keeps the app small.
- Base 16 px, line height 1.5. Headings tight (1.2), tracked slightly.
- Numbers, timestamps and device names in a monospace face for scannability.

## Interaction

- Pairing: one screen, type the code, press pair. Confirm fingerprint.
- Start sync: one button. Auto-connect is a settings toggle for people who
  want zero interaction.
- A synced item is copied back by tapping it.
- Desktop: clicking the tray icon opens the window in under 150 ms.
- Receiving a new item while the window is closed: a quiet system
  notification, nothing more.

## Non-goals (v0)

- No browser version, no embedded web page. The app is the app. (A
  separate, optional terminal client exists for people who want no UI at
  all; it is documented in setup.md, not designed here.)
- No animations beyond simple fades. Motion is a signal, not decoration.
- No settings maze: settings stay at five controls or fewer; anything more
  belongs in a later release.
