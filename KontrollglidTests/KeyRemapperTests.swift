import XCTest

final class KeyRemapperTests: XCTestCase {
    private func remap(_ key: UInt16, _ mods: Modifiers, rules: KeyRuleSet = KeyRuleSet(), finder: Bool = false) -> RemapResult {
        KeyRemapper.remap(keyCode: key, modifiers: mods, rules: rules, isFinder: finder)
    }

    func testCtrlLetterBecomesCmd() {
        XCTAssertEqual(remap(KeyCode.c, .control), .keystroke(KeyStroke(KeyCode.c, .command)))
        XCTAssertEqual(remap(KeyCode.v, [.control, .shift]), .keystroke(KeyStroke(KeyCode.v, [.command, .shift])))
        XCTAssertEqual(remap(KeyCode.returnKey, .control), .keystroke(KeyStroke(KeyCode.returnKey, .command)))
    }

    func testCtrlYIsRedo() {
        XCTAssertEqual(remap(KeyCode.y, .control), .keystroke(KeyStroke(KeyCode.z, [.command, .shift])))
    }

    func testNativeMacShortcutsAreUntouched() {
        XCTAssertEqual(remap(KeyCode.c, .command), .passthrough)
        XCTAssertEqual(remap(KeyCode.c, []), .passthrough)
        XCTAssertEqual(remap(KeyCode.c, [.control, .option]), .passthrough)
        XCTAssertEqual(remap(KeyCode.tab, .control), .passthrough)
        XCTAssertEqual(remap(KeyCode.space, .control), .passthrough)
        XCTAssertEqual(remap(KeyCode.up, .control), .passthrough)
    }

    func testAltTabOpensSwitcher() {
        XCTAssertEqual(remap(KeyCode.tab, .option), .appSwitcher(KeyStroke(KeyCode.tab, .command)))
        XCTAssertEqual(remap(KeyCode.tab, [.option, .shift]), .appSwitcher(KeyStroke(KeyCode.tab, [.command, .shift])))
        XCTAssertEqual(remap(KeyCode.tab, .command), .passthrough)
    }

    func testHomeEnd() {
        XCTAssertEqual(remap(KeyCode.home, []), .keystroke(KeyStroke(KeyCode.left, .command)))
        XCTAssertEqual(remap(KeyCode.end, .shift), .keystroke(KeyStroke(KeyCode.right, [.command, .shift])))
        XCTAssertEqual(remap(KeyCode.home, .control), .keystroke(KeyStroke(KeyCode.up, .command)))
        XCTAssertEqual(remap(KeyCode.end, [.control, .shift]), .keystroke(KeyStroke(KeyCode.down, [.command, .shift])))
    }

    func testWordNavigation() {
        XCTAssertEqual(remap(KeyCode.left, .control), .keystroke(KeyStroke(KeyCode.left, .option)))
        XCTAssertEqual(remap(KeyCode.right, [.control, .shift]), .keystroke(KeyStroke(KeyCode.right, [.option, .shift])))
        XCTAssertEqual(remap(KeyCode.backspace, .control), .keystroke(KeyStroke(KeyCode.backspace, .option)))
        XCTAssertEqual(remap(KeyCode.forwardDelete, .control), .keystroke(KeyStroke(KeyCode.forwardDelete, .option)))
    }

    func testCloseAndQuit() {
        XCTAssertEqual(remap(KeyCode.f4, .option), .keystroke(KeyStroke(KeyCode.q, .command)))
        XCTAssertEqual(remap(KeyCode.f4, .control), .keystroke(KeyStroke(KeyCode.w, .command)))
        XCTAssertEqual(remap(KeyCode.f4, []), .passthrough)
    }

    func testInsertClipboard() {
        XCTAssertEqual(remap(KeyCode.insert, .control), .keystroke(KeyStroke(KeyCode.c, .command)))
        XCTAssertEqual(remap(KeyCode.insert, .shift), .keystroke(KeyStroke(KeyCode.v, .command)))
    }

    func testFunctionKeys() {
        XCTAssertEqual(remap(KeyCode.f5, []), .keystroke(KeyStroke(KeyCode.r, .command)))
        XCTAssertEqual(remap(KeyCode.f13, []), .keystroke(KeyStroke(KeyCode.five, [.command, .shift])))
    }

    func testFinderKeysOnlyInFinder() {
        XCTAssertEqual(remap(KeyCode.f2, [], finder: true), .keystroke(KeyStroke(KeyCode.returnKey)))
        XCTAssertEqual(remap(KeyCode.forwardDelete, [], finder: true), .keystroke(KeyStroke(KeyCode.backspace, .command)))
        XCTAssertEqual(remap(KeyCode.f2, []), .passthrough)
        XCTAssertEqual(remap(KeyCode.forwardDelete, []), .passthrough)
    }

    func testWinKey() {
        XCTAssertEqual(remap(KeyCode.l, .command), .keystroke(KeyStroke(KeyCode.q, [.control, .command])))
        XCTAssertEqual(remap(KeyCode.e, .command), .action(.openFinder))
    }

    func testDisabledRulesPassThrough() {
        var rules = KeyRuleSet()
        rules.ctrlToCmd = false
        rules.altTab = false
        rules.homeEnd = false
        rules.wordNavigation = false
        rules.closeQuit = false
        rules.functionKeys = false
        rules.winKey = false
        rules.finderKeys = false
        XCTAssertEqual(remap(KeyCode.c, .control, rules: rules), .passthrough)
        XCTAssertEqual(remap(KeyCode.tab, .option, rules: rules), .passthrough)
        XCTAssertEqual(remap(KeyCode.home, [], rules: rules), .passthrough)
        XCTAssertEqual(remap(KeyCode.left, .control, rules: rules), .passthrough)
        XCTAssertEqual(remap(KeyCode.f4, .option, rules: rules), .passthrough)
        XCTAssertEqual(remap(KeyCode.f5, [], rules: rules), .passthrough)
        XCTAssertEqual(remap(KeyCode.l, .command, rules: rules), .passthrough)
        XCTAssertEqual(remap(KeyCode.f2, [], rules: rules, finder: true), .passthrough)
    }

    // MARK: - Second round

    func testWinArrowsSwitchDesktop() {
        XCTAssertEqual(remap(KeyCode.left, .command), .desktopSwitcher(KeyStroke(KeyCode.left, .control)))
        XCTAssertEqual(remap(KeyCode.right, [.command, .control]), .desktopSwitcher(KeyStroke(KeyCode.right, .control)))
        XCTAssertEqual(remap(KeyCode.up, .command), .desktopSwitcher(KeyStroke(KeyCode.up, .control)))
        XCTAssertEqual(remap(KeyCode.down, .command), .desktopSwitcher(KeyStroke(KeyCode.down, .control)))
        XCTAssertEqual(remap(KeyCode.left, [.command, .shift]), .action(.moveWindow(toNext: false)))
        XCTAssertEqual(remap(KeyCode.right, [.command, .shift]), .action(.moveWindow(toNext: true)))
        XCTAssertEqual(remap(KeyCode.up, [.command, .shift]), .passthrough)
    }

    func testAltGrTypesPCCharacters() {
        let rules = KeyRuleSet()
        func altGr(_ key: UInt16, _ mods: Modifiers = .option, right: Bool = true) -> RemapResult {
            KeyRemapper.remap(keyCode: key, modifiers: mods, rules: rules, isFinder: false, altGr: right)
        }
        XCTAssertEqual(altGr(KeyCode.seven), .keystroke(KeyStroke(KeyCode.eight, [.option, .shift])))
        XCTAssertEqual(altGr(KeyCode.zero), .keystroke(KeyStroke(KeyCode.nine, [.option, .shift])))
        XCTAssertEqual(altGr(KeyCode.five), .keystroke(KeyStroke(KeyCode.four, .shift)))
        // Left Alt and AltGr+8 ([ on both systems) are untouched.
        XCTAssertEqual(altGr(KeyCode.seven, right: false), .passthrough)
        XCTAssertEqual(altGr(KeyCode.eight), .passthrough)
    }

    func testTerminalModeKeepsCtrlButFixesHomeEnd() {
        func terminal(_ key: UInt16, _ mods: Modifiers = []) -> RemapResult {
            KeyRemapper.remap(keyCode: key, modifiers: mods, rules: KeyRuleSet(), isFinder: false, isTerminal: true)
        }
        XCTAssertEqual(terminal(KeyCode.c, .control), .passthrough)
        XCTAssertEqual(terminal(KeyCode.left, .control), .passthrough)
        XCTAssertEqual(terminal(KeyCode.home), .keystroke(KeyStroke(KeyCode.a, .control)))
        XCTAssertEqual(terminal(KeyCode.end), .keystroke(KeyStroke(KeyCode.e, .control)))
        XCTAssertEqual(terminal(KeyCode.home, .shift), .passthrough)
        XCTAssertEqual(terminal(KeyCode.tab, .option), .appSwitcher(KeyStroke(KeyCode.tab, .command)))
    }

    func testOldTerminalExclusionBecomesTerminalMode() throws {
        let old = #"{"appRules":[{"bundleID":"com.apple.Terminal","name":"Terminal","disableSmoothScroll":false,"disableKeyRemap":true},{"bundleID":"com.apple.Notes","name":"Notes","disableSmoothScroll":false,"disableKeyRemap":true},{"bundleID":"x.y","name":"X","disableSmoothScroll":true,"disableKeyRemap":false}]}"#
        let rules = try XCTUnwrap(AppSettings.decode(Data(old.utf8))).appRules
        XCTAssertEqual(rules.map(\.keyMode), [.terminal, .off, .translate])
    }

    func testOldDefaultButtonAssignmentsAreDropped() throws {
        let custom = ButtonBinding(button: 2, stroke: KeyStroke(KeyCode.up, .control))
        var old = AppSettings()
        old.buttons = [
            ButtonBinding(button: 3, stroke: KeyStroke(KeyCode.leftBracket, .command)),
            ButtonBinding(button: 4, stroke: KeyStroke(KeyCode.c, .command)),
            custom,
        ]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json["version"] = nil
        let migrated = try XCTUnwrap(AppSettings.decode(JSONSerialization.data(withJSONObject: json)))
        XCTAssertEqual(migrated.buttons.map(\.button), [4, 2])
        // Once migrated, a deliberately re-added ⌘[ assignment is kept.
        let again = try XCTUnwrap(AppSettings.decode(JSONEncoder().encode(old)))
        XCTAssertEqual(again.buttons.count, 3)
    }
}
