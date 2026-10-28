# Sources

## scope_authority: S0
Defines what is IN this run. Items absent here are out of scope.

| id | what | type | resolver | scope_authority |
|----|------|------|----------|-----------------|
| S0 | User brief, verbatim | file | brief.md (author's notes, not published) | yes |
| S1 | Pelmet 0.10.0 source (MIT), commit 5531dcb | git | https://github.com/ismatBabirli/pelmet @5531dcb (Sources/PelmetCore/OverflowCollapseGeometry.swift, Sources/Pelmet/MenuBarManager.swift) | no |
| S2 | Display geometry measured on this Mac | file | research/probe/ax.swift (run output not published) | no |
| S3 | macOS 27.1 SDK headers (NSStatusItem.h) | file | $(xcrun --show-sdk-path)/System/Library/Frameworks/AppKit.framework/Headers/NSStatusItem.h | no |
| S4 | ObjC runtime dump of NSStatusItem / NSStatusBar | file | research/probe/rt.swift, research/probe/sig.swift | no |
| E5 | Private setters `_setLayoutIndex:`, `_setOverflowSpecifierPriority:`, priority items: no effect | log | research/logs/e5.log | no |
| E8 | Pelmet collapse layout (hypothesis check) | log | research/logs/e8.log | no |
| E9 | In-process drag `_startStatusItemDrag:` etc.: no effect | log | research/logs/e9.log | no |
| E10 | Seeded Preferred Position places a fresh name | log | research/logs/e10.log | no |
| E11 | Seed is honoured for a known name, also within one process | log | research/logs/e11.log | no |
| E12 | Key → bar position map, settle time | log | research/logs/e12.log | no |
| E13 | End-to-end collapse with seeded pushers, both displays | log | research/logs/e13.log | no |
| E14 | Known name without a key lands leftmost | log | research/logs/e14.log | no |
| W1 | Web digest: Ice/Bartender on macOS 27, name check (weak: one blog; mis-stated that the Pelmet repo does not exist) | web | human-only | no |
| app | Komora 0.1.0 own log (full): nudges, ⌘-drag pin, adopt fix | log | research/logs/komora-app.log | no |

Probe sources: `research/probe/` (`./build.sh eN` rebuilds and runs experiment N; needs
the terminal's Accessibility grant for the AX readout only).
