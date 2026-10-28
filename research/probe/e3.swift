import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
var a: NSStatusItem!
let s = Steps()
s.add(0.3, "create A") { a = makeItem("E1_A", title: "A1") }
for L in [300.0, 480.0, 500.0, 520.0, 560.0, 800.0, 1100.0, 1200.0, 2000.0, 37.0] {
  s.add(2.5, "len \(L)") {
    a.length = L
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      let rows = axRows()
      let vis = rows.filter { $0.y < 10 && $0.x >= 0 }
      log("L=\(L) item.length=\(a.length) win=\(a.button?.window?.frame ?? .zero) mine=\(mine())")
      log("   visible-left-edge=\(Int(vis.first?.x ?? -1)) n=\(vis.count) : " + vis.map{ "\($0.app.split(separator: ".").last!)@\(Int($0.x))" }.joined(separator: " "))
    }
  }
}
s.run(); app.run()
