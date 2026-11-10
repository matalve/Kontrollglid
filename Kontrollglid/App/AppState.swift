import AppKit
import ApplicationServices
import Combine
import ServiceManagement

/// Owns the engines and tracks permissions and the frontmost app.
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var accessibilityGranted = false
    @Published private(set) var inputMonitoringGranted = false
    @Published private(set) var externalKeyboards: [String] = []
    @Published private(set) var enginesRunning = false
    /// The last key pressed while the settings window was frontmost.
    @Published var lastKeyReport: String?

    /// Read from event tap callbacks, so plain properties rather than @Published.
    private(set) var frontBundleID: String?
    var isFrontmost: Bool { frontBundleID == Bundle.main.bundleIdentifier }

    private let scroll = ScrollEngine()
    private let buttons = ButtonEngine()
    private let keyboard = KeyboardEngine()
    private var timer: Timer?
    private var paused = false
    private var pauseObserver: AnyCancellable?

    private init() {}

    func start() {
        frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.frontBundleID = app?.bundleIdentifier
        }

        pauseObserver = SettingsStore.shared.$settings.map(\.paused).removeDuplicates().sink { [weak self] paused in
            self?.paused = paused
            self?.refresh()
        }

        refresh()
        // Permissions are granted in System Settings while we run, so keep checking.
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != accessibilityGranted { accessibilityGranted = trusted }
        let shouldRun = trusted && !paused
        if shouldRun, !enginesRunning {
            let started = [scroll.start(), buttons.start(), keyboard.start()]
            enginesRunning = started.allSatisfy { $0 }
        } else if !shouldRun, enginesRunning {
            scroll.stop()
            buttons.stop()
            keyboard.stop()
            enginesRunning = false
        }

        let monitor = KeyboardDeviceMonitor.shared
        let listening = monitor.hasAccess
        if listening != inputMonitoringGranted { inputMonitoringGranted = listening }
        if listening { monitor.startIfNeeded() }
        let names = monitor.externalKeyboardNames
        if names != externalKeyboards { externalKeyboards = names }
    }

    // MARK: - Permissions

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            openPrivacyPane("Privacy_Accessibility")
        }
    }

    func requestInputMonitoring() {
        KeyboardDeviceMonitor.shared.requestAccess()
        openPrivacyPane("Privacy_ListenEvent")
    }

    private func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Kontrollglid: could not change login item: \(error.localizedDescription)")
            }
        }
    }
}
