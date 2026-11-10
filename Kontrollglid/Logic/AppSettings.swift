import Foundation

enum ScrollDirection: String, Codable, CaseIterable, Identifiable {
    /// Follow the macOS "Natural scrolling" setting.
    case system
    /// Content follows the fingers (macOS default).
    case natural
    /// Wheel down moves the page down (Windows default).
    case traditional

    var id: String { rawValue }

    /// Whether events must be inverted to get this direction.
    func needsReversal(systemIsNatural: Bool) -> Bool {
        switch self {
        case .system: return false
        case .natural: return !systemIsNatural
        case .traditional: return systemIsNatural
        }
    }
}

enum ModifierChoice: String, Codable, CaseIterable, Identifiable {
    case none, control, option, command, shift

    var id: String { rawValue }

    var modifiers: Modifiers {
        switch self {
        case .none: return []
        case .control: return .control
        case .option: return .option
        case .command: return .command
        case .shift: return .shift
        }
    }

    func isHeld(in held: Modifiers) -> Bool {
        self != .none && held.contains(modifiers)
    }
}

/// What happens to events from an ordinary (notched) mouse wheel.
enum WheelMode: String, Codable, CaseIterable, Identifiable {
    /// Animated, pixel-smooth scrolling.
    case smooth
    /// No animation and no acceleration: every notch scrolls the same distance.
    case linear
    /// Leave macOS behaviour alone (accelerated).
    case system

    var id: String { rawValue }
}

struct ScrollSettings: Codable, Equatable {
    var wheelMode = WheelMode.smooth
    /// Lines per notch in `.linear` mode.
    var linesPerTick = 3.0
    /// Minimum distance in pixels for one wheel tick.
    var step = 33.0
    /// Gain applied to every tick.
    var speed = 2.7
    /// Smoothing length, 1 (snappy) … 10 (floaty).
    var duration = 4.3
    var mouseDirection = ScrollDirection.traditional
    var trackpadDirection = ScrollDirection.system
    /// Hold to scroll sideways with a vertical wheel.
    var horizontalModifier = ModifierChoice.shift
    /// Hold to scroll faster.
    var dashModifier = ModifierChoice.option
    var dashMultiplier = 3.0
    /// Hold to temporarily turn smoothing off (keeps Cmd+scroll zoom precise).
    var bypassModifier = ModifierChoice.command

    var timeConstant: Double { duration * 0.03 }
}

struct ButtonBinding: Codable, Equatable, Identifiable {
    var id = UUID()
    /// CoreGraphics button number: 2 = middle, 3 = back, 4 = forward, …
    var button: Int
    var stroke: KeyStroke
}

enum KeyboardScope: String, Codable, CaseIterable, Identifiable {
    case externalOnly, all
    var id: String { rawValue }
}

struct KeyboardSettings: Codable, Equatable {
    var enabled = true
    var scope = KeyboardScope.externalOnly
    var rules = KeyRuleSet()
}

/// How key translation behaves while a given app is frontmost.
enum KeyMode: String, Codable, CaseIterable, Identifiable {
    /// All rules apply.
    case translate
    /// Ctrl is left alone (it already works the Windows way in a shell) and
    /// Home/End become Ctrl+A/Ctrl+E. App switching and Win keys still work.
    case terminal
    /// Nothing is translated, e.g. in a remote desktop that expects PC keys.
    case off

    var id: String { rawValue }
}

struct AppRule: Codable, Equatable, Identifiable {
    var bundleID: String
    var name: String
    var disableSmoothScroll = false
    var keyMode = KeyMode.off

    var id: String { bundleID }

    static let knownTerminals: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable", "net.kovidgoyal.kitty", "org.alacritty",
    ]

    init(bundleID: String, name: String, disableSmoothScroll: Bool = false, keyMode: KeyMode = .off) {
        self.bundleID = bundleID
        self.name = name
        self.disableSmoothScroll = disableSmoothScroll
        self.keyMode = keyMode
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID, name, disableSmoothScroll, keyMode, disableKeyRemap
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        name = try c.decode(String.self, forKey: .name)
        disableSmoothScroll = try c.decodeIfPresent(Bool.self, forKey: .disableSmoothScroll) ?? false
        if let mode = try c.decodeIfPresent(KeyMode.self, forKey: .keyMode) {
            keyMode = mode
        } else if Self.knownTerminals.contains(bundleID) {
            // Saved before terminal mode existed, when a terminal could only be
            // fully on (Ctrl+C broken) or fully off (no Alt+Tab).
            keyMode = .terminal
        } else if try c.decodeIfPresent(Bool.self, forKey: .disableKeyRemap) ?? false {
            keyMode = .off
        } else {
            keyMode = .translate
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bundleID, forKey: .bundleID)
        try c.encode(name, forKey: .name)
        try c.encode(disableSmoothScroll, forKey: .disableSmoothScroll)
        try c.encode(keyMode, forKey: .keyMode)
    }
}

struct AppSettings: Codable, Equatable {
    var scroll = ScrollSettings()
    var buttonsEnabled = true
    var buttons: [ButtonBinding] = [
        ButtonBinding(button: 3, stroke: KeyStroke(KeyCode.leftBracket, .command)),
        ButtonBinding(button: 4, stroke: KeyStroke(KeyCode.rightBracket, .command)),
    ]
    var keyboard = KeyboardSettings()
    /// Terminals need the real Ctrl+C, and remote desktops/VMs already speak
    /// Windows, so they get terminal mode and no translation respectively.
    var appRules: [AppRule] = [
        AppRule(bundleID: "com.apple.Terminal", name: "Terminal", keyMode: .terminal),
        AppRule(bundleID: "com.googlecode.iterm2", name: "iTerm", keyMode: .terminal),
        AppRule(bundleID: "com.mitchellh.ghostty", name: "Ghostty", keyMode: .terminal),
        AppRule(bundleID: "dev.warp.Warp-Stable", name: "Warp", keyMode: .terminal),
        AppRule(bundleID: "net.kovidgoyal.kitty", name: "kitty", keyMode: .terminal),
        AppRule(bundleID: "org.alacritty", name: "Alacritty", keyMode: .terminal),
        AppRule(bundleID: "com.microsoft.rdc.macos", name: "Windows App", keyMode: .off),
        AppRule(bundleID: "com.parallels.desktop.console", name: "Parallels Desktop", keyMode: .off),
        AppRule(bundleID: "com.vmware.fusion", name: "VMware Fusion", keyMode: .off),
        AppRule(bundleID: "com.utmapp.UTM", name: "UTM", keyMode: .off),
    ]

    /// Decode saved settings, filling in anything missing from the defaults so
    /// that adding a new setting never throws away the user's existing ones.
    static func decode(_ data: Data) -> AppSettings? {
        guard let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let defaultsData = try? JSONEncoder().encode(AppSettings()),
              let defaults = try? JSONSerialization.jsonObject(with: defaultsData) as? [String: Any],
              let merged = try? JSONSerialization.data(withJSONObject: merge(saved, onto: defaults)) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: merged)
    }

    private static func merge(_ saved: [String: Any], onto defaults: [String: Any]) -> [String: Any] {
        var result = defaults
        for (key, value) in saved {
            if let nested = value as? [String: Any], let base = defaults[key] as? [String: Any] {
                result[key] = merge(nested, onto: base)
            } else {
                result[key] = value
            }
        }
        return result
    }

    func rule(for bundleID: String?) -> AppRule? {
        guard let bundleID else { return nil }
        return appRules.first { $0.bundleID == bundleID }
    }
}
