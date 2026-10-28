import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var a: NSStatusItem!
let s = Steps()
s.add(0.2, "E13_T known (last key 250), remove defaults key, register") {
  UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position E13_T")
  a = makeItem("E13_T", title: "‹")
}
s.add(1.5, "where") { log("x=\(a.button!.window!.frame.minX) saved=\(callFloat(a, "_savedPreferredPosition")) defaults=\(UserDefaults.standard.object(forKey: "NSStatusItem Preferred Position E13_T") ?? "nil")") }
s.run(); app.run()
