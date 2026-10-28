import AppKit
import Carbon.HIToolbox
import KomoraCore
import ServiceManagement

// Komora — hides every menu bar icon left of its divider on macOS 27.
//
// Mechanism (measured, research/logs/e10-e14): the app's own defaults key
// "NSStatusItem Preferred Position <autosaveName>" places an item on every
// registration; a bigger key sits further left. On collapse Komora registers
// pushers with keys just above the divider's key, so they land directly left
// of it, and gives them a long length. macOS 27 overflows the bar from the
// left, so every icon left of the pushers goes into the system « menu. On
// expand the pushers are removed. No Accessibility, no Screen Recording.

// A user ⌘-drag pins every item that exists at that moment: MenuBarAgent keeps
// its position and deletes the seed key, and later seeds are ignored
// (measured 2026-10-28 17:48-17:52, Komora.log). So probes take a fresh name
// per run, pushers move to a new generation when a collapse fails, and the
// divider moves to a new generation when Komora has to move a pinned one.
var dividerName: String {
    let g = defaults.integer(forKey: "dividerGeneration")
    return g == 0 ? "Komora_Divider" : "Komora_Divider_g\(g)"
}
func pusherName(_ i: Int) -> String { "Komora_P\(defaults.integer(forKey: "pusherGeneration"))_\(i)" }
func freshProbeName() -> String { "Komora_Probe_\(UUID().uuidString.prefix(8))" }
func bump(_ key: String) { defaults.set(defaults.integer(forKey: key) + 1, forKey: key) }
func positionKey(_ name: String) -> String { "NSStatusItem Preferred Position \(name)" }

let defaults = UserDefaults.standard
let storedKeyName = "dividerKey"
let offsetKey = "dividerOffset"
let stepKeysKey = "dividerStepKeys"

// MARK: - Log

let logURL: URL = {
    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
    return dir.appendingPathComponent("Komora.log")
}()

func log(_ message: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
    if let h = try? FileHandle(forWritingTo: logURL) {
        h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
    } else {
        try? line.write(to: logURL, atomically: true, encoding: .utf8)
    }
}

// MARK: - Status items

@MainActor
func frame(_ item: NSStatusItem) -> Verify.Frame {
    let f = item.button?.window?.frame ?? .zero
    return Verify.Frame(minX: f.minX, width: f.width)
}

@MainActor
/// `key == nil` registers without a seed, so a position the user set by
/// ⌘-drag (held by MenuBarAgent) is kept.
func register(_ name: String, key: Double?, length: CGFloat) -> NSStatusItem {
    if let key { defaults.set(key, forKey: positionKey(name)) }
    let item = NSStatusBar.system.statusItem(withLength: length)
    item.autosaveName = name
    item.isVisible = true
    return item
}

/// Waits until the item's frame stops moving (layout settles in ~0.1 s, e12).
@MainActor
func settled(_ items: [NSStatusItem], timeout: TimeInterval = 2) async {
    var last = items.map { frame($0) }
    var stableSince = Date()
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        try? await Task.sleep(nanoseconds: 30_000_000)
        let now = items.map { frame($0) }
        if now != last { last = now; stableSince = Date() }
        if Date().timeIntervalSince(stableSince) > 0.2 { return }
    }
}

// MARK: - Controller

@MainActor
final class Komora: NSObject, NSMenuDelegate {
    private var divider: NSStatusItem!
    private var pushers: [NSStatusItem] = []
    private(set) var isCollapsed = false
    private var lastVerified: Bool?
    private var busy = false
    private let hotkey = Hotkey()

    /// After a user ⌘-drag of the divider, macOS deletes our seed key and
    /// MenuBarAgent keeps the position (measured 2026-10-28 17:48-17:50, Komora.log).
    var userPlaced: Bool {
        defaults.object(forKey: positionKey(dividerName)) == nil && defaults.object(forKey: storedKeyName) != nil
    }

    var dividerKey: Double {
        get {
            if let k = defaults.object(forKey: positionKey(dividerName)) as? Double, k > 0 { return k }
            if let k = defaults.object(forKey: storedKeyName) as? Double, k > 0 { return k }
            return Keys.defaultDivider
        }
        set { defaults.set(newValue, forKey: storedKeyName) }
    }

    func start() {
        if defaults.object(forKey: storedKeyName) == nil { defaults.set(0, forKey: offsetKey) } // first launch: default place
        let key = dividerKey
        if userPlaced {
            placeDivider(key: nil)
        } else {
            placeDivider(key: key)
            defaults.set(key, forKey: storedKeyName)
        }
        hotkey.onPress = { [weak self] in self?.toggle() }
        hotkey.register()
        log("start key=\(key) userPlaced=\(userPlaced) hotkey=\(hotkey.statusText)")

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshIfCollapsed(reason: "screens") }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshIfCollapsed(reason: "wake") }
        }
        Task { @MainActor in await settled([divider]); writeState() }
    }

    // MARK: Toggle
    //
    // Requests set `wanted`; `pump` applies it when no work is in flight, so a
    // shortcut pressed during a collapse or a nudge is applied, not dropped.

    private var wanted = false
    private var needsRefresh = false
    private var refreshWork: DispatchWorkItem?

    func toggle() { request(!wanted) }
    func collapse() { request(true) }
    func expand() { request(false) }

    private func request(_ collapsed: Bool) {
        wanted = collapsed
        pump()
    }

    private func pump() {
        guard !busy else { return }
        if wanted && (!isCollapsed || needsRefresh) {
            needsRefresh = false
            removePushers()
            isCollapsed = false
            busy = true
            Task { @MainActor in
                await adoptIfPinned()
                var ok = await placePushers()
                if !ok {
                    // Pinned pusher names (a ⌘-drag while collapsed) or a moved
                    // divider: fresh pusher names, fresh calibration, once.
                    log("collapse: pushers not adjacent, retrying with new pusher names")
                    removePushers()
                    bump("pusherGeneration")
                    await adoptIfPinned(force: true)
                    ok = await placePushers()
                }
                lastVerified = ok
                isCollapsed = true
                busy = false
                updateGlyph(); writeState()
                log("collapse verified=\(ok) divider=\(frame(divider)) pushers=\(pushers.map { Int(frame($0).minX) })")
                pump()
            }
        } else if !wanted && isCollapsed {
            removePushers()
            isCollapsed = false
            lastVerified = nil
            needsRefresh = false
            updateGlyph(); writeState()
            log("expand")
        }
    }

    private func placePushers() async -> Bool {
        let plan = Geometry.plan(widths: NSScreen.screens.map { $0.frame.width })
        let key = dividerKey
        for i in 0..<plan.count {
            let p = register(pusherName(i), key: Keys.pusher(i, divider: key), length: plan.unit)
            p.button?.isEnabled = false
            p.button?.setAccessibilityElement(false)
            pushers.append(p)
        }
        await settled(pushers + [divider])
        return Verify.pushersAdjacent(divider: frame(divider), pushers: pushers.map { frame($0) })
    }

    /// The user ⌘-dragged the divider, so MenuBarAgent holds its position and
    /// our seed is gone. Find the key of that position by bisection with a
    /// fresh-named probe (left of the divider iff probe key > divider key; own
    /// frames only). Repeated when the divider's x changes or a collapse fails.
    /// A pinned divider and seeded pushers do not order by one rule (measured
    /// 17:54:37: pushers above the calibrated key landed right of it). So adopt
    /// the user's spot: calibrate, then recreate the divider under a new name
    /// seeded at that key — it lands in the same place and obeys keys again.
    /// `force`: adopt even though our seed is still there. Measured 2026-10-28
    /// 20:33:51: after a ⌘-drag the seed key can survive while MenuBarAgent
    /// ignores it, so a failed collapse check is the only sign.
    private func adoptIfPinned(force: Bool = false) async {
        guard userPlaced || force else { return }
        await calibrateIfNeeded(force: true)
        let before = frame(divider)
        bump("dividerGeneration")
        defaults.removeObject(forKey: offsetKey) // moved by hand: the step count is unknown
        placeDivider(key: dividerKey)
        await settled([divider])
        log("adopt: \(dividerName) key \(dividerKey) x \(Int(before.minX)) -> \(Int(frame(divider).minX))")
    }

    private func calibrateIfNeeded(force: Bool = false) async {
        guard userPlaced || force else { return }
        await settled([divider])
        let x = Double(frame(divider).minX)
        if !force, let cx = defaults.object(forKey: "calibratedX") as? Double, cx == x { return }
        let probeName = freshProbeName()
        var probe: NSStatusItem?
        func isLeft(_ key: Double) async -> Bool {
            if let p = probe { NSStatusBar.system.removeStatusItem(p) }
            let p = register(probeName, key: key, length: 1)
            p.button?.isEnabled = false
            probe = p
            await settled([p, divider])
            let f = frame(p), d = frame(divider)
            return f.minX > 0 && f.maxX <= d.minX + 3
        }
        defer { if let p = probe { NSStatusBar.system.removeStatusItem(p) } }
        var lo = Keys.step, hi = 1024.0
        if await isLeft(lo) { log("calibrate: probe left of divider at the lowest key"); return }
        while !(await isLeft(hi)) {
            hi *= 2
            if hi > 100_000 { log("calibrate: probe never left of divider"); return }
        }
        while hi - lo > Keys.step {
            let mid = Keys.snap((lo + hi) / 2)
            if mid <= lo || mid >= hi { break }
            if await isLeft(mid) { hi = mid } else { lo = mid }
        }
        dividerKey = (lo + hi) / 2
        await settled([divider])
        defaults.set(Double(frame(divider).minX), forKey: "calibratedX")
        log("calibrate: divider key in \(lo)..\(hi), x \(Int(frame(divider).minX))")
    }

    private func removePushers() {
        for p in pushers { NSStatusBar.system.removeStatusItem(p) }
        pushers.removeAll()
    }

    /// Debounced: displays and wake send bursts, and the screen list can be
    /// partial at first. Re-plans from the screens present 1 s after the last event.
    private func refreshIfCollapsed(reason: String) {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.wanted else { return }
                log("refresh (\(reason)) screens=\(NSScreen.screens.map { Int($0.frame.width) })")
                self.needsRefresh = true
                self.pump()
            }
        }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    // MARK: Nudge (move the divider one icon without ⌘-drag)

    enum Direction { case left, right }

    func nudge(_ direction: Direction) {
        guard !busy else { return }
        removePushers()
        isCollapsed = false
        busy = true
        Task { @MainActor in
            defer { busy = false; updateGlyph(); writeState(); pump() }
            await adoptIfPinned()
            let before = frame(divider)
            let target = dividerOffset.map { $0 + (direction == .right ? 1 : -1) }

            // A step taken before: jump straight to its key, no probe search.
            // Accept it only if the divider really moved the right way; an app
            // that quit or launched since can make the stored key stale.
            if let t = target, let cached = stepKeys[String(t)] {
                placeDivider(key: cached)
                await settled([divider])
                let dx = frame(divider).minX - before.minX
                if frame(divider).minX > 0, direction == .right ? dx > 2 : dx < -2 {
                    dividerKey = cached
                    defaults.set(t, forKey: offsetKey)
                    log("nudge \(direction): remembered step \(t), key \(cached) x \(Int(before.minX)) -> \(Int(frame(divider).minX))")
                    return
                }
                log("nudge \(direction): remembered step \(t) is stale, searching")
                placeDivider(key: dividerKey)
                await settled([divider])
            }

            guard let newKey = await findNeighbourKey(direction) else {
                log("nudge \(direction): no neighbour, divider stays")
                NSSound.beep(); return
            }
            dividerKey = newKey
            placeDivider(key: newKey)
            await settled([divider])
            if let t = target {
                defaults.set(t, forKey: offsetKey)
                var keys = stepKeys
                keys[String(t)] = newKey
                defaults.set(keys, forKey: stepKeysKey)
            }
            log("nudge \(direction): key \(newKey) x \(Int(before.minX)) -> \(Int(frame(divider).minX))")
        }
    }

    /// Divider keys found for each step from the default place, so a step
    /// taken once is not searched again ("0" is the default place).
    var stepKeys: [String: Double] {
        var keys = defaults.dictionary(forKey: stepKeysKey) as? [String: Double] ?? [:]
        keys["0"] = keys["0"] ?? Keys.defaultDivider // the default place is always known
        return keys
    }

    /// Steps from the default place: +1 = one icon more hidden. nil after a ⌘-drag.
    var dividerOffset: Int? { defaults.object(forKey: offsetKey) as? Int }
    var offsetText: String {
        guard let n = dividerOffset else { return "custom" }
        return n == 0 ? "0" : (n > 0 ? "+\(n)" : "−\(-n)")
    }

    /// Puts the divider back at the first-launch value under a fresh name, so a
    /// name pinned by a ⌘-drag does not hold it in place.
    func resetDivider() {
        guard !busy else { return }
        removePushers()
        isCollapsed = false
        bump("dividerGeneration")
        defaults.removeObject(forKey: "calibratedX")
        dividerKey = Keys.defaultDivider
        defaults.set(0, forKey: offsetKey)
        placeDivider(key: Keys.defaultDivider)
        log("reset divider: \(dividerName) key \(Keys.defaultDivider)")
        Task { @MainActor in await settled([divider]); writeState(); pump() }
    }

    /// Bisection over keys with a probe item, own frames only (no permission).
    /// A probe whose key lies between the divider's key and the neighbour's
    /// key sits right next to the divider; past the neighbour it does not.
    /// The new key keeps a margin from the found boundary, because a foreign
    /// key can sit within 2^-10 of it (measured: a foreign value between 498.999 and 499, research/logs/komora-app.log).
    private func findNeighbourKey(_ direction: Direction) async -> Double? {
        let probeName = freshProbeName()
        let k = dividerKey
        let step = Keys.step
        let sign: Double = direction == .left ? 1 : -1
        var probe: NSStatusItem?
        func probeAt(_ key: Double) async -> (left: Bool, right: Bool) {
            if let p = probe { NSStatusBar.system.removeStatusItem(p) }
            let p = register(probeName, key: key, length: 1)
            p.button?.isEnabled = false
            probe = p
            await settled([p, divider])
            let d = frame(divider), f = frame(p)
            log("probe \(direction) key=\(key) probe=\(Int(f.minX))w\(Int(f.width)) divider=\(Int(d.minX))w\(Int(d.width))")
            return (Verify.adjacentLeft(f, of: d), Verify.adjacentRight(f, of: d))
        }
        func adjacent(_ key: Double) async -> Bool {
            let r = await probeAt(key)
            return direction == .left ? r.left : r.right
        }
        defer { if let p = probe { NSStatusBar.system.removeStatusItem(p) } }

        // 1. Bracket the neighbour's key: near is adjacent (or the divider's
        //    own key), far is past the neighbour.
        var near = k
        var far = k + sign * step
        var dist = 1.0
        while await adjacent(far) {
            near = far
            if direction == .right && near <= step { return nil } // nothing left to pass on the right
            far = k + sign * dist
            dist *= 2
            if far > 100_000 { return nil } // divider is already leftmost
            if far < step { far = step }    // probe the lowest keys before giving up
        }
        // 2. Bisect to one step.
        while abs(far - near) > step {
            let mid = Keys.snap((near + far) / 2)
            if mid == near || mid == far { break }
            if await adjacent(mid) { near = mid } else { far = mid }
        }
        // 3. New key = far plus a margin, so the divider lands just past the
        //    neighbour and not past the next one. Check it with the probe at
        //    `far`: it must end up directly between the divider and the
        //    neighbour. Shrink the margin if something else is in the way.
        var margin = 0.25
        while margin >= step {
            let candidate = far + sign * margin
            if candidate <= 0 { margin /= 4; continue }
            placeDivider(key: candidate)
            await settled([divider])
            let r = await probeAt(far)
            if direction == .left ? r.right : r.left { return candidate }
            margin /= 4
        }
        // Could not confirm; put the divider back where it was.
        placeDivider(key: k)
        return nil
    }

    /// (Re)registers the divider at `key` and wires its button.
    private func placeDivider(key: Double?) {
        if let old = divider { NSStatusBar.system.removeStatusItem(old) }
        divider = register(dividerName, key: key, length: NSStatusItem.variableLength)
        if let b = divider.button {
            b.target = self
            b.action = #selector(clicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
            b.setAccessibilityLabel("Komora divider")
        }
        updateGlyph()
    }

    // MARK: UI

    private func updateGlyph() {
        guard let b = divider?.button else { return }
        let name = isCollapsed ? "chevron.left" : "chevron.right"
        b.image = NSImage(systemSymbolName: name, accessibilityDescription: isCollapsed ? "Show icons" : "Hide icons")
        b.image?.isTemplate = true
        b.toolTip = isCollapsed ? "Komora: icons hidden — click to show" : "Komora: click to hide icons left of this divider"
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            toggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        @discardableResult func item(_ title: String, _ symbol: String, _ action: Selector?, key: String = "") -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.target = action == nil || action == #selector(NSApplication.terminate(_:)) ? nil : self
            i.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            if action == nil { i.isEnabled = false }
            menu.addItem(i)
            return i
        }
        item(isCollapsed ? "Show Icons" : "Hide Icons", isCollapsed ? "eye" : "eye.slash", #selector(menuToggle))
        menu.addItem(.separator())
        let stepper = NSMenuItem()
        stepper.view = StepperMenuRow(title: "Hidden icons", symbol: "eye.slash.circle", value: offsetText,
                                      minusTip: "Hide one icon fewer (divider moves left)",
                                      plusTip: "Hide one icon more (divider moves right)") { [weak self, weak menu] more in
            menu?.cancelTracking()
            self?.nudge(more ? .right : .left)
        }
        menu.addItem(stepper)
        item("Reset Divider Position", "arrow.counterclockwise", #selector(menuResetDivider))
        menu.addItem(.separator())
        item("Shortcut: \(hotkey.statusText)", "keyboard", nil)
        item("Change Shortcut…", "command", #selector(menuChangeShortcut))
        let login = NSMenuItem()
        login.view = SwitchMenuRow(title: "Launch at Login", symbol: "power", isOn: LaunchAtLogin.isEnabled) { [weak self] on in
            LaunchAtLogin.set(on); self?.writeState()
        }
        menu.addItem(login)
        if let v = lastVerified {
            item(v ? "Last collapse: verified" : "Last collapse: an icon may sit next to the divider",
                 v ? "checkmark.circle" : "exclamationmark.triangle", nil)
        }
        menu.addItem(.separator())
        item("Quit Komora", "xmark.circle", #selector(NSApplication.terminate(_:)), key: "q")
        divider.menu = menu
        divider.button?.performClick(nil)
        divider.menu = nil
    }

    private lazy var recorder: ShortcutRecorder = {
        let r = ShortcutRecorder(hotkey: hotkey)
        r.onChange = { [weak self] in self?.writeState() }
        return r
    }()

    @objc private func menuToggle() { toggle() }
    @objc private func menuLeft() { nudge(.left) }
    @objc private func menuRight() { nudge(.right) }
    @objc private func menuResetDivider() { resetDivider() }
    @objc private func menuChangeShortcut() { recorder.show() }

    // MARK: State (for scripts and tests)

    func writeState() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Komora")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let d = divider.map { frame($0) }
        let state: [String: Any] = [
            "collapsed": isCollapsed,
            "verified": lastVerified as Any? ?? NSNull(),
            "dividerKey": dividerKey,
            "dividerMinX": d?.minX ?? -1,
            "dividerOffset": dividerOffset as Any? ?? NSNull(),
            "pushers": pushers.map { ["minX": frame($0).minX, "width": frame($0).width] },
            "hotkey": hotkey.statusText,
            "launchAtLogin": LaunchAtLogin.isEnabled,
            "updated": ISO8601DateFormatter().string(from: Date()),
        ]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dir.appendingPathComponent("state.json"))
        }
    }

    // URL scheme: komora://collapse | expand | toggle | left | right | reset-divider | login-on | login-off | shortcut | state
    func handle(url: URL) {
        switch url.host ?? url.path {
        case "collapse": collapse()
        case "expand": expand()
        case "toggle": toggle()
        case "left": nudge(.left)
        case "right": nudge(.right)
        case "reset-divider": resetDivider()
        case "login-on": LaunchAtLogin.set(true); writeState()
        case "login-off": LaunchAtLogin.set(false); writeState()
        case "shortcut": recorder.show()
        default: writeState()
        }
    }
}

// MARK: - Menu row with a switch

/// A menu row laid out like a standard item (icon, title) with an NSSwitch on
/// the right, so an on/off setting reads as a setting, not as a selection.
final class SwitchMenuRow: NSView {
    private let onToggle: (Bool) -> Void
    private let toggle = NSSwitch()

    init(title: String, symbol: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        self.onToggle = onToggle
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 26))
        autoresizingMask = [.width]

        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .labelColor
        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 0)
        toggle.controlSize = .small
        toggle.state = isOn ? .on : .off
        toggle.target = self
        toggle.action = #selector(changed)
        toggle.setAccessibilityLabel(title)

        for v in [icon, label, toggle] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 12),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func changed() { onToggle(toggle.state == .on) }
}

/// A menu row with an icon, a title and a − / + control on the right.
final class StepperMenuRow: NSView {
    private let onStep: (Bool) -> Void
    private let control: NSSegmentedControl

    init(title: String, symbol: String, value: String, minusTip: String, plusTip: String, onStep: @escaping (_ more: Bool) -> Void) {
        self.onStep = onStep
        control = NSSegmentedControl(images: [NSImage(systemSymbolName: "minus", accessibilityDescription: minusTip)!,
                                              NSImage(systemSymbolName: "plus", accessibilityDescription: plusTip)!],
                                     trackingMode: .momentary, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 28))
        autoresizingMask = [.width]
        control.target = self
        control.action = #selector(clicked)
        control.controlSize = .small
        control.setToolTip(minusTip, forSegment: 0)
        control.setToolTip(plusTip, forSegment: 1)

        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .labelColor
        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 0)
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.toolTip = "Steps from the default divider place (0). custom = moved by ⌘-drag; Reset Divider Position starts counting again."
        for v in [icon, label, valueLabel, control] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 12),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            control.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 8),
            control.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            control.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func clicked() { onStep(control.selectedSegment == 1) }
}

// MARK: - Launch at login (SMAppService, macOS 13+)

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log("launch at login \(on ? "on" : "off") failed: \(error.localizedDescription)")
        }
        log("launch at login: \(SMAppService.mainApp.status.rawValue) (0 off, 1 on, 2 needs approval, 3 not found)")
    }
}

// MARK: - Global shortcut (Carbon, needs no permission)

final class Hotkey {
    static let defaultCode = UInt32(kVK_ANSI_B)
    static let defaultMods = UInt32(cmdKey | optionKey)

    var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false
    private(set) var statusText = "not registered"

    var code: UInt32 { UInt32(defaults.object(forKey: "hotkeyKeyCode") as? Int ?? Int(Hotkey.defaultCode)) }
    var mods: UInt32 { UInt32(defaults.object(forKey: "hotkeyModifiers") as? Int ?? Int(Hotkey.defaultMods)) }

    /// Registers the stored shortcut (default ⌥⌘B).
    @discardableResult
    func register() -> OSStatus {
        installHandler()
        unregister()
        let id = EventHotKeyID(signature: OSType(0x4B4D5241), id: 1) // 'KMRA'
        let err = RegisterEventHotKey(code, mods, id, GetApplicationEventTarget(), 0, &ref)
        let label = Hotkey.describe(code: code, mods: mods)
        statusText = err == noErr ? label : "\(label) unavailable — another app holds it"
        return err
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    /// Stores and registers a new shortcut. Keeps the old one if the new one is taken.
    func change(code newCode: UInt32, mods newMods: UInt32) -> Bool {
        let oldCode = defaults.object(forKey: "hotkeyKeyCode"), oldMods = defaults.object(forKey: "hotkeyModifiers")
        defaults.set(Int(newCode), forKey: "hotkeyKeyCode")
        defaults.set(Int(newMods), forKey: "hotkeyModifiers")
        if register() == noErr { log("shortcut: \(statusText)"); return true }
        defaults.set(oldCode, forKey: "hotkeyKeyCode")
        defaults.set(oldMods, forKey: "hotkeyModifiers")
        register()
        return false
    }

    func reset() {
        defaults.removeObject(forKey: "hotkeyKeyCode")
        defaults.removeObject(forKey: "hotkeyModifiers")
        register()
        log("shortcut reset: \(statusText)")
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            let hk = Unmanaged<Hotkey>.fromOpaque(data!).takeUnretainedValue()
            DispatchQueue.main.async { hk.onPress?() }
            return noErr
        }, 1, &spec, me, nil)
    }

    static func carbonMods(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    static func describe(code: UInt32, mods: UInt32) -> String {
        var s = ""
        if mods & UInt32(controlKey) != 0 { s += "⌃" }
        if mods & UInt32(optionKey) != 0 { s += "⌥" }
        if mods & UInt32(shiftKey) != 0 { s += "⇧" }
        if mods & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyName(code)
    }

    static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    /// Key name from the ASCII-capable layout, so a Cyrillic layout still shows "B".
    static func keyName(_ code: UInt32) -> String {
        if let s = specialKeys[Int(code)] { return s }
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "key \(code)" }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var dead: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress!
            return UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return "key \(code)" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}

// MARK: - Shortcut recorder window

/// A small window that records the next key combination. It reads keys only
/// while its own window is key, so it needs no Input Monitoring permission.
@MainActor
final class ShortcutRecorder: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private var monitor: Any?
    private let label = NSTextField(labelWithString: "")
    private let hotkey: Hotkey
    var onChange: (() -> Void)?

    init(hotkey: Hotkey) { self.hotkey = hotkey }

    func show() {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 150),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Komora Shortcut"
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let title = NSTextField(labelWithString: "Press the new shortcut.")
        title.font = .boldSystemFont(ofSize: 13)
        label.stringValue = "Current: \(hotkey.statusText). Use ⌘, ⌥ or ⌃. Esc cancels."
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 3
        let reset = NSButton(title: "Reset to ⌥⌘B", target: self, action: #selector(resetShortcut))
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(close))
        let buttons = NSStackView(views: [reset, cancel])
        let stack = NSStackView(views: [title, label, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = NSView()
        panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            stack.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),
            label.widthAnchor.constraint(equalToConstant: 320),
        ])
        window = panel

        // The global shortcut would swallow its own combination while recording.
        hotkey.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            self.record(event)
            return nil
        }
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func record(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == UInt16(kVK_Escape) && flags.isEmpty { close(); return }
        guard !flags.intersection([.command, .option, .control]).isEmpty else {
            label.stringValue = "Add ⌘, ⌥ or ⌃ to the key."
            return
        }
        let code = UInt32(event.keyCode), mods = Hotkey.carbonMods(flags)
        if hotkey.change(code: code, mods: mods) {
            onChange?()
            close()
        } else {
            label.stringValue = "\(Hotkey.describe(code: code, mods: mods)) is taken by another app. Try another."
        }
    }

    @objc private func resetShortcut() {
        hotkey.reset()
        onChange?()
        close()
    }

    @objc func close() { window?.close() }

    func windowWillClose(_ notification: Notification) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        window = nil
        hotkey.register() // restores the stored shortcut if recording was cancelled
        onChange?()
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    let komora = MainActor.assumeIsolated { Komora() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)),
                                                     forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        MainActor.assumeIsolated { komora.start() }
    }

    @objc func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let s = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue, let url = URL(string: s) else { return }
        MainActor.assumeIsolated { komora.handle(url: url) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
