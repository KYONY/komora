import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> CFTypeRef? { var v: CFTypeRef?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
let filter = CommandLine.arguments.dropFirst().first ?? ""
for app in NSWorkspace.shared.runningApplications where (app.bundleIdentifier ?? "").contains(filter) {
  let ax = AXUIElementCreateApplication(app.processIdentifier)
  guard let bar = attr(ax, "AXExtrasMenuBar") else { continue }
  for k in (attr(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
    var names: CFArray?; AXUIElementCopyAttributeNames(k, &names)
    print("== \(app.bundleIdentifier!)")
    for n in (names as? [String]) ?? [] { if n == "AXChildren" || n == "AXParent" || n == "AXTopLevelUIElement" || n == "AXWindow" { continue }; print("   \(n) = \(attr(k, n).map{ "\($0)" }?.replacingOccurrences(of: "\n", with: " ") ?? "nil")") }
    var acts: CFArray?; AXUIElementCopyActionNames(k, &acts); print("   actions: \(acts as? [String] ?? [])")
  }
}
