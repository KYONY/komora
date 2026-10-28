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
- **Hidden icons − / +** — **+** hides one icon more: the divider moves one
  icon right. **−** hides one icon fewer: the divider moves one icon left. Each
  press takes a few seconds, because Komora searches with a probe item (see
  [how it works](how-it-works.md#6-moving-the-divider-without-the-mouse)). If no
  icon is there to pass, Komora beeps and the divider stays. The number next to
  the buttons counts steps from the default place: `0` is the default, `+2`
  hides two icons more, `−1` one icon fewer. After a ⌘-drag it shows `custom`;
  **Reset Divider Position** sets it back to `0`. Komora cannot count the hidden
  icons themselves: that would need Accessibility.

  The first time you step to a number, Komora searches for the next icon. While
  it searches, the icons next to the divider jump left and right for a few
  seconds: each try moves a hidden probe item, and macOS lays out the bar again.
  Komora remembers where each step landed. The next time you step to the same
  number, the divider goes there at once, without the search. If the divider
  does not move the right way, for example because an app quit or launched,
  Komora searches again and updates what it remembered. Steps are remembered
  only while the counter shows a number, not `custom`.
- **Reset Divider Position** — puts the divider back where it starts on first
  launch (position value 250).
- **Shortcut: ⌥⌘B** — the current shortcut, or a note that another app holds it.
- **Change Shortcut…** — opens a small window. Press the new combination; it
  must include ⌘, ⌥ or ⌃. Esc or **Cancel** keeps the old one. **Reset to ⌥⌘B**
  restores the default. If another app holds the combination, the window says so.
- **Launch at Login** — a switch. On means Komora starts when you log in. It
  uses the system login item API (`SMAppService`), so Komora appears in System
  Settings → General → Login Items.
- **Last collapse: verified** — Komora's own check passed. If it says "an icon
  may sit next to the divider", see [troubleshooting](troubleshooting.md).
- **Quit Komora** — quits. The pushers go away with the process, so hidden
  icons should come back.

## Choose what to hide

Put the icons you want hidden **left** of the divider, and the icons you want
to keep **right** of it. To change the order, ⌘-drag icons or the divider.

## Change the shortcut

Use **Change Shortcut…** in the menu. Komora stores the result in two
defaults, which you can also set by hand. Values are Carbon virtual key codes and
Carbon modifier masks.

```sh
# Example: ⌃⌥⌘H  (kVK_ANSI_H = 4; cmdKey 256 + optionKey 2048 + controlKey 4096)
defaults write dev.komora.Komora hotkeyKeyCode -int 4
defaults write dev.komora.Komora hotkeyModifiers -int 6400
# back to ⌥⌘B
defaults delete dev.komora.Komora hotkeyKeyCode
defaults delete dev.komora.Komora hotkeyModifiers
```

Quit and reopen Komora after a change made by hand.

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
open komora://reset-divider
open komora://shortcut  # open the shortcut window
open komora://login-on  # launch at login on
open komora://login-off
open komora://state    # rewrite the state file
```

The state file is
`~/Library/Application Support/Komora/state.json`:

```json
{
  "collapsed" : true,
  "dividerKey" : 625.99951171875,
  "dividerMinX" : 1609,
  "dividerOffset" : 2,
  "hotkey" : "⌥⌘B",
  "launchAtLogin" : true,
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
| `dividerOffset` | Steps from the default place; absent after a ⌘-drag. |
| `dividerStepKeys` | Remembered divider value for each step number (`"0"`, `"1"`, `"-1"` …). |
| `dividerGeneration`, `pusherGeneration` | Name generations after a ⌘-drag pin. |
| `calibratedX` | The divider x at the last calibration. |
| `hotkeyKeyCode`, `hotkeyModifiers` | The shortcut, if you changed it. |

To reset everything, quit Komora and run
`defaults delete dev.komora.Komora`. Komora then starts with value 250 and the
first divider name. If you ever ⌘-dragged that name, macOS may keep the dragged
spot instead (see [how it works §7](how-it-works.md#7--drag-pins-items)); this
is not tested.
