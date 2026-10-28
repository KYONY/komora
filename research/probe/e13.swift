import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
func pp(_ n: String) -> String { "NSStatusItem Preferred Position \(n)" }
func place(_ name: String, key: Double, title: String, length: CGFloat = NSStatusItem.variableLength) -> NSStatusItem {
  UserDefaults.standard.set(key, forKey: pp(name)); return makeItem(name, title: title, length: length)
}
var t: NSStatusItem!; var pushers: [NSStatusItem] = []
let unit: CGFloat = 449
let s = Steps()
s.add(0.2, "T at 250") { t = place("E13_T", key: 250, title: "‹") }
s.add(1.0, "expanded") { displayRows(); log("T=\(t.button!.window!.frame)") }
s.add(0.2, "collapse: register 5 pushers at 250+0.001*i, length \(unit)") {
  for i in 1...5 { pushers.append(place("E13_S\(i)", key: 250 + 0.001 * Double(i), title: "", length: unit)) }
}
s.add(1.5, "collapsed") { displayRows(); log("T=\(t.button!.window!.frame) pushers=" + pushers.map { "\(Int($0.button!.window!.frame.minX))" }.joined(separator: ",")) }
s.add(0.2, "expand: remove pushers") { pushers.forEach { NSStatusBar.system.removeStatusItem($0) }; pushers = [] }
s.add(1.5, "expanded again") { displayRows() }
s.run(); app.run()
