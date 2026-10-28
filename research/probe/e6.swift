import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var p: NSStatusItem!, h2: NSStatusItem!, h1: NSStatusItem!
let s = Steps()
s.add(0.3, "P, H2, H1") { p = makeItem("E4_P", title: "P4"); h2 = makeItem("E4_H2", title: "H2"); h1 = makeItem("E4_H1", title: "H1") }
s.add(2.5, "L=850") { p.length = 850 }
s.add(2.5, "state") { log(barState()) }
s.add(0.2, "press «") { if let c = chevronElement() { log("press -> \(AXUIElementPerformAction(c, kAXPressAction as CFString).rawValue)") } else { log("no chevron") } }
s.add(1.5, "agent windows") { dumpAgentWindows() }
s.add(0.2, "press « again") { if let c = chevronElement() { log("press2 -> \(AXUIElementPerformAction(c, kAXPressAction as CFString).rawValue)") } }
s.add(1.0, "after close") { dumpAgentWindows() }
s.add(0.2, "reset") { p.length = NSStatusItem.variableLength }
s.run(); app.run()
