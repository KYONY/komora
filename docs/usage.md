# Using Komora

## Controls

| Action | Result |
|---|---|
| Left-click the divider `›` | Hide every icon left of it. The glyph becomes `‹`. |
| Left-click `‹` | Show the icons again. |
| ⌥⌘B | Toggle from anywhere. |
| Right-click or ⌃-click the divider | Open the menu. |
| ⌘-drag the divider | Move it. Komora adopts the new spot on the next collapse or move. |

While collapsed, the hidden icons are out of the bar. macOS may show a « item
for them. Whether hidden icons open from it is not tested yet; expand to use them.

A press during a collapse or a move is not lost. Komora applies the last
request when the current work ends.

## Menu

- **Hide Icons / Show Icons** — same as a left click.
- **Move Divider One Icon Left / Right** — move the divider past the next icon
  without the mouse. This takes a few seconds, because Komora searches with a
  probe item (see [how it works](how-it-works.md#6-moving-the-divider-without-the-mouse)).
  If no icon is there to pass, Komora beeps and the divider stays.
- **Shortcut: ⌥⌘B** — or a note that another app holds the shortcut. With a
  custom shortcut the label shows the key code, for example `⌃⌥⌘key 4`.
- **Last collapse: verified** — Komora's own check passed. If it says "an icon
  may sit next to the divider", see [troubleshooting](troubleshooting.md).
- **Quit Komora** — quits. The pushers go away with the process, so hidden
  icons should come back.

## Choose what to hide

Put the icons you want hidden **left** of the divider, and the icons you want
to keep **right** of it. To change the order, ⌘-drag icons or the divider.

## Change the shortcut

Komora reads two optional defaults. Values are Carbon virtual key codes and
Carbon modifier masks.

```sh
# Example: ⌃⌥⌘H  (kVK_ANSI_H = 4; cmdKey 256 + optionKey 2048 + controlKey 4096)
defaults write dev.komora.Komora hotkeyKeyCode -int 4
defaults write dev.komora.Komora hotkeyModifiers -int 6400
# back to ⌥⌘B
defaults delete dev.komora.Komora hotkeyKeyCode
defaults delete dev.komora.Komora hotkeyModifiers
```

Quit and reopen Komora after a change.

| Modifier | Mask |
|---|---|
| ⌘ `cmdKey` | 256 |
| ⇧ `shiftKey` | 512 |
| ⌥ `optionKey` | 2048 |
| ⌃ `controlKey` | 4096 |

## Scripting

Komora registers the `komora://` URL scheme:

```sh
open komora://collapse
open komora://expand
open komora://toggle
open komora://left     # move the divider one icon left
open komora://right
open komora://state    # rewrite the state file
```

The state file is
`~/Library/Application Support/Komora/state.json`:

```json
{
  "collapsed" : true,
  "dividerKey" : 625.99951171875,
  "dividerMinX" : 1609,
  "hotkey" : "⌥⌘B",
  "pushers" : [ { "minX" : 1144, "width" : 465 }, … ],
  "updated" : "2026-10-28T19:48:52Z",
  "verified" : true
}
```

Read it with `jq` or `plutil -p`, for example
`jq .verified ~/Library/Application\ Support/Komora/state.json`.

The log is `~/Library/Logs/Komora.log`. Each collapse writes one line with the
check result and the pusher positions.

## Stored settings

All of them are in the `dev.komora.Komora` defaults domain.

| Key | Meaning |
|---|---|
| `NSStatusItem Preferred Position Komora_…` | Position values of the divider, pushers and probes, written by Komora. |
| `dividerKey` | Komora's copy of the divider's value. |
| `dividerGeneration`, `pusherGeneration` | Name generations after a ⌘-drag pin. |
| `calibratedX` | The divider x at the last calibration. |
| `hotkeyKeyCode`, `hotkeyModifiers` | Optional shortcut override. |

To reset everything, quit Komora and run
`defaults delete dev.komora.Komora`. Komora then starts with value 250 and the
first divider name. If you ever ⌘-dragged that name, macOS may keep the dragged
spot instead (see [how it works §7](how-it-works.md#7--drag-pins-items)); this
is not tested.
