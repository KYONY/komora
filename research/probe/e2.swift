import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var items: [NSStatusItem] = []
let s = Steps()
s.add(0.3, "create E1_A then E1_B (known from e1)") {
  items.append(makeItem("E1_A", title: "A1"))
  items.append(makeItem("E1_B", title: "B1"))
}
for t in [1.0, 2.0, 4.0] { s.add(t, "t+\(t)") { log("mine: " + mine()); log("winframes: " + items.map{ "\($0.button?.window?.frame ?? .zero)" }.joined(separator: " ")) } }
s.add(0.2, "create E2_C fresh") { items.append(makeItem("E2_C", title: "C2")) }
s.add(4.0, "after C") { log("mine: " + mine()) }
s.add(0.2, "snap") { snap("final") }
s.run(); app.run()
