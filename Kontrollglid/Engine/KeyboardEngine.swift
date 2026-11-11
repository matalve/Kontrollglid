import AppKit
import CoreGraphics

/// Translates Windows-style shortcuts into their macOS equivalents.
final class KeyboardEngine {
    private var tap: EventTap?
    /// A modifier we hold down on the user's behalf while they hold another:
    /// Cmd while Alt is held for the app switcher, Ctrl while Win is held for
    /// switching desktops. The system has to see the real modifier go down and
    /// stay down, or these multi-step gestures end after the first step.
    private struct Hold {
        let physical: Modifiers
        let synthetic: Modifiers
        let keyCode: UInt16

        static let appSwitcher = Hold(physical: .option, synthetic: .command, keyCode: KeyCode.command)
        static let desktopSwitcher = Hold(physical: .command, synthetic: .control, keyCode: KeyCode.control)

        func translate(_ held: Modifiers) -> Modifiers {
            held.subtracting(physical).union(synthetic)
        }
    }

    private var hold: Hold?
    /// Keys whose key-down we swallowed, so the key-up is swallowed too.
    private var swallowed = Set<UInt16>()

    func start() -> Bool {
        guard tap == nil else { return true }
        tap = EventTap(events: [.keyDown, .keyUp, .flagsChanged]) { [weak self] type, event in
            guard let self else { return event }
            return self.handle(type, event)
        }
        return tap != nil
    }

    func stop() {
        endHold(held: [])
        tap = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        if Synthetic.isSynthetic(event) { return event }
        let held = Modifiers(event.flags)

        if type == .flagsChanged {
            // Alt released: let go of the Cmd we were holding for the switcher.
            guard let hold else { return event }
            if held.contains(hold.physical) {
                // Shift pressed mid-switch: the system must keep seeing our
                // modifier held, or it takes this as the modifier being released.
                Synthetic.setModifiers(hold.translate(held), on: event)
            } else {
                endHold(held: held)
            }
            return event
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp, swallowed.remove(keyCode) != nil { return nil }

        if let hold, held.contains(hold.physical) {
            // Arrows, Q, Esc and Tab should all act on the open switcher, and
            // further arrows should keep stepping through desktops.
            Synthetic.apply(KeyStroke(keyCode, hold.translate(held)), to: event)
            return event
        }

        let settings = SettingsStore.shared.settings
        let front = AppState.shared.frontBundleID
        let mode = settings.rule(for: front)?.keyMode ?? .translate
        let result = KeyRemapper.remap(
            keyCode: keyCode,
            modifiers: held,
            rules: settings.keyboard.rules,
            isFinder: front == "com.apple.finder",
            isTerminal: mode == .terminal,
            altGr: Synthetic.isAltGr(event.flags)
        )
        if AppState.shared.isFrontmost {
            // Our own window never translates; it shows what would have happened.
            if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                report(KeyStroke(keyCode, held), result)
            }
            return event
        }
        guard settings.keyboard.enabled, mode != .off, isInScope(settings) else { return event }

        switch result {
        case .passthrough:
            return event
        case .keystroke(let stroke):
            Synthetic.apply(stroke, to: event)
            return event
        case .appSwitcher(let stroke):
            if type == .keyDown { beginHold(.appSwitcher, held: held) }
            Synthetic.apply(stroke, to: event)
            return event
        case .desktopSwitcher(let stroke):
            if type == .keyDown { beginHold(.desktopSwitcher, held: held) }
            Synthetic.apply(stroke, to: event)
            return event
        case .action(let action):
            if type == .keyDown {
                swallowed.insert(keyCode)
                if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { perform(action) }
            }
            return nil
        }
    }

    private func isInScope(_ settings: AppSettings) -> Bool {
        switch settings.keyboard.scope {
        case .all:
            return true
        case .externalOnly:
            let monitor = KeyboardDeviceMonitor.shared
            return monitor.isRunning && monitor.lastKeyWasExternal
        }
    }

    /// Describe a key press for the key tester in the settings window.
    private func report(_ pressed: KeyStroke, _ result: RemapResult) {
        let monitor = KeyboardDeviceMonitor.shared
        let source = !monitor.isRunning ? "unknown keyboard"
            : (monitor.lastKeyWasExternal ? "external keyboard" : "built-in keyboard")
        let outcome: String
        switch result {
        case .passthrough: outcome = "not translated"
        case .keystroke(let stroke), .appSwitcher(let stroke), .desktopSwitcher(let stroke): outcome = "becomes \(KeyNames.describe(stroke))"
        case .action(.openFinder): outcome = "opens Finder"
        }
        AppState.shared.lastKeyReport = "\(KeyNames.describe(pressed)) (code \(pressed.keyCode)), \(source): \(outcome)"
    }

    private func beginHold(_ new: Hold, held: Modifiers) {
        guard hold == nil else { return }
        hold = new
        Synthetic.postModifierKey(new.keyCode, down: true, nowHeld: new.translate(held))
    }

    private func endHold(held: Modifiers) {
        guard let hold else { return }
        self.hold = nil
        Synthetic.postModifierKey(hold.keyCode, down: false, nowHeld: held.subtracting(hold.synthetic))
    }

    private func perform(_ action: SystemAction) {
        switch action {
        case .openFinder:
            NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
        }
    }
}
