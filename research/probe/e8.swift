import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
func pelmetToggle() -> AXUIElement? {
  guard let a = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.ismatbabirli.Pelmet" }) else { return nil }
  let ax = AXUIElementCreateApplication(a.processIdentifier)
  guard let bar = attr(ax, "AXExtrasMenuBar") else { return nil }
  return ((attr(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement]) ?? []).first { label($0) == "Pelmet" }
}
let s = Steps()
s.add(0.3, "before") { displayRows(); log("pelmet isCollapsed=\(UserDefaults(suiteName: "com.ismatbabirli.Pelmet")?.bool(forKey: "isCollapsed") ?? false)") }
s.add(0.2, "press Pelmet toggle") { if let t = pelmetToggle() { log("press -> \(AXUIElementPerformAction(t, kAXPressAction as CFString).rawValue)") } else { log("no toggle") } }
s.add(3.0, "collapsed?") { displayRows() }
s.add(0.2, "press again") { if let t = pelmetToggle() { log("press -> \(AXUIElementPerformAction(t, kAXPressAction as CFString).rawValue)") } }
s.add(3.0, "expanded?") { displayRows() }
s.run(); app.run()
