# Troubleshooting

## I cannot see the divider

- **Another item covers it.** Overlays such as a "software island" pill in the
  middle of the bar can draw over status items. ⌘-drag the divider to a free
  spot, or use **Hidden icons − / +** or **Reset Divider Position** in the menu.
- **The bar is full.** If the divider itself sits far left, macOS may put it
  out of the bar. Quit Komora, run `defaults delete dev.komora.Komora`, and
  reopen it. If that does not help, ⌘-drag icons to make room.
- **It is on the other display.** Each display has its own copy of the bar. On
  a narrow display macOS fits fewer icons, so the divider can be out of the bar
  there.

## Icons stay visible after a collapse

Open the divider's menu and read the last line.

- **"Last collapse: an icon may sit next to the divider"** — Komora's check
  found a gap in the pusher chain. Collapse again: Komora retries with new
  pusher names and re-reads the divider's place. If it keeps failing, ⌘-drag
  the divider one place and back, then collapse.
- **"Last collapse: verified"** but an icon is still visible — that icon is
  **right** of the divider. Move it left of the divider, or move the divider.
- Look at `~/Library/Logs/Komora.log`. A line with `verified=false` and
  `pushers=[…]` shows where the pushers went.

## The divider jumped after I ⌘-dragged it

After a ⌘-drag, macOS stops honouring the position value Komora wrote for the
divider. Komora notices this on the next collapse or move. It finds the value
of your spot and re-creates the divider there under a new name. The divider
may flicker once. If it lands somewhere else, open an issue with the log lines
that start with `calibrate:` and `adopt:`.

## ⌥⌘B does nothing, or does two things

- The menu line **Shortcut: … unavailable** means another app holds it.
  [Change the shortcut](usage.md#change-the-shortcut).
- If another menu bar hider runs (for example Pelmet), both may react to the
  same shortcut. Quit the other hider and remove it from Login Items.

## After sleep or a display change

When collapsed, Komora rebuilds the pushers 1 s after the last display or wake
event. This path is not tested yet. If icons reappear, press ⌥⌘B twice.

## Komora crashed or I quit it while collapsed

The pushers belong to the Komora process and should go away with it, so the
icons should come back. Komora always starts expanded. If icons stay hidden,
open Komora and expand.

## macOS asks whether to open Komora

The build is ad-hoc signed, not notarized. If macOS blocks it, allow it in
System Settings → Privacy & Security.

## Reporting a problem

Include:

- macOS version and build (`sw_vers`);
- your displays (size, notch or no notch);
- `~/Library/Application Support/Komora/state.json`;
- the last 50 lines of `~/Library/Logs/Komora.log`.
