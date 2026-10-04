import Foundation

/// Songmodell mit optionalen Metadaten.
///
/// Titel, Künstler und Cover sind bewusst optional: Die App zeigt nur an,
/// was ein Anbieter tatsächlich geliefert hat, und erfindet nichts.
/// Bei YouTube enthält `artist` den Kanalnamen (siehe `MusicProvider.creatorLabel`).
nonisolated struct SongInfo: Identifiable, Hashable, Codable, Sendable {
    /// Stabile ID im Format `<anbieter>:<anbieter-id>`, z. B. `spotify:4uLU6hMCjMI75M1A2tKUQC`.
    let id: String
    let provider: MusicProvider
    let url: URL
    let title: String?
    let artist: String?
    let artworkURL: URL?

    init(id: String, provider: MusicProvider, url: URL, title: String?, artist: String?, artworkURL: URL?) {
        self.id = id
        self.provider = provider
        self.url = url
        self.title = Self.normalized(title)
        self.artist = Self.normalized(artist)
        self.artworkURL = artworkURL.flatMap { AllowedHosts.isAllowedArtworkURL($0) ? $0 : nil }
    }

    /// `true`, wenn mindestens ein Metadatenfeld vorhanden ist.
    var hasMetadata: Bool {
        title != nil || artist != nil || artworkURL != nil
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
