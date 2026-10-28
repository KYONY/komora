# Building and contributing

## Build

```sh
swift build                 # debug
swift test                  # KomoraCore unit tests
./scripts/build-app.sh      # release build → build/Komora.app (ad-hoc signed)
```

Requirements: macOS with Swift 5.9 or later (Xcode or the Command Line Tools).

## Layout

| Path | Contents |
|---|---|
| `Sources/KomoraCore/Geometry.swift` | Pure logic: pusher sizing, position values, the collapse check. Unit-tested. |
| `Sources/Komora/main.swift` | The app: status items, collapse/expand, divider moves, ⌘-drag adopt, shortcut, URL scheme. |
| `Tests/KomoraCoreTests/` | Tests for `KomoraCore`. |
| `scripts/build-app.sh` | Builds and signs the `.app` bundle. |
| `scripts/make-icon.swift`, `Resources/` | Draws the app icon: `swift scripts/make-icon.swift` writes `Resources/AppIcon.icns` and `.png`. |
| `research/probe/` | Probe programs used to measure macOS behaviour ([research notes](docs/research.md)). |
| `research/logs/` | Their output, cited by the docs. |
| `openspec/` | The design record of the first version. |

## Rules for changes

- **Measure macOS behaviour, do not assume it.** A claim about how macOS lays
  out the menu bar needs a log from a probe or a cited source. Say which macOS
  build and which displays you measured on.
- **No Accessibility, no Screen Recording, no synthetic mouse events** in the
  app. Probes may use Accessibility to read the bar.
- **Do not copy code from GPL projects** such as Ice. Studying their behaviour
  is fine.
- Keep logic that can be tested in `KomoraCore`, with tests.

## Reports from other setups help most

Komora is measured on one Mac. If you run it on a notched MacBook, a single
display, or another macOS build, an issue with `sw_vers`, your display sizes,
`state.json` and the log lines from a collapse is very useful — whether it
works or not.
