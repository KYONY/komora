# Changelog

## 0.1.0 — 2026-10-28

First version.

- One divider item. Click or ⌥⌘B hides every status icon left of it and shows them again.
- Collapse with seeded pusher items placed directly left of the divider
  ([how it works](docs/how-it-works.md)).
- Self-check from Komora's own frames after each collapse, one retry, result in the menu.
- Move the divider one icon left or right from the menu, without the mouse.
- ⌘-drag support: Komora detects a pinned divider and adopts its spot.
- Rebuild on display change and wake while collapsed (not tested yet).
- `komora://` URL scheme, `state.json` and `Komora.log` for scripts.
- No Accessibility or Screen Recording permission.
