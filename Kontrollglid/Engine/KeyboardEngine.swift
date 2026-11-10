import AppKit
import CoreGraphics

/// Translates Windows-style shortcuts into their macOS equivalents.
final class KeyboardEngine {
    private var tap: EventTap?
    /// True while we are holding a synthetic Cmd for the app switcher.
    private var switcherActive = false
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
        endSwitcher(held: [])
        tap = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        if Synthetic.isSynthetic(event) { return event }
        let held = Modifiers(event.flags)

        if type == .flagsChanged {
            // Alt released: let go of the Cmd we were holding for the switcher.
            guard switcherActive else { return event }
            if held.contains(.option) {
                // Shift pressed mid-switch: the system must keep seeing Cmd held,
                // or it takes this as Cmd being released and closes the switcher.
                Synthetic.setModifiers(held.subtracting(.option).union(.command), on: event)
            } else {
                endSwitcher(held: held)
            }
            return event
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp, swallowed.remove(keyCode) != nil { return nil }

        if switcherActive, held.contains(.option) {
            // Arrows, Q, Esc and Tab should all act on the open switcher.
            Synthetic.apply(KeyStroke(keyCode, held.subtracting(.option).union(.command)), to: event)
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
            if type == .keyDown, !switcherActive {
                switcherActive = true
                Synthetic.postCommand(down: true, otherModifiers: stroke.modifiers)
            }
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
        case .keystroke(let stroke), .appSwitcher(let stroke): outcome = "becomes \(KeyNames.describe(stroke))"
        case .action(.openFinder): outcome = "opens Finder"
        }
        AppState.shared.lastKeyReport = "\(KeyNames.describe(pressed)) (code \(pressed.keyCode)), \(source): \(outcome)"
    }

    private func endSwitcher(held: Modifiers) {
        guard switcherActive else { return }
        switcherActive = false
        Synthetic.postCommand(down: false, otherModifiers: held)
    }

    private func perform(_ action: SystemAction) {
        switch action {
        case .openFinder:
            NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
        }
    }
}
