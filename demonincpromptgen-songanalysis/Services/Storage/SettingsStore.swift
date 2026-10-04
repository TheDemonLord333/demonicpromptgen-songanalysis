import Foundation
import Observation

/// Lokale Speicherung der Einstellungen in `UserDefaults` (nur auf diesem Gerät).
@MainActor
@Observable
final class AppSettings {
    private enum Keys {
        static let promptConfiguration = "settings.promptConfiguration.v1"
        static let rememberLastSongURL = "settings.rememberLastSongURL"
        static let lastSongURL = "settings.lastSongURL"
    }

    var promptConfiguration: PromptConfiguration {
        didSet {
            guard promptConfiguration != oldValue else { return }
            save(promptConfiguration)
        }
    }

    var rememberLastSongURL: Bool {
        didSet {
            defaults.set(rememberLastSongURL, forKey: Keys.rememberLastSongURL)
            if !rememberLastSongURL {
                lastSongURL = nil
            }
        }
    }

    /// Wird nur gespeichert, wenn `rememberLastSongURL` aktiv ist.
    private(set) var lastSongURL: String? {
        didSet {
            if let lastSongURL {
                defaults.set(lastSongURL, forKey: Keys.lastSongURL)
            } else {
                defaults.removeObject(forKey: Keys.lastSongURL)
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.promptConfiguration),
           let stored = try? JSONDecoder().decode(PromptConfiguration.self, from: data) {
            promptConfiguration = stored
        } else {
            promptConfiguration = .default
        }
        let remember = defaults.bool(forKey: Keys.rememberLastSongURL)
        rememberLastSongURL = remember
        lastSongURL = remember ? defaults.string(forKey: Keys.lastSongURL) : nil
    }

    func recordSongURL(_ url: String?) {
        guard rememberLastSongURL else { return }
        lastSongURL = url
    }

    private func save(_ configuration: PromptConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: Keys.promptConfiguration)
    }
}
