import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var p: NSStatusItem!, h2: NSStatusItem!, h1: NSStatusItem!
let s = Steps()
s.add(0.3, "create P, H2, H1 (fresh, in that order)") {
  p = makeItem("E4_P", title: "P4"); h2 = makeItem("E4_H2", title: "H2"); h1 = makeItem("E4_H1", title: "H1")
}
s.add(3, "expanded") { log(barState()) }
for L in [450.0, 700.0, 900.0, 1100.0, 1300.0, 1700.0, 2500.0, 20.0] {
  s.add(0.5, "set P.length=\(L)") { p.length = L }
  s.add(2.5, "state L=\(L)") { log("P.win=\(p.button?.window?.frame ?? .zero) H1.win=\(h1.button?.window?.frame ?? .zero)"); log(barState()) }
}
s.run(); app.run()
