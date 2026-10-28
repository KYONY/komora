import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var p: NSStatusItem!, h2: NSStatusItem!, h1: NSStatusItem!
func inproc(_ it: NSStatusItem) -> String {
  let w = it.button?.window
  return "\(it.autosaveName!): occl=\(w?.occlusionState.contains(.visible) ?? false) vis=\(w?.isVisible ?? false) hidden=\(callInt(it, "_isHidden")) screen=\(w?.screen?.localizedName ?? "nil") frame=\(w?.frame ?? .zero)"
}
let s = Steps()
s.add(0.3, "P, H2, H1") { p = makeItem("E4_P", title: "P4"); h2 = makeItem("E4_H2", title: "H2"); h1 = makeItem("E4_H1", title: "H1") }
s.add(2.5, "expanded") { displayRows(); log(inproc(h1)); log(inproc(p)) }
s.add(0.2, "L=850") { p.length = 850 }
s.add(2.5, "collapsed") { displayRows(); log(inproc(h1)); log(inproc(p)) }
s.add(0.2, "press windows-tree «") {
  for w in agentWindows() { for b in (attr(w, kAXChildrenAttribute) as? [AXUIElement]) ?? [] where label(b).contains("Show Hidden") {
    var acts: CFArray?; AXUIElementCopyActionNames(b, &acts); log("acts \(acts as? [String] ?? [])")
    log("press -> \(AXUIElementPerformAction(b, kAXPressAction as CFString).rawValue)") } }
}
s.add(1.5, "after press") { displayRows(); log("windows: \(agentWindows().count)"); for w in agentWindows() { log("  \(frameOf(w)) \(label(w))") } }
s.add(0.2, "reset") { p.length = NSStatusItem.variableLength }
s.add(2.0, "after reset") { displayRows() }
s.run(); app.run()
