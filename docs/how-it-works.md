# How Komora works

Everything here was measured on macOS 27.0.1 (26A434), Mac mini M4 Pro, with two
displays without a notch: a 2320×1305 pt landscape display and a 1026×1824 pt
portrait display, both at scale 2. Claims link to the log that shows them.
Where no log exists, the text says so. Other setups may behave differently.

## 1. How macOS 27 draws the menu bar

- MenuBarAgent draws the status area. Each display gets its own copy of the bar.
  The copies are visible to Accessibility as MenuBarAgent windows, one per
  display ([e8](../research/logs/e8.log), the `win@0` and `win@2320` rows).
- Pelmet 0.10's source (`OverflowCollapseGeometry.swift`) says macOS discards
  a length change past a limit of about half the display width. Komora did not
  measure the limit. Early probes (e3, e4, output not kept) saw 700 and 900 pt
  accepted on the main display and 1100 pt and more refused. Treat this as a
  hint, not as evidence.
- When the items do not fit, macOS does not shrink them. It moves the
  **leftmost** items out of the bar ([e8](../research/logs/e8.log), the
  "collapsed?" rows). In that run a system « item ("Show Hidden Menu Bar
  Items") appeared.

So to hide icon X you need enough width directly **right** of X, and that width
must belong to items that stay in the bar.

## 2. An app can choose where its own items go

Each status item with an `autosaveName` has a position value. AppKit stores it
in the app's own defaults as `NSStatusItem Preferred Position <autosaveName>`.

| Observation | Evidence |
|---|---|
| If the app writes the value **before** it registers the item, the item lands at that place. | [e10](../research/logs/e10.log): seed 300 → x 1692, seed 1000 → x 1113 |
| This works for a name macOS already knows, and after `removeStatusItem` + re-create in the same process. | [e11](../research/logs/e11.log): 1000 → x 1171, then 300 → x 1692 |
| A bigger value means further left. Seeded values from 150 to 999 landed between foreign items; 999 landed left of all of them. | [e12](../research/logs/e12.log): a sweep from 0 to 999 |
| Values 1–100 do not pass right of the system items (Control Center, clock). | [e12](../research/logs/e12.log): all land at x 2107 |
| No value, or 0, means leftmost. | [e12](../research/logs/e12.log) key 0, [e14](../research/logs/e14.log) |
| The bar settles 0.06–0.09 s after a registration. | [e12](../research/logs/e12.log) `settle=` |
| The app reads its own item's position from `button.window.frame`. This needs no permission. An item that macOS overflowed out of the bar reports x = 0. | [e13](../research/logs/e13.log) `pushers=1498,1033,568,0,0` |

The comment in Pelmet 0.10 (`MenuBarManager.swift`) says an app "can neither
read nor seed" this value. On macOS 27.0.1 that is not true.

## 3. Collapse and expand

Komora has one permanent item, the **divider**, with position value *K*.
(The first launch uses *K* = 250. On the test Mac this put it directly right of
the item AppE ([e12](../research/logs/e12.log), key 250).)

**Collapse:**

1. Compute the pusher length (the unit) and the pusher count (see §4).
2. Register *N* pushers. Pusher *i* gets the value *K* + (*i* + 1)·2⁻¹⁴ and
   the unit length. Its button is disabled and hidden from Accessibility.
3. All pusher values are a little bigger than *K*, so the pushers land in a
   row directly left of the divider.
4. Their total width is more than the widest display. macOS overflows from the
   left, so every icon left of the pushers leaves the bar. Some pushers
   overflow as well; that is harmless.
5. Komora waits until its frames stop moving, then checks the result (see §5).

**Expand:** remove the pushers with `removeStatusItem`. The icons come back.

Komora creates and removes the pushers each time. It does not keep invisible
spacers alive. Two results follow:

- The pushers belong to the Komora process, so they should go away when it
  exits. A forced quit while collapsed was tested once: the next launch started
  expanded (author's run notes, not published). The return of the foreign icons after
  a crash was not observed separately.
- A pusher can never sit in the wrong place from an old session.

The end-to-end probe run [e13](../research/logs/e13.log) shows the result
through Accessibility. After collapse the main display's bar held only
pushers, the divider `‹` and the system items. The portrait display showed the
probe's own items, a « item and the items right of the divider.

For the shipped app the evidence is weaker. Its own check passed
(`verified=true`, [app log](../research/logs/komora-app.log)), and an
Accessibility readout on 2026-10-28 at 17:55 UTC showed the icons gone on both
displays. That readout was not saved, so treat it as unverified. No screenshot exists.

### Why 2⁻¹⁴

This is a design choice, not a measurement. The value macOS reports for an
item without a seed is `3.4028235e+38`, the largest 32-bit float
([e10](../research/logs/e10.log), [e14](../research/logs/e14.log)). That
suggests the values are 32-bit floats somewhere. Steps of 2⁻¹⁴ are exact in
Float32 below 1024, so two pushers cannot round onto one value. 32 pushers span
1/512 above *K*, so a foreign value is unlikely to fall between two pushers.
e13 used steps of 0.001; the app uses 2⁻¹⁴.

## 4. Sizing

```
unit  = floor(min(display widths) / 2 − 64)          // 449 pt here
count = ceil(max(display widths) / (unit + 16)) + 1   // 6 here, at most 32
```

- The unit follows Pelmet 0.10's formula. One length applies to the bar on
  every display, so the narrowest display sets the limit.
- AppKit adds 16 pt of padding around each item, so a 449 pt pusher is 465 pt
  wide in the bar ([e13](../research/logs/e13.log) rows: `w465`).
- One spare pusher covers rounding. Spare pushers overflow themselves.
- 449 pt is the only unit measured end to end. Larger units may work on wider
  displays. They are not tested.

Code: `Sources/KomoraCore/Geometry.swift`, `Geometry.plan(widths:)`.

## 5. Self-check without permission

Komora cannot see other apps' icons. It can see its own frames, and that is
enough. After a collapse, `Verify.pushersAdjacent` passes only if:

- the divider is visible (x > 0, width > 0);
- every pusher has a width, and at least one pusher overflowed (x = 0), which
  shows the pushers reached the left end of the bar;
- the visible pushers form one unbroken chain that ends at the divider. The
  first may be 3 pt off. Gaps between pushers may be up to 10 pt, because the
  leftmost pusher can sit 8 pt off where it meets the app menus.

A gap in the chain means a foreign icon sits between two pushers or between a
pusher and the divider. That icon would stay visible. If the check fails,
Komora retries once with new pusher names (§7). The divider's menu shows the
last result.

## 6. Moving the divider without the mouse

The menu buttons **Hidden icons − / +** search for the next
foreign item's value. Komora uses a 1 pt wide **probe** item:

1. It places the probe at values further and further from *K* until the probe
   is no longer directly next to the divider. Now a foreign item lies between.
2. It bisects to a step of 2⁻¹⁰.
3. The new *K* is the found boundary plus a margin of 0.25. Komora checks the
   result with the probe. If something else is in the way, it divides the
   margin by 4 and tries again.

The margin exists because a foreign value can sit within 2⁻¹⁰ of a boundary.
On the test Mac, with the divider at 499, a probe at 498.999 landed right of
the next foreign item (AppD in the logs). So that item's value
lay between 498.999 and 499 ([app log](../research/logs/komora-app.log)
17:02:33–17:04:11, `probe right` lines).

### Remembered steps

Each search re-registers the probe many times, and every registration makes
macOS lay out the bar again. The icons next to the divider visibly jump. So
Komora stores the value it found for each step from the default place
(`dividerStepKeys`, keyed by the counter: `"0"` is 250, `"-1"`, `"1"` …).

On the next step to a stored number, Komora places the divider at the stored
value and checks its own frame: the divider must have moved at least 2 pt in
the expected direction. If it did, the step is done without a probe. If not,
the stored value is stale (an app quit or launched, so the foreign values
around the divider changed). Komora puts the divider back, runs the normal
search and stores the new value. After a ⌘-drag the counter is unknown, so no
stored value is used until **Reset Divider Position**.

This check is a design choice. It is not measured on a bar where apps change
between two steps.

## 7. ⌘-drag pins items

You can ⌘-drag the divider like any menu bar item. On macOS 27.0.1 a ⌘-drag
changes the rules for the dragged app:

- MenuBarAgent keeps the dragged item's new position. The divider's
  `NSStatusItem Preferred Position` value disappeared from Komora's defaults
  after the drag. This was seen with `defaults read` on 2026-10-28; the output
  was not saved.
- The probe item existed during the drag, under a fixed name at that time.
  Afterwards it landed at x 2003 for every value Komora tried, up to about 131072
  ([app log](../research/logs/komora-app.log), 44 lines with
  `probe=2003w17`, 17:48:47–17:52:36). So MenuBarAgent ignored new values for
  that name too. Komora's code therefore assumes that a drag pins every item
  of the app that exists at that moment. Only these two items were observed.
- With a pinned divider, seeded pushers did not line up with it. Komora found
  the divider's value (625.999–626.0) and seeded the pushers just above it.
  Its check still failed twice: `verified=false`, pushers at x 1170, 705, 232
  against a divider at x 1609 (app log 17:54:30–17:54:37).

Komora handles this:

1. **Fresh names.** Each probe run uses a new random name. If a collapse check
   fails, Komora moves the pushers to a new name generation and retries once.
2. **Adopt.** On the next collapse or move, Komora sees that the divider's
   value is gone. It bisects with a fresh probe to find the value of the
   divider's current spot. Then it re-creates the divider under a new name
   (`Komora_Divider_g1`, `_g2`, …) seeded with that value. The new divider
   lands at the same spot, and the normal rules apply again.

App log 17:55:22–17:55:23 shows the fix: "calibrate: divider key in
625.999..626.0", "adopt: Komora_Divider_g1 … x 1592 -> 1609", then
"collapse verified=true".

## 8. Shortcut

Komora registers ⌥⌘B with Carbon `RegisterEventHotKey`. This API needs no
Accessibility or Input Monitoring permission. If another app holds the same
combination, the menu says so. On the test Mac the registration returned
`noErr` while Pelmet was also running, so both apps may react.

## 9. Things that did not work

These private AppKit methods had no effect on macOS 27.0.1:

| Method | Result | Evidence |
|---|---|---|
| `_setLayoutIndex:` | order unchanged | [e5](../research/logs/e5.log) |
| `_setOverflowSpecifierPriority:` | value not kept (`ovf now 0`) | [e5](../research/logs/e5.log) |
| `_statusItemWithLength:withPriority:` | the item does not appear in the bar | [e5](../research/logs/e5.log) |
| `_startStatusItemDrag:`, `_dragStatusItemWithOffset:`, `_completeStatusItemDrag` | `isDragging=false`, positions unchanged | [e9](../research/logs/e9.log) |

The SDK headers for macOS 27.1 add no public API for item order. The only new
`NSStatusItem` API is `expandedInterfaceDelegate` / session.
