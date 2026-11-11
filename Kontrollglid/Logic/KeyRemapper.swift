import Foundation

/// Which groups of Windows-style shortcuts are translated.
struct KeyRuleSet: Codable, Equatable {
    /// Ctrl+C/V/X/Z/A/S/F/T/W… → Cmd+…, Ctrl+Y → redo, Ctrl/Shift+Insert.
    var ctrlToCmd = true
    /// Ctrl+←/→ moves by word, Ctrl+Backspace/Delete deletes a word.
    var wordNavigation = true
    /// Home/End go to start/end of line, Ctrl+Home/End to start/end of document.
    var homeEnd = true
    /// Alt+Tab opens the app switcher.
    var altTab = true
    /// Alt+F4 quits the app, Ctrl+F4 closes the window/tab.
    var closeQuit = true
    /// F5 reloads, Print Screen opens the screenshot tool.
    var functionKeys = true
    /// Win+L locks the screen, Win+E opens Finder, Win+←/→ switches desktop,
    /// Win+↑ opens Mission Control and Win+↓ shows the app's windows.
    var winKey = true
    /// AltGr gives the characters printed on a Swedish PC keyboard: { } \ | €.
    var altGr = true
    /// In Finder: F2 renames, Delete moves to the Trash.
    var finderKeys = true
}

enum SystemAction: Equatable {
    case openFinder
}

enum RemapResult: Equatable {
    /// Leave the key event untouched.
    case passthrough
    /// Replace the key event with this keystroke.
    case keystroke(KeyStroke)
    /// Like `.keystroke`, but Cmd must stay held until Alt is released so the
    /// app switcher stays open.
    case appSwitcher(KeyStroke)
    /// Like `.keystroke`, but Ctrl must stay held until Win is released so
    /// several desktops can be stepped through in one go.
    case desktopSwitcher(KeyStroke)
    /// Swallow the key event and perform an action instead.
    case action(SystemAction)
}

/// Pure translation from "what a Windows user pressed on a PC keyboard" to
/// "what macOS expects". On a PC keyboard Ctrl = Control, Alt = Option and
/// Win = Command.
enum KeyRemapper {
    /// - Parameters:
    ///   - isTerminal: the front app is a terminal, where Ctrl already means
    ///     what a Windows user expects and must be left alone.
    ///   - altGr: the Option that is held is the right-hand one.
    static func remap(
        keyCode: UInt16,
        modifiers m: Modifiers,
        rules: KeyRuleSet,
        isFinder: Bool,
        isTerminal: Bool = false,
        altGr: Bool = false
    ) -> RemapResult {
        let ctrl = m.contains(.control)
        let alt = m.contains(.option)
        let cmd = m.contains(.command)
        let shift = m.intersection(.shift)

        if rules.altTab, keyCode == KeyCode.tab, alt, !cmd, !ctrl {
            return .appSwitcher(KeyStroke(KeyCode.tab, shift.union(.command)))
        }

        if rules.closeQuit, keyCode == KeyCode.f4 {
            if m == [.option] { return .keystroke(KeyStroke(KeyCode.q, .command)) }
            if m == [.control] { return .keystroke(KeyStroke(KeyCode.w, .command)) }
        }

        if rules.altGr, altGr, m == [.option], let stroke = swedishAltGr[keyCode] {
            return .keystroke(stroke)
        }

        if rules.winKey, cmd, !alt, shift.isEmpty, KeyCode.arrows.contains(keyCode) {
            return .desktopSwitcher(KeyStroke(keyCode, .control))
        }

        if rules.homeEnd, keyCode == KeyCode.home || keyCode == KeyCode.end, !cmd, !alt {
            let isHome = keyCode == KeyCode.home
            if isTerminal {
                // Shells use Ctrl+A / Ctrl+E for start / end of line.
                guard m.isEmpty else { return .passthrough }
                return .keystroke(KeyStroke(isHome ? KeyCode.a : KeyCode.e, .control))
            }
            let target: UInt16 = ctrl
                ? (isHome ? KeyCode.up : KeyCode.down)
                : (isHome ? KeyCode.left : KeyCode.right)
            return .keystroke(KeyStroke(target, shift.union(.command)))
        }

        if rules.wordNavigation, !isTerminal, ctrl, !cmd, !alt {
            if keyCode == KeyCode.left || keyCode == KeyCode.right {
                return .keystroke(KeyStroke(keyCode, shift.union(.option)))
            }
            if shift.isEmpty, keyCode == KeyCode.backspace || keyCode == KeyCode.forwardDelete {
                return .keystroke(KeyStroke(keyCode, .option))
            }
        }

        if rules.ctrlToCmd, keyCode == KeyCode.insert {
            if m == [.control] { return .keystroke(KeyStroke(KeyCode.c, .command)) }
            if m == [.shift] { return .keystroke(KeyStroke(KeyCode.v, .command)) }
        }

        if rules.functionKeys, m.isEmpty {
            if keyCode == KeyCode.f5, !isTerminal { return .keystroke(KeyStroke(KeyCode.r, .command)) }
            if keyCode == KeyCode.f13 { return .keystroke(KeyStroke(KeyCode.five, [.command, .shift])) }
        }

        if rules.finderKeys, isFinder, m.isEmpty {
            if keyCode == KeyCode.f2 { return .keystroke(KeyStroke(KeyCode.returnKey)) }
            if keyCode == KeyCode.forwardDelete { return .keystroke(KeyStroke(KeyCode.backspace, .command)) }
        }

        if rules.winKey, m == [.command] {
            if keyCode == KeyCode.l { return .keystroke(KeyStroke(KeyCode.q, [.control, .command])) }
            if keyCode == KeyCode.e { return .action(.openFinder) }
        }

        if rules.ctrlToCmd, !isTerminal, ctrl, !cmd, !alt, KeyCode.mainBlock.contains(keyCode) {
            if keyCode == KeyCode.y, shift.isEmpty {
                return .keystroke(KeyStroke(KeyCode.z, [.command, .shift]))
            }
            return .keystroke(KeyStroke(keyCode, m.subtracting(.control).union(.command)))
        }

        return .passthrough
    }

    /// What AltGr+key must become on the macOS Swedish layout to type the
    /// character printed on a Swedish PC keyboard. AltGr+2/3/4/8/9 (@ £ $ [ ])
    /// are already the same on both.
    private static let swedishAltGr: [UInt16: KeyStroke] = [
        KeyCode.seven: KeyStroke(KeyCode.eight, [.option, .shift]), // {
        KeyCode.zero: KeyStroke(KeyCode.nine, [.option, .shift]), // }
        KeyCode.plus: KeyStroke(KeyCode.seven, [.option, .shift]), // \
        KeyCode.isoSection: KeyStroke(KeyCode.seven, .option), // |
        KeyCode.grave: KeyStroke(KeyCode.seven, .option), // |
        KeyCode.five: KeyStroke(KeyCode.four, .shift), // €
        KeyCode.e: KeyStroke(KeyCode.four, .shift), // €
    ]
}
