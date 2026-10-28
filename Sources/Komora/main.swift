import AppKit
import Carbon.HIToolbox
import KomoraCore

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
                    await adoptIfPinned()
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
    private func adoptIfPinned() async {
        guard userPlaced else { return }
        await calibrateIfNeeded(force: true)
        let before = frame(divider)
        bump("dividerGeneration")
        placeDivider(key: dividerKey)
        await settled([divider])
        log("adopt: \(dividerName) key \(dividerKey) x \(Int(before.minX)) -> \(Int(frame(divider).minX))")
    }

    private func calibrateIfNeeded(force: Bool = false) async {
        guard userPlaced else { return }
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
            guard let newKey = await findNeighbourKey(direction) else {
                log("nudge \(direction): no neighbour, divider stays")
                NSSound.beep(); return
            }
            dividerKey = newKey
            placeDivider(key: newKey)
            await settled([divider])
            log("nudge \(direction): key \(newKey) x \(Int(before.minX)) -> \(Int(frame(divider).minX))")
        }
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
        menu.addItem(withTitle: isCollapsed ? "Show Icons" : "Hide Icons", action: #selector(menuToggle), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Move Divider One Icon Left", action: #selector(menuLeft), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Move Divider One Icon Right", action: #selector(menuRight), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let hk = NSMenuItem(title: "Shortcut: \(hotkey.statusText)", action: nil, keyEquivalent: "")
        hk.isEnabled = false
        menu.addItem(hk)
        if let v = lastVerified {
            let st = NSMenuItem(title: v ? "Last collapse: verified" : "Last collapse: an icon may sit next to the divider", action: nil, keyEquivalent: "")
            st.isEnabled = false
            menu.addItem(st)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Komora", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        divider.menu = menu
        divider.button?.performClick(nil)
        divider.menu = nil
    }

    @objc private func menuToggle() { toggle() }
    @objc private func menuLeft() { nudge(.left) }
    @objc private func menuRight() { nudge(.right) }

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
            "pushers": pushers.map { ["minX": frame($0).minX, "width": frame($0).width] },
            "hotkey": hotkey.statusText,
            "updated": ISO8601DateFormatter().string(from: Date()),
        ]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dir.appendingPathComponent("state.json"))
        }
    }

    // URL scheme: komora://collapse | expand | toggle | left | right | state
    func handle(url: URL) {
        switch url.host ?? url.path {
        case "collapse": collapse()
        case "expand": expand()
        case "toggle": toggle()
        case "left": nudge(.left)
        case "right": nudge(.right)
        default: writeState()
        }
    }
}

// MARK: - Global shortcut (Carbon, needs no permission)

final class Hotkey {
    var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?
    private(set) var statusText = "not registered"

    func register() {
        // Default ⌥⌘B; override: defaults write dev.komora.Komora hotkeyKeyCode -int N; hotkeyModifiers -int M (Carbon masks).
        let code = UInt32(defaults.object(forKey: "hotkeyKeyCode") as? Int ?? kVK_ANSI_B)
        let mods = UInt32(defaults.object(forKey: "hotkeyModifiers") as? Int ?? (cmdKey | optionKey))
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            let hk = Unmanaged<Hotkey>.fromOpaque(data!).takeUnretainedValue()
            DispatchQueue.main.async { hk.onPress?() }
            return noErr
        }, 1, &spec, me, nil)
        let id = EventHotKeyID(signature: OSType(0x4B4D5241), id: 1) // 'KMRA'
        let err = RegisterEventHotKey(code, mods, id, GetApplicationEventTarget(), 0, &ref)
        let label = Hotkey.describe(code: code, mods: mods)
        statusText = err == noErr ? label : "\(label) unavailable (error \(err)) — another app holds it"
    }

    static func describe(code: UInt32, mods: UInt32) -> String {
        var s = ""
        if mods & UInt32(controlKey) != 0 { s += "⌃" }
        if mods & UInt32(optionKey) != 0 { s += "⌥" }
        if mods & UInt32(shiftKey) != 0 { s += "⇧" }
        if mods & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + (code == UInt32(kVK_ANSI_B) ? "B" : "key \(code)")
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
