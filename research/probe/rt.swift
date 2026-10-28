import AppKit
import ObjectiveC
func dump(_ name: String) {
  guard let c: AnyClass = NSClassFromString(name) else { print("no", name); return }
  for (cls, label) in [(c, "-"), (object_getClass(c)!, "+")] {
    var n: UInt32 = 0
    guard let ms = class_copyMethodList(cls, &n) else { continue }
    let names = (0..<Int(n)).map { NSStringFromSelector(method_getName(ms[$0])) }.sorted()
    print("== \(name) \(label) (\(n))"); print(names.joined(separator: "\n"))
  }
}
_ = NSApplication.shared; _ = NSStatusBar.system
for n in CommandLine.arguments.dropFirst() { dump(n) }
