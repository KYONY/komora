import AppKit
import ApplicationServices
import ObjectiveC

func attr(_ e: AXUIElement, _ a: String) -> CFTypeRef? { var v: CFTypeRef?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
let myPid = ProcessInfo.processInfo.processIdentifier
func log(_ s: String) { print(s); fflush(stdout) }

struct AXRow { let x: Double; let w: Double; let y: Double; let app: String; let mine: Bool; let title: String }
func axRows() -> [AXRow] {
  var rows: [AXRow] = []
  for app in NSWorkspace.shared.runningApplications {
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(ax, 0.5)
    guard let bar = attr(ax, "AXExtrasMenuBar") else { continue }
    for k in (attr(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
      var p = CGPoint.zero, s = CGSize.zero
      if let pv = attr(k, kAXPositionAttribute) { AXValueGetValue(pv as! AXValue, .cgPoint, &p) }
      if let sv = attr(k, kAXSizeAttribute) { AXValueGetValue(sv as! AXValue, .cgSize, &s) }
      let t = [attr(k, kAXTitleAttribute) as? String, attr(k, kAXDescriptionAttribute) as? String].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:"|")
      let name = (app.bundleIdentifier ?? "?").split(separator: ".").suffix(2).joined(separator: ".")
      rows.append(AXRow(x: p.x, w: s.width, y: p.y, app: name, mine: app.processIdentifier == myPid, title: t))
    }
  }
  return rows.sorted { $0.x < $1.x }
}
func snap(_ label: String) {
  let ml = NSEvent.mouseLocation
  log("--- \(label)  mouse=(\(Int(ml.x)),\(Int(ml.y)))")
  for r in axRows() { log(String(format: "  %@ x=%7.1f w=%6.1f y=%4.1f %@ [%@]", r.mine ? "**" : "  ", r.x, r.w, r.y, r.app, r.title)) }
}
func mine() -> String { axRows().filter{$0.mine}.map{ "\($0.title)@\(Int($0.x))w\(Int($0.w))" }.joined(separator: " ") }
func diag(_ it: NSStatusItem) -> String {
  let sel = NSSelectorFromString("_diagnosticsDict")
  guard it.responds(to: sel), let d = it.perform(sel)?.takeUnretainedValue() else { return "nodiag" }
  return "\(d)"
}
func callInt(_ obj: AnyObject, _ name: String) -> Int32 {
  let sel = NSSelectorFromString(name); guard let m = class_getInstanceMethod(type(of: obj), sel) else { return -999 }
  typealias F = @convention(c) (AnyObject, Selector) -> Int32
  return unsafeBitCast(method_getImplementation(m), to: F.self)(obj, sel)
}
func callFloat(_ obj: AnyObject, _ name: String) -> Float {
  let sel = NSSelectorFromString(name); guard let m = class_getInstanceMethod(type(of: obj), sel) else { return -999 }
  typealias F = @convention(c) (AnyObject, Selector) -> Float
  return unsafeBitCast(method_getImplementation(m), to: F.self)(obj, sel)
}
func setInt(_ obj: AnyObject, _ name: String, _ v: Int32) {
  let sel = NSSelectorFromString(name); guard let m = class_getInstanceMethod(type(of: obj), sel) else { log("no \(name)"); return }
  typealias F = @convention(c) (AnyObject, Selector, Int32) -> Void
  unsafeBitCast(method_getImplementation(m), to: F.self)(obj, sel, v)
}
func makeItem(_ name: String, title: String, length: CGFloat = NSStatusItem.variableLength) -> NSStatusItem {
  let it = NSStatusBar.system.statusItem(withLength: length)
  it.autosaveName = name
  it.button?.title = title
  it.button?.setAccessibilityTitle(title)
  it.isVisible = true
  return it
}
func makePriorityItem(_ name: String, title: String, priority: Int) -> NSStatusItem? {
  let bar = NSStatusBar.system
  let sel = NSSelectorFromString("_statusItemWithLength:withPriority:")
  guard let m = class_getInstanceMethod(NSStatusBar.self, sel) else { log("no prio api"); return nil }
  typealias F = @convention(c) (AnyObject, Selector, Double, Int) -> Unmanaged<NSStatusItem>
  let it = unsafeBitCast(method_getImplementation(m), to: F.self)(bar, sel, Double(NSStatusItem.variableLength), priority).takeRetainedValue()
  it.autosaveName = name; it.button?.title = title; it.button?.setAccessibilityTitle(title); it.isVisible = true
  return it
}
final class Steps {
  var list: [(Double, String, () -> Void)] = []
  func add(_ delay: Double, _ label: String, _ f: @escaping () -> Void) { list.append((delay, label, f)) }
  func run() {
    var t = 0.0
    for (d, label, f) in list { t += d; DispatchQueue.main.asyncAfter(deadline: .now() + t) { log("### \(label)"); f() } }
    DispatchQueue.main.asyncAfter(deadline: .now() + t + 1) { log("### done"); exit(0) }
  }
}

/// Compact state of the bar copy AX reports: chevron position, own items, first foreign items.
func barState() -> String {
  let rows = axRows()
  let chev = rows.first { $0.title.contains("Show Hidden") }
  let own = rows.filter { $0.mine }.map { "\($0.title)@\(Int($0.x))w\(Int($0.w))" }.joined(separator: " ")
  let foreign = rows.filter { !$0.mine && !$0.title.contains("Show Hidden") }.prefix(4).map { "\($0.app.split(separator: ".").last!)@\(Int($0.x))" }.joined(separator: " ")
  return "« \(chev.map { "@\(Int($0.x))" } ?? "none") | own: \(own) | first-foreign: \(foreign)"
}

func chevronElement() -> AXUIElement? {
  for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.MenuBarAgent" {
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    guard let bar = attr(ax, "AXExtrasMenuBar") else { continue }
    for k in (attr(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
      if ((attr(k, kAXDescriptionAttribute) as? String) ?? "").contains("Show Hidden") { return k }
    }
  }
  return nil
}
func dumpTree(_ e: AXUIElement, _ depth: Int = 0, max: Int = 6) {
  if depth > max { return }
  let role = attr(e, kAXRoleAttribute) as? String ?? "?"
  let t = [attr(e, kAXTitleAttribute) as? String, attr(e, kAXDescriptionAttribute) as? String, attr(e, kAXIdentifierAttribute) as? String].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:"|")
  var p = CGPoint.zero, s = CGSize.zero
  if let pv = attr(e, kAXPositionAttribute) { AXValueGetValue(pv as! AXValue, .cgPoint, &p) }
  if let sv = attr(e, kAXSizeAttribute) { AXValueGetValue(sv as! AXValue, .cgSize, &s) }
  log(String(repeating: "  ", count: depth) + "\(role) [\(t)] @\(Int(p.x)),\(Int(p.y)) \(Int(s.width))x\(Int(s.height))")
  for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { dumpTree(c, depth + 1, max: max) }
}
func dumpAgentWindows() {
  for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.MenuBarAgent" {
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    for w in (attr(ax, kAXWindowsAttribute) as? [AXUIElement]) ?? [] { dumpTree(w) }
    log("(agent windows: \((attr(ax, kAXWindowsAttribute) as? [AXUIElement])?.count ?? -1))")
  }
}

func agentWindows() -> [AXUIElement] {
  guard let a = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.MenuBarAgent" }) else { return [] }
  let ax = AXUIElementCreateApplication(a.processIdentifier)
  return (attr(ax, kAXWindowsAttribute) as? [AXUIElement]) ?? []
}
func frameOf(_ e: AXUIElement) -> CGRect {
  var p = CGPoint.zero, s = CGSize.zero
  if let pv = attr(e, kAXPositionAttribute) { AXValueGetValue(pv as! AXValue, .cgPoint, &p) }
  if let sv = attr(e, kAXSizeAttribute) { AXValueGetValue(sv as! AXValue, .cgSize, &s) }
  return CGRect(origin: p, size: s)
}
func label(_ e: AXUIElement) -> String {
  [attr(e, kAXTitleAttribute) as? String, attr(e, kAXDescriptionAttribute) as? String, attr(e, kAXIdentifierAttribute) as? String].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:"|")
}
/// One line per display window: host views sorted by x with first-child label.
func displayRows() {
  for w in agentWindows() {
    let wf = frameOf(w)
    var parts: [(CGFloat, String)] = []
    for h in (attr(w, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
      let f = frameOf(h); let role = attr(h, kAXRoleAttribute) as? String ?? "?"
      let kid = ((attr(h, kAXChildrenAttribute) as? [AXUIElement]) ?? []).first
      var l = label(h); if l.isEmpty, let kid { l = label(kid); if l.isEmpty, let g = ((attr(kid, kAXChildrenAttribute) as? [AXUIElement]) ?? []).first { l = label(g) } }
      if role == "AXApplication" { continue }
      parts.append((f.minX, "\(l.isEmpty ? "·" : String(l.prefix(14)))@\(Int(f.minX))w\(Int(f.width))"))
    }
    log("  win@\(Int(wf.minX)) w\(Int(wf.width)) n=\(parts.count): " + parts.sorted { $0.0 < $1.0 }.map { $0.1 }.joined(separator: " "))
  }
}

func callVoid(_ obj: AnyObject, _ name: String) {
  let sel = NSSelectorFromString(name); guard let m = class_getInstanceMethod(type(of: obj), sel) else { log("no \(name)"); return }
  typealias F = @convention(c) (AnyObject, Selector) -> Void
  unsafeBitCast(method_getImplementation(m), to: F.self)(obj, sel)
}
func callBool(_ obj: AnyObject, _ name: String, _ v: Bool) {
  let sel = NSSelectorFromString(name); guard let m = class_getInstanceMethod(type(of: obj), sel) else { log("no \(name)"); return }
  typealias F = @convention(c) (AnyObject, Selector, Bool) -> Void
  unsafeBitCast(method_getImplementation(m), to: F.self)(obj, sel, v)
}
func getBool(_ obj: AnyObject, _ name: String) -> Bool {
  let sel = NSSelectorFromString(name); guard let m = class_getInstanceMethod(type(of: obj), sel) else { return false }
  typealias F = @convention(c) (AnyObject, Selector) -> Bool
  return unsafeBitCast(method_getImplementation(m), to: F.self)(obj, sel)
}
func callPoint(_ obj: AnyObject, _ name: String, _ p: CGPoint) {
  let sel = NSSelectorFromString(name); guard let m = class_getInstanceMethod(type(of: obj), sel) else { log("no \(name)"); return }
  typealias F = @convention(c) (AnyObject, Selector, CGPoint) -> Void
  unsafeBitCast(method_getImplementation(m), to: F.self)(obj, sel, p)
}
func ownOrder(_ items: [NSStatusItem]) -> String {
  items.sorted { ($0.button?.window?.frame.minX ?? 0) < ($1.button?.window?.frame.minX ?? 0) }.map { "\($0.button?.title ?? "?")@\(Int($0.button?.window?.frame.minX ?? -1))" }.joined(separator: " ")
}
