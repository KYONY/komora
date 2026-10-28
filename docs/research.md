# Research notes

Komora started as a question: why does Pelmet 0.10 not hide icons on macOS 27,
and can an app fix it without Accessibility? The answers came from small probe
programs run on one Mac. This page lists them.

**Test machine:** macOS 27.0.1 (26A434), Mac mini M4 Pro. Displays: 2320×1305 pt
landscape and 1026×1824 pt portrait, scale 2, no notch.

## Running the probes

```sh
cd research/probe
./build.sh e12        # builds e12.swift with common.swift and runs it
```

- The probes read the bar through Accessibility (MenuBarAgent windows), so the
  terminal app needs the Accessibility grant. Komora itself does not.
- The AX readout returns nothing while the screen is locked.
- `build.sh` overwrites the single probe binary
  `KomoraProbe.app/Contents/MacOS/KomoraProbe` each time.
- Some probes collapse your menu bar for a moment. They restore it at the end.

## Log format

```
win@0 w2320 n=22: ·@1199w38 AppB@1237w33 … Clock|com.appl@2181w116
```

One row per display copy of the bar: `win@<display x> w<display width>
n=<items>`, then each item as `<label>@<x>w<width>`. `·` is an item with no
label. `‹` / `Komora divider` / `KomoraProbe` are our own items.

Third-party app names are anonymised as `AppA`…`AppM`. Apple system items,
Pelmet and Komora keep their names.

## Experiments with logs

| Id | Question | Result | Log |
|---|---|---|---|
| e5 | Do `_setLayoutIndex:`, `_setOverflowSpecifierPriority:` or a priority item change the order? | No. The overflow priority does not even keep its value. | [e5.log](../research/logs/e5.log) |
| e8 | Why does Pelmet not hide the icons? | Its spacers sit left of every icon. On collapse macOS overflows the spacers, and the icons stay. | [e8.log](../research/logs/e8.log) |
| e9 | Does AppKit's in-process drag API move an item? | No. `isDragging` stays false. | [e9.log](../research/logs/e9.log) |
| e10 | Does a seeded `NSStatusItem Preferred Position` place a new name? | Yes. 300 → x 1692, 1000 → x 1113. | [e10.log](../research/logs/e10.log) |
| e11 | Does it work for a known name, and after remove + re-create in one process? | Yes, both. | [e11.log](../research/logs/e11.log) |
| e12 | Map from value to position, and settle time | Monotonic: bigger value = further left. 0 = leftmost. 1–100 stay left of the system items. Settles in 0.06–0.09 s. | [e12.log](../research/logs/e12.log) |
| e13 | End to end: divider at 250, five 449 pt pushers | Every icon left of the divider hidden on both displays. All back after expand. | [e13.log](../research/logs/e13.log) |
| e14 | A known name with its value deleted | Lands leftmost. | [e14.log](../research/logs/e14.log) |
| app | Komora 0.1.0 in use, including the ⌘-drag pin and the adopt fix | See [how it works §7](how-it-works.md#7--drag-pins-items). Older lines say "retrying once"; later builds say "retrying with new pusher names". | [komora-app.log](../research/logs/komora-app.log) (full app log) |

## Probes without kept logs

`e1`–`e4`, `e6`, `e7` and the `ax*`, `rt`, `sig` and `obs` files were
exploratory: AX attribute dumps, Objective-C runtime dumps of `NSStatusItem`
and `NSStatusBar`, length limits, and a live observer. Their output was read
in the session and not saved. Do not treat them as evidence. Re-run them if
you need the numbers.

## Sources

- Pelmet 0.10.0 (MIT), commit `5531dcb`:
  `Sources/PelmetCore/OverflowCollapseGeometry.swift`,
  `Sources/Pelmet/MenuBarManager.swift`.
- macOS 27.1 SDK, `AppKit.framework/Headers/NSStatusItem.h`.
- The full design record of this run is in
  [openspec/changes/2026-10-28-menu-bar-icon-hider/](../openspec/changes/2026-10-28-menu-bar-icon-hider/).

## Re-checking after a macOS update

If a later macOS breaks Komora, run `./build.sh e12` first. It shows whether
position values still place items and in which direction. Then run `e13` for
the full collapse.
