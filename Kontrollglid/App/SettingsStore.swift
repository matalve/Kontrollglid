import Combine
import Foundation

/// Holds the user's settings and saves them to UserDefaults on every change.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private static let key = "settings.v1"

    @Published var settings: AppSettings {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = AppSettings.decode(data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    func resetToDefaults() {
        settings = AppSettings()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
