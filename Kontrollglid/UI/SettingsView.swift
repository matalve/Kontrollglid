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
        .frame(width: 600, height: 540)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject private var state = AppState.shared
    @ObservedObject private var store = SettingsStore.shared

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
            Section("Features") {
                Picker("Mouse wheel", selection: $store.settings.scroll.wheelMode) {
                    Text("Smooth scrolling").tag(WheelMode.smooth)
                    Text("No acceleration").tag(WheelMode.linear)
                    Text("macOS default").tag(WheelMode.system)
                }
                Toggle("Mouse buttons as shortcuts", isOn: $store.settings.buttonsEnabled)
                Toggle("Windows shortcuts", isOn: $store.settings.keyboard.enabled)
            }
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.launchAtLogin = $0 }
                ))
                Button("Reset all settings") { store.resetToDefaults() }
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
        Form {
            Section("Direction") {
                DirectionPicker(title: "Mouse wheel", selection: $store.settings.scroll.mouseDirection)
                DirectionPicker(title: "Trackpad", selection: $store.settings.scroll.trackpadDirection)
            }
            Section {
                Picker("Mode", selection: $store.settings.scroll.wheelMode) {
                    Text("Smooth scrolling").tag(WheelMode.smooth)
                    Text("No acceleration").tag(WheelMode.linear)
                    Text("macOS default").tag(WheelMode.system)
                }
                switch store.settings.scroll.wheelMode {
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
                Text("No acceleration: every notch of the wheel scrolls the same distance, with no animation and without the sluggish start macOS has.")
            }
            Section("Hold to") {
                ModifierPicker(title: "Scroll sideways", selection: $store.settings.scroll.horizontalModifier)
                ModifierPicker(title: "Scroll faster", selection: $store.settings.scroll.dashModifier)
                SliderRow(title: "Fast factor", value: $store.settings.scroll.dashMultiplier, range: 1.5...8, format: "%.1f×")
                ModifierPicker(title: "Pause smoothing", selection: $store.settings.scroll.bypassModifier)
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
                Toggle("Enabled", isOn: $store.settings.buttonsEnabled)
            }
            Section {
                if store.settings.buttons.isEmpty {
                    Text("No buttons are assigned.").foregroundStyle(.secondary)
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
                Text("Left and right click cannot be reassigned. Mission Control and desktop switching need the standard macOS shortcuts to be enabled.")
            }
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
        Form {
            Section {
                Toggle("Translate Windows shortcuts", isOn: $store.settings.keyboard.enabled)
                Picker("Applies to", selection: $store.settings.keyboard.scope) {
                    Text("External keyboards only").tag(KeyboardScope.externalOnly)
                    Text("All keyboards").tag(KeyboardScope.all)
                }
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
            }
            Section {
                RuleToggle("Ctrl as Cmd", "Ctrl+C, V, X, Z, A, S, F, T, W … plus Ctrl+Y for redo and Ctrl/Shift+Insert", $store.settings.keyboard.rules.ctrlToCmd)
                RuleToggle("Home and End", "Start/end of the line. With Ctrl: start/end of the document", $store.settings.keyboard.rules.homeEnd)
                RuleToggle("Word navigation", "Ctrl+←/→ moves by word, Ctrl+Backspace/Delete deletes a word", $store.settings.keyboard.rules.wordNavigation)
                RuleToggle("Alt+Tab", "Switches app, like ⌘⇥", $store.settings.keyboard.rules.altTab)
                RuleToggle("Alt+F4 and Ctrl+F4", "Quits the app and closes the window/tab", $store.settings.keyboard.rules.closeQuit)
                RuleToggle("F5 and Print Screen", "Reloads and opens the screenshot tool", $store.settings.keyboard.rules.functionKeys)
                RuleToggle("Win key", "Win+L locks the screen, Win+E opens Finder, Win+←/→ switches desktop", $store.settings.keyboard.rules.winKey)
                RuleToggle("Finder", "F2 renames, Delete moves to the Trash", $store.settings.keyboard.rules.finderKeys)
                RuleToggle("AltGr as on a PC", "AltGr+7 and 0 type { }, AltGr+plus types \\, AltGr+< types |, AltGr+5 and E type €. Assumes the Swedish layout", $store.settings.keyboard.rules.altGr)
            } header: {
                Text("Shortcuts")
            } footer: {
                Text("On a PC keyboard Ctrl = ⌃, Alt = ⌥ and Win = ⌘. Terminals and remote desktops have their own modes under Apps.")
            }
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

    var body: some View {
        Form {
            Section {
                ForEach($store.settings.appRules) { $rule in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(rule.name)
                            Text(rule.bundleID).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("Mouse wheel", isOn: Binding(get: { !rule.disableSmoothScroll }, set: { rule.disableSmoothScroll = !$0 }))
                        Picker("Keys", selection: $rule.keyMode) {
                            Text("Translate").tag(KeyMode.translate)
                            Text("Terminal mode").tag(KeyMode.terminal)
                            Text("Off").tag(KeyMode.off)
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button(role: .destructive) {
                            store.settings.appRules.removeAll { $0.bundleID == rule.bundleID }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .toggleStyle(.checkbox)
                }
                HStack {
                    Menu("Add running app") {
                        ForEach(runningApps(), id: \.bundleID) { app in
                            Button(app.name) { add(app) }
                        }
                    }
                    .fixedSize()
                    Button("Choose app…", action: chooseApp)
                }
            } header: {
                Text("Per-app rules")
            } footer: {
                Text("Applies while the app is frontmost. Terminal mode leaves Ctrl alone and makes Home/End go to the start/end of the line; Alt+Tab and the Win key work as usual.")
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
