import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            ScrollTab().tabItem { Label("Scroll", systemImage: "arrow.up.and.down") }
            ButtonsTab().tabItem { Label("Mouse Buttons", systemImage: "computermouse") }
            KeyboardTab().tabItem { Label("Keyboard", systemImage: "keyboard") }
            AppsTab().tabItem { Label("Apps", systemImage: "square.grid.2x2") }
        }
        .frame(width: 620, height: 600)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject private var state = AppState.shared
    @ObservedObject private var store = SettingsStore.shared
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Permissions") {
                PermissionRow(
                    title: "Accessibility",
                    detail: "Required for everything: scrolling, mouse buttons and keys.",
                    granted: state.accessibilityGranted,
                    action: state.requestAccessibility
                )
                PermissionRow(
                    title: "Input Monitoring",
                    detail: "Only needed to tell an external keyboard from the built-in one.",
                    granted: state.inputMonitoringGranted,
                    action: state.requestInputMonitoring
                )
            }
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.launchAtLogin = $0 }
                ))
                Toggle(isOn: $store.settings.paused) {
                    Text("Pause Kontrollglid")
                    Text("Turns off scrolling, mouse buttons and shortcuts until you resume. Also in the menu bar menu.")
                }
            }
            Section {
                Button("Reset All Settings…") { confirmReset = true }
                    .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
                        Button("Reset", role: .destructive) { store.resetToDefaults() }
                    } message: {
                        Text("Your mouse button assignments and per-app rules will be lost.")
                    }
            } footer: {
                Text("Kontrollglid has no network code. Nothing leaves this Mac.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted { Button("Grant…", action: action) }
        }
    }
}

// MARK: - Scroll

private struct ScrollTab: View {
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        let mode = store.settings.scroll.wheelMode
        Form {
            Section {
                Picker("Mode", selection: $store.settings.scroll.wheelMode) {
                    Text("Smooth").tag(WheelMode.smooth)
                    Text("No acceleration").tag(WheelMode.linear)
                    Text("macOS default").tag(WheelMode.system)
                }
                DirectionPicker(title: "Direction", selection: $store.settings.scroll.mouseDirection)
                switch mode {
                case .smooth:
                    SliderRow(title: "Step", value: $store.settings.scroll.step, range: 10...100, format: "%.0f px")
                    SliderRow(title: "Speed", value: $store.settings.scroll.speed, range: 0.5...8, format: "%.1f×")
                    SliderRow(title: "Smoothness", value: $store.settings.scroll.duration, range: 1...10, format: "%.1f")
                case .linear:
                    SliderRow(title: "Lines per notch", value: $store.settings.scroll.linesPerTick, range: 1...10, step: 1, format: "%.0f")
                case .system:
                    EmptyView()
                }
            } header: {
                Text("Mouse wheel")
            } footer: {
                switch mode {
                case .smooth: Text("Animated scrolling. Step is the shortest distance one notch moves, Speed multiplies it, and Smoothness sets how long the glide lasts.")
                case .linear: Text("Every notch scrolls the same distance, with no animation and without the sluggish start macOS has.")
                case .system: Text("The wheel is left to macOS. Only the direction is changed.")
                }
            }
            if mode != .system {
                Section("Hold while scrolling the wheel to") {
                    ModifierPicker(title: "Scroll sideways", selection: $store.settings.scroll.horizontalModifier)
                    ModifierPicker(title: "Scroll faster", selection: $store.settings.scroll.dashModifier)
                    SliderRow(title: "Faster by", value: $store.settings.scroll.dashMultiplier, range: 1.5...8, format: "%.1f×")
                    if mode == .smooth {
                        ModifierPicker(title: "Pause smoothing", selection: $store.settings.scroll.bypassModifier)
                    }
                }
            }
            Section {
                DirectionPicker(title: "Direction", selection: $store.settings.scroll.trackpadDirection)
            } header: {
                Text("Trackpad")
            } footer: {
                Text("Swipes between desktops and pages always follow the Natural scrolling setting in macOS. Choose Follow macOS here to keep scrolling and swipes consistent.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct DirectionPicker: View {
    let title: String
    @Binding var selection: ScrollDirection

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Follow macOS").tag(ScrollDirection.system)
            Text("Like Windows").tag(ScrollDirection.traditional)
            Text("Natural").tag(ScrollDirection.natural)
        }
    }
}

private struct ModifierPicker: View {
    let title: String
    @Binding var selection: ModifierChoice

    var body: some View {
        Picker(title, selection: $selection) {
            Text("None").tag(ModifierChoice.none)
            Text("⇧ Shift").tag(ModifierChoice.shift)
            Text("⌃ Ctrl").tag(ModifierChoice.control)
            Text("⌥ Alt").tag(ModifierChoice.option)
            Text("⌘ Cmd / Win").tag(ModifierChoice.command)
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    let format: String

    var body: some View {
        HStack {
            Text(title).frame(width: 110, alignment: .leading)
            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
            Text(String(format: format, value))
                .monospacedDigit()
                .frame(width: 60, alignment: .trailing)
        }
    }
}

// MARK: - Mouse buttons

private struct ButtonsTab: View {
    @ObservedObject private var store = SettingsStore.shared

    private static let presets: [(String, KeyStroke)] = [
        ("Back", KeyStroke(KeyCode.leftBracket, .command)),
        ("Forward", KeyStroke(KeyCode.rightBracket, .command)),
        ("Mission Control", KeyStroke(KeyCode.up, .control)),
        ("App windows", KeyStroke(KeyCode.down, .control)),
        ("Desktop to the left", KeyStroke(KeyCode.left, .control)),
        ("Desktop to the right", KeyStroke(KeyCode.right, .control)),
        ("Copy", KeyStroke(KeyCode.c, .command)),
        ("Paste", KeyStroke(KeyCode.v, .command)),
        ("Close tab/window", KeyStroke(KeyCode.w, .command)),
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Mouse button shortcuts", isOn: $store.settings.buttonsEnabled)
            }
            Section {
                if store.settings.buttons.isEmpty {
                    Text("No buttons are assigned. They all work as the app in front decides.").foregroundStyle(.secondary)
                }
                ForEach($store.settings.buttons) { $binding in
                    HStack {
                        Text(Self.buttonName(binding.button)).frame(width: 120, alignment: .leading)
                        ShortcutRecorder(stroke: $binding.stroke)
                        Menu("Presets") {
                            ForEach(Self.presets, id: \.0) { preset in
                                Button("\(preset.0)  \(KeyNames.describe(preset.1))") { binding.stroke = preset.1 }
                            }
                        }
                        .fixedSize()
                        Spacer()
                        Button(role: .destructive) {
                            store.settings.buttons.removeAll { $0.id == binding.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                MouseButtonRecorder(title: "Add mouse button…") { button in
                    guard !store.settings.buttons.contains(where: { $0.button == button }) else { return }
                    store.settings.buttons.append(ButtonBinding(button: button, stroke: Self.presets[0].1))
                }
            } header: {
                Text("Assignments")
            } footer: {
                Text("A button without an assignment is passed to the app untouched. Most browsers and editors already use buttons 4 and 5 for back and forward, so assign those only for apps that ignore them. Left and right click cannot be reassigned.")
            }
            .disabled(!store.settings.buttonsEnabled)
        }
        .formStyle(.grouped)
    }

    private static func buttonName(_ button: Int) -> String {
        switch button {
        case 2: return "Middle button"
        case 3: return "Button 4 (back)"
        case 4: return "Button 5 (forward)"
        default: return "Button \(button + 1)"
        }
    }
}

// MARK: - Keyboard

private struct KeyboardTab: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var state = AppState.shared

    var body: some View {
        let rules = $store.settings.keyboard.rules
        Form {
            Section {
                Toggle("Windows shortcuts", isOn: $store.settings.keyboard.enabled)
                Picker("Applies to", selection: $store.settings.keyboard.scope) {
                    Text("External keyboards only").tag(KeyboardScope.externalOnly)
                    Text("All keyboards").tag(KeyboardScope.all)
                }
                .disabled(!store.settings.keyboard.enabled)
                if store.settings.keyboard.scope == .externalOnly {
                    if !state.inputMonitoringGranted {
                        Label("Needs the Input Monitoring permission (see General). Without it nothing is translated.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else if state.externalKeyboards.isEmpty {
                        Text("No external keyboard connected.").foregroundStyle(.secondary)
                    } else {
                        Text("Connected: \(state.externalKeyboards.joined(separator: ", "))").foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("On a PC keyboard Ctrl = ⌃, Alt = ⌥ and Win = ⌘. Terminals and remote desktops are handled under Apps.")
            }
            Group {
                Section("Editing") {
                    RuleToggle("Ctrl as Cmd", "Ctrl+C, V, X, Z, A, S, F, T, W … plus Ctrl+Y for redo and Ctrl/Shift+Insert", rules.ctrlToCmd)
                    RuleToggle("Home and End", "Start/end of the line. With Ctrl: start/end of the document", rules.homeEnd)
                    RuleToggle("Word navigation", "Ctrl+←/→ moves by word, Ctrl+Backspace/Delete deletes a word", rules.wordNavigation)
                    RuleToggle("AltGr as on a PC", "AltGr+7 and 0 type { }, AltGr+plus types \\, AltGr+< types |, AltGr+5 and E type €. Assumes the Swedish layout", rules.altGr)
                }
                Section("Apps and windows") {
                    RuleToggle("Alt+Tab", "Switches app, like ⌘⇥", rules.altTab)
                    RuleToggle("Alt+F4 and Ctrl+F4", "Quits the app and closes the window/tab", rules.closeQuit)
                    RuleToggle("Win key", "Win+L locks the screen, Win+E opens Finder, Win+←/→ switches desktop", rules.winKey)
                    RuleToggle("F5 and Print Screen", "Reloads and opens the screenshot tool", rules.functionKeys)
                    RuleToggle("Finder", "F2 renames, Delete moves to the Trash", rules.finderKeys)
                }
            }
            .disabled(!store.settings.keyboard.enabled)
            Section {
                Text(state.lastKeyReport ?? "Press a key or combination while this window is active.")
                    .foregroundStyle(state.lastKeyReport == nil ? .secondary : .primary)
                    .textSelection(.enabled)
            } header: {
                Text("Key tester")
            } footer: {
                Text("Shows what Kontrollglid receives and what it would be translated to. Nothing is translated in this window, and nothing is stored.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct RuleToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    init(_ title: String, _ detail: String, _ isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Per-app rules

private struct AppsTab: View {
    @ObservedObject private var store = SettingsStore.shared

    private static let scrollWidth: CGFloat = 70
    private static let keysWidth: CGFloat = 150

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("App")
                    Spacer()
                    Text("Scrolling").frame(width: Self.scrollWidth)
                    Text("Keys").frame(width: Self.keysWidth)
                    Image(systemName: "trash").hidden()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                ForEach($store.settings.appRules) { $rule in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(rule.name)
                            Text(rule.bundleID).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("Scrolling", isOn: Binding(get: { !rule.disableSmoothScroll }, set: { rule.disableSmoothScroll = !$0 }))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .frame(width: Self.scrollWidth)
                        Picker("Keys", selection: $rule.keyMode) {
                            Text("Translate").tag(KeyMode.translate)
                            Text("Terminal mode").tag(KeyMode.terminal)
                            Text("Off").tag(KeyMode.off)
                        }
                        .labelsHidden()
                        .frame(width: Self.keysWidth)
                        Button(role: .destructive) {
                            store.settings.appRules.removeAll { $0.bundleID == rule.bundleID }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove the rule for \(rule.name)")
                    }
                }
                HStack {
                    Menu("Add Running App") {
                        ForEach(runningApps(), id: \.bundleID) { app in
                            Button(app.name) { add(app) }
                        }
                    }
                    .fixedSize()
                    Button("Choose App…", action: chooseApp)
                }
            } header: {
                Text("Rules for apps that need different behaviour")
            } footer: {
                Text("""
                    Apps not listed here get everything. A rule applies while its app is frontmost.
                    Scrolling: uncheck to leave the mouse wheel to macOS in that app.
                    Keys: Terminal mode leaves Ctrl alone and makes Home/End go to the start/end of the line, while Alt+Tab and the Win key still work. Off translates nothing. Newly added apps start as Off.
                    """)
            }
        }
        .formStyle(.grouped)
    }

    private func runningApps() -> [AppRule] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppRule? in
                guard let id = app.bundleIdentifier, store.settings.rule(for: id) == nil else { return nil }
                return AppRule(bundleID: id, name: app.localizedName ?? id, keyMode: .off)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func add(_ rule: AppRule) {
        guard store.settings.rule(for: rule.bundleID) == nil else { return }
        store.settings.appRules.append(rule)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        add(AppRule(bundleID: id, name: FileManager.default.displayName(atPath: url.path), keyMode: .off))
    }
}
