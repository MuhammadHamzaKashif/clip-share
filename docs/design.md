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

## Layout (v0)

Centered column (max 640 px), left-aligned content. The window is resizable
but the column stays fixed to keep the density readable.

```
+-----------------------------------------------+
|  ClipShare          [status] [name]  [gear]   |
|                                               |
|  DEVICES                                      |
|  +-----------------------------------------+  |
|  | [icon]  No devices yet                  |  |
|  | Pair your laptop or phone to build      |  |
|  | your shared clipboard.                  |  |
|  +-----------------------------------------+  |
|                                               |
|  [  Start sync  ]     [ Pair device ]         |
|                                               |
|  RECENT                                     3 |
|  ──────────────────────────────────────────── |
|  07:42  laptop   https://example.com/some..  |
|  07:40  phone    const answer = 42;          |
|  07:35  pc       image · 2 KB                |
|  ──────────────────────────────────────────── |
|  sync on  ·  history: 50 items               |
+-----------------------------------------------+
```

### Header

Left: app wordmark. Right: status chip (pulsing green dot + "syncing" when
active; muted dot + "idle" when not), device name in mono, settings icon.

### Devices

Section label in small-caps mono. When no devices are paired: a composed
empty state ( icon-in-circle + "No devices yet" + explanatory subtext) in a
soft-border card. When devices are discovered: rows with a green/outline
status dot, name, and "connected" / "nearby" mono label.

### Actions

Two buttons: "Start sync" / "Stop sync" (filled pill, accent), "Pair device"
(outlined pill). AnimatedSwitcher swaps the label and icon.

### History

Section label with an item count right-aligned. Rows: mono time + accent
source + content (or image thumbnail + KB/MB), trailing copy icon. Tapping
any row copies it back to the clipboard. Hairline dividers between rows.
Empty state: centered "Nothing here yet" with explanatory subtext.

### Footer

Mono: `sync on` / `sync off` and `history: 50 items`.

## Mobile layout (v0)

Same column structure, narrower padding, thumb-friendly rows. The device list
is top-level, not buried in a menu.

## Tray (desktop)

- Icon only, no text, monochrome-friendly so it works with dark taskbars.
- Menu: Open (launch app), Quit (exit). Full tray menu comes with proper
  native tray support in v1.
- Start at login: a setting that writes to the OS autostart location so the
  app is there when you boot.

## Colors

- Light mode: near-white background (#FAFAF9), near-black text (#18181B),
  desaturated teal accent (#0D9488).
- Dark mode: near-black background (#0C0C0E), near-white text (#F4F4F5),
  bright teal accent (#2DD4BF). Follows the system theme, no toggle needed.
- Connected status: green (#16A34A / #4ADE80). Muted labels: zinc-500.
- All backgrounds are off-values (no pure black/white). Shadows are tinted.

## Typography

- Bundled Geist (sans) and Geist Mono (monospace), variable TTFs, ~340 KB
  total. Loaded as Flutter assets, no network font downloads.
- Base 14 px, line height 1.5. Headings use Geist weight 600, tracked tight
  (-0.5). Body uses default 400.
- Timestamps, device names, section labels, footer status in Geist Mono.
  Section labels ("DEVICES", "RECENT") set in small-caps mono, letter-
  spaced.

## Interaction

- Pairing: choose mode (show code / enter code). Code shown in a bordered
  mono box with a pulsing dot. Enter code: pick device from discovered list,
  type the 6-character code.
- Start sync: one button. Auto-connect is a settings toggle for people who
  want zero interaction.
- A synced item is copied back by tapping it.
- Desktop: clicking the tray icon launches the app.
- Receiving a new item while the window is closed: a quiet system
  notification, nothing more.

## Non-goals (v0)

- No browser version, no embedded web page. The app is the app. (A
  separate, optional terminal client exists for people who want no UI at
  all; it is documented in setup.md, not designed here.)
- No animations beyond simple fades and the status dot pulse. Motion is a
  signal, not decoration.
- No settings maze: settings stay at five controls or fewer; anything more
  belongs in a later release.
