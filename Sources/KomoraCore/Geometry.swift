import CoreGraphics

/// Pusher geometry for macOS 27's overflowing menu bar.
///
/// macOS 27 overflows the bar from the left: when status items do not fit, the
/// leftmost go into the system « menu. Komora places pushers directly left of
/// its divider and inflates them, so everything further left overflows.
/// Unit formula follows Pelmet 0.10 (MIT): half the narrowest display, minus a
/// 64 pt margin. 449 pt is the only unit measured end to end on this setup
/// (research/logs/e13.log); larger single-item lengths are unverified.
public enum Geometry {
    /// AppKit draws 16 pt of chrome around each item's length.
    public static let chrome: CGFloat = 16
    static let margin: CGFloat = 64
    public static let maxPushers = 32

    public struct Plan: Equatable {
        public let unit: CGFloat
        public let count: Int
    }

    /// `widths` are display widths in points (no-notch displays).
    public static func plan(widths: [CGFloat]) -> Plan {
        guard let narrow = widths.min(), let wide = widths.max(), narrow > 0 else {
            return Plan(unit: 200, count: 8)
        }
        let unit = max(50, (narrow / 2 - margin).rounded(.down))
        // One spare: excess pushers overflow themselves harmlessly.
        let count = Int((wide / (unit + chrome)).rounded(.up)) + 1
        return Plan(unit: unit, count: min(count, maxPushers))
    }
}

/// Order keys for "NSStatusItem Preferred Position <name>".
/// Bigger key = further left (research/logs/e12.log).
public enum Keys {
    /// Search grid for the divider: 2^-10, exact in Float32 below 2^13.
    public static let step: Double = 1.0 / 1024
    /// Pusher spacing: 2^-14, exact in Float32 below 1024, so 32 pushers span
    /// 1/512 above the divider and a foreign key can hardly fall between them.
    public static let pusherStep: Double = 1.0 / 16384
    public static let defaultDivider: Double = 250

    public static func pusher(_ index: Int, divider: Double) -> Double {
        divider + Double(index + 1) * pusherStep
    }

    /// `k` rounded down to the step grid.
    public static func snap(_ k: Double) -> Double {
        (k / step).rounded(.down) * step
    }
}

/// Collapse verification from own window frames only (no permission).
public enum Verify {
    public struct Frame: Equatable {
        public let minX: CGFloat
        public let width: CGFloat
        public init(minX: CGFloat, width: CGFloat) { self.minX = minX; self.width = width }
        public var maxX: CGFloat { minX + width }
    }

    /// The divider must be visible, and the visible pushers must form one
    /// unbroken chain ending at the divider: a gap means a foreign icon.
    /// Between pushers a gap under `chainGap` is allowed: no status item is
    /// narrower than 16 pt (Bluetooth, measured), and the leftmost pusher can sit
    /// 8 pt off when it reaches the app menus (Komora.log 17:10:46).
    public static let chainGap: CGFloat = 10
    public static func pushersAdjacent(divider: Frame, pushers: [Frame], tolerance: CGFloat = 3) -> Bool {
        guard divider.minX > 0, divider.width > 0 else { return false }
        // Every pusher got a window and a length; at least one overflowed, which
        // shows the pushers reached past the left end of the bar (e13: x = 0).
        guard !pushers.isEmpty, pushers.allSatisfy({ $0.width > 0 }),
              pushers.contains(where: { $0.minX <= 0 }) else { return false }
        let visible = pushers.filter { $0.minX > 0 }.sorted { $0.minX > $1.minX }
        var edge = divider.minX
        for (i, p) in visible.enumerated() {
            guard abs(p.maxX - edge) <= (i == 0 ? tolerance : chainGap) else { return false }
            edge = p.minX
        }
        return true
    }

    /// Probe directly left of the divider (used by the nudge search).
    public static func adjacentLeft(_ probe: Frame, of divider: Frame, tolerance: CGFloat = 3) -> Bool {
        probe.minX > 0 && abs(probe.maxX - divider.minX) <= tolerance
    }
    public static func adjacentRight(_ probe: Frame, of divider: Frame, tolerance: CGFloat = 3) -> Bool {
        probe.minX > 0 && abs(probe.minX - divider.maxX) <= tolerance
    }
}
