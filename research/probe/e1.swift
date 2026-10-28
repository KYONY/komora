import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var items: [NSStatusItem] = []
let s = Steps()
s.add(0.5, "baseline") { snap("baseline") }
s.add(0.1, "create E1_A then E1_B (fresh)") {
  items.append(makeItem("E1_A", title: "A1"))
  items.append(makeItem("E1_B", title: "B1"))
}
s.add(1.5, "after create") { log("mine: " + mine())
  for it in items { log("\(it.autosaveName ?? "") prio=\(callInt(it, "_priority")) ins=\(callInt(it, "_systemInsertOrder")) ovf=\(callInt(it, "_overflowSpecifierPriority")) cur=\(callFloat(it, "_currentPreferredPosition")) saved=\(callFloat(it, "_savedPreferredPosition")) disp=\(String(describing: it.perform(NSSelectorFromString("_displayIdentifier"))?.takeUnretainedValue()))") }
  log("diag A: " + diag(items[0]))
  log("frame A: \(String(describing: items[0].button?.window?.frame)) win=\(String(describing: items[0].button?.window))")
}
s.add(0.2, "full snap") { snap("after create") }
s.run()
app.run()
