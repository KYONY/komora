import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { log("trusted=\(AXIsProcessTrusted()) wins=\(agentWindows().count)"); displayRows(); exit(0) }
app.run()
