import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
let name = "E12_PROBE"
let key = "NSStatusItem Preferred Position \(name)"
var probe: NSStatusItem?
func neighbours(_ x: CGFloat) -> String {
  let rows = axRows().filter { !$0.mine && $0.y < 10 && $0.x > 0 && $0.x < 2320 }
  let l = rows.last { $0.x < x }; let r = rows.first { $0.x > x }
  return "\(l.map { "\($0.app.split(separator: ".").last!)\($0.title.isEmpty ? "" : "[\($0.title.prefix(8))]")" } ?? "-") < P < \(r.map { "\($0.app.split(separator: ".").last!)\($0.title.isEmpty ? "" : "[\($0.title.prefix(8))]")" } ?? "-")"
}
var keys: [Double] = [150, 250, 400, 600, 800, 950]
func next() {
  guard !keys.isEmpty else { log("done"); exit(0) }
  let k = keys.removeFirst()
  if let p = probe { NSStatusBar.system.removeStatusItem(p); probe = nil }
  UserDefaults.standard.set(k, forKey: key)
  let t0 = Date()
  let p = makeItem(name, title: "•"); probe = p
  var last: CGFloat = -12345; var stableSince = Date()
  Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { t in
    let x = p.button?.window?.frame.minX ?? -1
    if x != last { last = x; stableSince = Date() }
    if Date().timeIntervalSince(stableSince) > 0.4 && x > 0 {
      t.invalidate()
      let settle = stableSince.timeIntervalSince(t0)
      log(String(format: "key=%7.2f x=%6.0f settle=%.2fs  %@", k, x, settle, neighbours(x)))
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { next() }
    }
    if Date().timeIntervalSince(t0) > 5 { t.invalidate(); log("key=\(k) timeout x=\(x)"); next() }
  }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { next() }
app.run()
