import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var items: [NSStatusItem] = []
let s = Steps()
s.add(0.2, "seed + create") {
  UserDefaults.standard.set(300.0, forKey: "NSStatusItem Preferred Position E10_SEED300")
  UserDefaults.standard.set(1000.0, forKey: "NSStatusItem Preferred Position E10_SEED1000")
  items.append(makeItem("E4_P", title: "P4"))
  items.append(makeItem("E10_SEED300", title: "S300"))
  items.append(makeItem("E10_SEED1000", title: "S1000"))
}
s.add(3, "after") { displayRows(); for it in items { log("\(it.autosaveName!) cur=\(callFloat(it, "_currentPreferredPosition")) saved=\(callFloat(it, "_savedPreferredPosition")) approx=\(it.button?.window?.frame ?? .zero)") } }
s.run(); app.run()
