# Design: Komora 0.1.0

## Decisions

- [DECISION] Own app, Swift package (`KomoraCore` + `Komora`), built by `scripts/build-app.sh`
  into `build/Komora.app` (bundle id `dev.komora.Komora`, ad-hoc signed, LSUIElement).
- [DECISION] One visible item, the divider `Komora_Divider`, later `Komora_Divider_g<n>` (chevron). Left click toggles,
  right/⌃-click opens the menu. No separate toggle item (scope S0).
- [DECISION] Divider key K lives in our defaults (`NSStatusItem Preferred Position Komora_Divider`
  + `dividerKey`). Re-registered with it each launch [FACT: E11].
- [DECISION] Collapse = register N pushers `Komora_P<gen>_<i>`, key K + (i+1)·2⁻¹⁴ (exact in
  Float32 below 1024; changed from 2⁻¹⁰ after review round 1), length = unit; expand = `removeStatusItem`. Crash while collapsed fails open:
  the items die with the process. Launch is always expanded.
- [DECISION] unit = ⌊min(width)/2 − 64⌋ (449 pt here), N = ⌈max(width)/(unit+16)⌉ + 1 (6 here).
  Formula follows Pelmet 0.10 [S1]; 449 is the only unit measured end to end [FACT: E13].
- [DECISION] Self-check after collapse from own frames: divider visible; every pusher has a width
  and at least one overflowed (x = 0) [FACT: E13]; visible pushers form a chain to the divider
  (first ±3 pt, then gaps ≤ 10 pt). One retry with a new pusher generation, result in the menu.
- [DECISION] Divider moves from the menu ("one icon left/right") by bisection with a probe item
  `Komora_Probe_<random>` (fresh name per run), own frames only. New key = boundary ± 0.25 margin, confirmed by the probe,
  margin shrinks ×¼ on failure. Reason: a foreign key sat within 2⁻¹⁰ of a boundary
  (komora-app.log 17:02:33–17:04:11: a foreign value between 498.999 and 499).
- [DECISION] First-launch key 250 (on this Mac: right of AppE, left of AppF; names anonymised in the logs) [FACT: E12, E13].
- [DECISION] Global shortcut via Carbon `RegisterEventHotKey`, default ⌥⌘B, overridable by
  `hotkeyKeyCode` / `hotkeyModifiers` defaults. No permission needed.
- [DECISION] Screen-parameter change and wake rebuild the pushers when collapsed.
- [DECISION] URL scheme `komora://collapse|expand|toggle|left|right|state` and
  `~/Library/Application Support/Komora/state.json`, `~/Library/Logs/Komora.log` — for
  scripted checks.

- [DECISION] Pinned divider → adopt: bisect its key with a fresh probe, then re-create the
  divider as `Komora_Divider_g<n>` seeded at that key. Verified: komora-app.log 17:55:23.

## Rejected
- Keep-alive hidden spacers (Pelmet): unknown order, invisible, fail-open on crash not needed.
- `_setLayoutIndex:`, `_setOverflowSpecifierPriority:`, priority items, in-process drag: no effect [FACT: E5, E9].
- Accessibility-based order reading in the app: not needed; own frames suffice.

## Unverified
- [ASSUMPTION: needs-verification] Visual result. An AX readout at 17:55 showed icons hidden on
  both displays (not saved); the app has run with verified=true since 19:48 (komora-app.log).
  No screenshot.
- [FACT: komora-app.log 17:48–17:55, `defaults read` 2026-10-28] A user ⌘-drag pins every
  item of the app that exists at that moment: MenuBarAgent keeps the position, deletes the
  seed key, and ignores later seeds for that name. Pinned and seeded items do not order by
  one rule.
- [ASSUMPTION: needs-verification] Hotkey with Pelmet running: registration returned noErr,
  so both apps may react to ⌥⌘B.
- [ASSUMPTION: needs-verification] Wake / display reconfiguration paths (code exists, not run).
