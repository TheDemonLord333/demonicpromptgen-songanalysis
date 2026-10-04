import Foundation
import Observation

/// ViewModel des Songauswahl-Sheets: Anbieterauswahl, entprellte Suche, Ergebnisliste.
@MainActor
@Observable
final class SongPickerViewModel {
    var selectedProvider: MusicProvider {
        didSet {
            guard selectedProvider != oldValue else { return }
            scheduleSearch(debounce: false)
        }
    }

    var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch(debounce: true)
        }
    }

    private(set) var state: SearchState = .idle

    @ObservationIgnored private let integrations: [MusicProvider: any ProviderIntegration]
    @ObservationIgnored private let debounceInterval: Duration
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var searchGeneration = 0

    static let minimumQueryLength = 2

    init(
        integrations: [any ProviderIntegration],
        initialProvider: MusicProvider = .spotify,
        debounceInterval: Duration = .milliseconds(450)
    ) {
        var map: [MusicProvider: any ProviderIntegration] = [:]
        for integration in integrations {
            map[integration.provider] = integration
        }
        self.integrations = map
        self.selectedProvider = initialProvider
        self.debounceInterval = debounceInterval
    }

    var currentIntegration: (any ProviderIntegration)? {
        integrations[selectedProvider]
    }

    var availability: SearchAvailability {
        currentIntegration?.searchAvailability
            ?? .unavailable(reason: "Dieser Anbieter ist nicht verfügbar.")
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func refreshStatuses() async {
        for integration in integrations.values {
            await integration.refreshStatus()
        }
    }

    func retry() {
        scheduleSearch(debounce: false)
    }

    func cancel() {
        searchTask?.cancel()
        searchTask = nil
        searchGeneration += 1
    }

    private func scheduleSearch(debounce: Bool) {
        cancel()
        let generation = searchGeneration
        let term = trimmedQuery

        guard term.count >= Self.minimumQueryLength,
              let integration = currentIntegration,
              case .available = integration.searchAvailability else {
            state = .idle
            return
        }

        state = .searching
        let delay = debounceInterval
        searchTask = Task { [weak self] in
            if debounce, delay > .zero {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }
            let newState: SearchState
            do {
                let songs = try await integration.search(term)
                newState = songs.isEmpty ? .noResults : .results(songs)
            } catch is CancellationError {
                return
            } catch let error as OAuthError {
                newState = .failed(error.message)
            } catch {
                newState = .failed(NetworkError.userMessage(for: error))
            }
            guard let self, generation == self.searchGeneration else { return }
            self.state = newState
        }
    }
}
