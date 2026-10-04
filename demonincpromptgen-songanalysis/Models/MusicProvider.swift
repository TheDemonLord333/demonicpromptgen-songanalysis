import Foundation

/// Unterstützte Musikanbieter für Song-Links, Metadaten und Songsuche.
nonisolated enum MusicProvider: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case spotify
    case youtube
    case appleMusic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spotify: "Spotify"
        case .youtube: "YouTube"
        case .appleMusic: "Apple Music"
        }
    }

    /// Bezeichnung des Titelfelds. YouTube liefert Videotitel, keine gesicherten Songtitel.
    var titleLabel: String {
        self == .youtube ? "Video" : "Titel"
    }

    /// Bezeichnung des Urheberfelds. YouTube liefert Kanalnamen, keine gesicherte Künstlerzuordnung.
    var creatorLabel: String {
        self == .youtube ? "Kanal" : "Künstler"
    }
}
