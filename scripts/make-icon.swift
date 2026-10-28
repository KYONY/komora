// Draws Komora's app icon and writes Resources/AppIcon.icns.
// usage: swift scripts/make-icon.swift   (from the repo root)
//
// Motif: a menu bar strip with the divider chevron; the icons left of it fade
// out as they slide into the "komora" (Ukrainian: storeroom).
import AppKit

let size: CGFloat = 1024

func draw(in ctx: CGContext) {
    // macOS icon grid: 824 pt body centred on 1024, corner radius ~185.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(shape); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
    ctx.restoreGState()

    // Background: deep indigo to teal.
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(srgbRed: 0.10, green: 0.12, blue: 0.28, alpha: 1).cgColor,
        NSColor(srgbRed: 0.07, green: 0.36, blue: 0.45, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Soft top highlight.
    let hl = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor.white.withAlphaComponent(0.16).cgColor, NSColor.white.withAlphaComponent(0).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(hl, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])

    // Menu bar strip.
    let bar = CGRect(x: 150, y: 452, width: 724, height: 150)
    ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 75, cornerHeight: 75, transform: nil))
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.14).cgColor)
    ctx.fillPath()

    // Icons left of the divider, fading and shrinking towards the left.
    let cy = bar.midY
    let hidden: [(x: CGFloat, s: CGFloat, a: CGFloat)] = [(560, 66, 0.85), (460, 58, 0.50), (372, 50, 0.26), (296, 42, 0.11)]
    for h in hidden {
        let r = CGRect(x: h.x - h.s / 2, y: cy - h.s / 2, width: h.s, height: h.s)
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: h.s * 0.28, cornerHeight: h.s * 0.28, transform: nil))
        ctx.setFillColor(NSColor.white.withAlphaComponent(h.a).cgColor)
        ctx.fillPath()
    }

    // Divider chevron "›".
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(30); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 668, y: cy + 52))
    ctx.addLine(to: CGPoint(x: 720, y: cy))
    ctx.addLine(to: CGPoint(x: 668, y: cy - 52))
    ctx.strokePath()

    // Items that stay visible, right of the divider.
    for x: CGFloat in [796] {
        ctx.addEllipse(in: CGRect(x: x - 22, y: cy - 22, width: 44, height: 44))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.fillPath()
    }

    // Storeroom shelves below the bar: where the hidden icons go.
    let stored: [(x: CGFloat, y: CGFloat, s: CGFloat, a: CGFloat)] = [
        (330, 339, 52, 0.30), (410, 339, 52, 0.22), (490, 339, 52, 0.30),
        (360, 229, 52, 0.18), (440, 229, 52, 0.24),
    ]
    for b in stored {
        let r = CGRect(x: b.x - b.s / 2, y: b.y, width: b.s, height: b.s)
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: b.s * 0.28, cornerHeight: b.s * 0.28, transform: nil))
        ctx.setFillColor(NSColor.white.withAlphaComponent(b.a).cgColor)
        ctx.fillPath()
    }
    ctx.setLineCap(.round)
    for (i, y) in [CGFloat(330), 220].enumerated() {
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(i == 0 ? 0.22 : 0.13).cgColor)
        ctx.setLineWidth(18)
        ctx.move(to: CGPoint(x: 250, y: y)); ctx.addLine(to: CGPoint(x: 774, y: y))
        ctx.strokePath()
    }
    ctx.restoreGState()
}

func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    let ctx = g.cgContext
    ctx.scaleBy(x: CGFloat(px) / size, y: CGFloat(px) / size)
    draw(in: ctx)
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! png(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! png(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! fm.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
try! png(1024).write(to: URL(fileURLWithPath: "Resources/AppIcon.png"))

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "wrote Resources/AppIcon.icns and Resources/AppIcon.png" : "iconutil failed")
