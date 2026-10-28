import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var p: NSStatusItem!, h2: NSStatusItem!, h1: NSStatusItem!
let s = Steps()
s.add(0.3, "P, H2, H1") { p = makeItem("E4_P", title: "P4"); h2 = makeItem("E4_H2", title: "H2"); h1 = makeItem("E4_H1", title: "H1") }
s.add(2.5, "before") { displayRows(); log("own: " + ownOrder([p,h2,h1])); log("supportsDragging=\(getBool(h1, "_supportsDragging")) allowItemDragging=\(getBool(h1, "_allowItemDragging"))") }
s.add(0.2, "start drag H1") { callBool(h1, "_startStatusItemDrag:", true); log("isDragging=\(getBool(h1, "_isDragging"))") }
for dx in stride(from: 20.0, through: 140.0, by: 20.0) {
  s.add(0.15, "drag +\(dx)") { callPoint(h1, "_dragStatusItemWithOffset:", CGPoint(x: dx, y: 0)) }
}
s.add(0.3, "mid") { log("own: " + ownOrder([p,h2,h1])) }
s.add(0.2, "complete") { callVoid(h1, "_completeStatusItemDrag"); log("isDragging=\(getBool(h1, "_isDragging"))") }
s.add(2.5, "after") { displayRows(); log("own: " + ownOrder([p,h2,h1])) }
s.run(); app.run()
