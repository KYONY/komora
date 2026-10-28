import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var a: NSStatusItem?
let key = "NSStatusItem Preferred Position E10_SEED300"
let s = Steps()
s.add(0.2, "known name, defaults rewritten to 1000 before register") {
  log("defaults before: \(UserDefaults.standard.object(forKey: key) ?? "nil")")
  UserDefaults.standard.set(1000.0, forKey: key)
  a = makeItem("E10_SEED300", title: "S300")
}
s.add(3, "where?") { log("own: \(a!.button!.window!.frame.minX) saved=\(callFloat(a!, "_savedPreferredPosition"))"); displayRows() }
s.add(0.2, "remove, set 300, re-add same process") {
  NSStatusBar.system.removeStatusItem(a!); a = nil
  UserDefaults.standard.set(300.0, forKey: key)
}
s.add(1.0, "re-add") { a = makeItem("E10_SEED300", title: "S300") }
s.add(3, "where2?") { log("own: \(a!.button!.window!.frame.minX) saved=\(callFloat(a!, "_savedPreferredPosition"))"); displayRows(); log("defaults after: \(UserDefaults.standard.object(forKey: key) ?? "nil")") }
s.run(); app.run()
