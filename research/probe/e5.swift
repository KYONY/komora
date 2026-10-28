import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var p: NSStatusItem!, h2: NSStatusItem!, h1: NSStatusItem!, q: NSStatusItem?
let s = Steps()
s.add(0.3, "reuse E4 names: P, H2, H1") { p = makeItem("E4_P", title: "P4"); h2 = makeItem("E4_H2", title: "H2"); h1 = makeItem("E4_H1", title: "H1") }
s.add(3, "expanded") { log(barState()) }
s.add(0.2, "H1._setLayoutIndex(5)") { setInt(h1, "_setLayoutIndex:", 5) }
s.add(2.5, "after layoutIndex 5") { log(barState()) }
s.add(0.2, "H1._setLayoutIndex(0)") { setInt(h1, "_setLayoutIndex:", 0) }
s.add(2.5, "after layoutIndex 0") { log(barState()) }
s.add(0.2, "P overflowPrio=1000, L=900") { setInt(p, "_setOverflowSpecifierPriority:", 1000); log("ovf now \(callInt(p, "_overflowSpecifierPriority"))"); p.length = 900 }
s.add(3, "L=900 ovf1000") { log(barState()) }
s.add(0.2, "P overflowPrio=-1000") { setInt(p, "_setOverflowSpecifierPriority:", -1000); p.length = 899 }
s.add(3, "L=899 ovf-1000") { log(barState()) }
s.add(0.2, "H2 ovf=1000, P ovf 0, L=800") { setInt(p, "_setOverflowSpecifierPriority:", 0); setInt(h2, "_setOverflowSpecifierPriority:", 1000); p.length = 850 }
s.add(3, "L=850 H2 ovf1000") { log(barState()) }
s.add(0.2, "reset P") { p.length = NSStatusItem.variableLength }
s.add(1.5, "priority item E5_Q prio=2147483647") { q = makePriorityItem("E5_Q", title: "Q5", priority: Int(Int32.max)) }
s.add(3, "after prio item") { log(barState()); if let q { log("Q prio=\(callInt(q, "_priority"))") } }
s.run(); app.run()
