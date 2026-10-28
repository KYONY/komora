import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> CFTypeRef? { var v: CFTypeRef?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
struct Row { let x: Double; let y: Double; let w: Double; let app: String; let pid: pid_t; let title: String }
var rows: [Row] = []
for app in NSWorkspace.shared.runningApplications {
  let ax = AXUIElementCreateApplication(app.processIdentifier)
  AXUIElementSetMessagingTimeout(ax, 0.5)
  guard let bar = attr(ax, "AXExtrasMenuBar") else { continue }
  let kids = (attr(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement]) ?? []
  for k in kids {
    var p = CGPoint.zero, s = CGSize.zero
    if let pv = attr(k, kAXPositionAttribute) { AXValueGetValue(pv as! AXValue, .cgPoint, &p) }
    if let sv = attr(k, kAXSizeAttribute) { AXValueGetValue(sv as! AXValue, .cgSize, &s) }
    let t = [attr(k, kAXTitleAttribute) as? String, attr(k, kAXDescriptionAttribute) as? String, attr(k, kAXIdentifierAttribute) as? String].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" | ")
    rows.append(Row(x: p.x, y: p.y, w: s.width, app: app.bundleIdentifier ?? app.localizedName ?? "?", pid: app.processIdentifier, title: t))
  }
}
for r in rows.sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) }) {
  print(String(format: "x=%7.1f y=%6.1f w=%6.1f  %@  [%@]", r.x, r.y, r.w, r.app, r.title))
}
