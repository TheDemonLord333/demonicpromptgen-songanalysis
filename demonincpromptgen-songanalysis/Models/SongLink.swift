import Foundation

/// Ein geprüfter, normalisierter Song-Link.
nonisolated struct SongLink: Hashable, Sendable {
    enum Reference: Hashable, Sendable {
        case spotifyTrack(id: String)
        case youtubeVideo(id: String)
        case appleMusicSong(id: String, storefront: String?)
        /// Kurzlink (z. B. `spotify.link`, `apple.co`), der erst über
        /// eine begrenzte Weiterleitungsauflösung zum eigentlichen Song führt.
        case shortLink
    }

    let provider: MusicProvider
    /// Normalisierte URL ohne bekannte Trackingparameter.
    let url: URL
    let reference: Reference

    var needsResolution: Bool {
        if case .shortLink = reference { return true }
        return false
    }

    /// ID im selben Format wie `SongInfo.id`, sofern der Link eindeutig auf einen Song zeigt.
    var songID: String? {
        switch reference {
        case .spotifyTrack(let id): "\(MusicProvider.spotify.rawValue):\(id)"
        case .youtubeVideo(let id): "\(MusicProvider.youtube.rawValue):\(id)"
        case .appleMusicSong(let id, _): "\(MusicProvider.appleMusic.rawValue):\(id)"
        case .shortLink: nil
        }
    }
}

/// Verständliche Fehler bei der Link-Prüfung.
nonisolated enum SongLinkError: Error, Equatable, Sendable {
    case empty
    case notALink
    case unsupportedScheme
    case credentialsInURL
    case unsupportedHost
    case unsupportedContent(MusicProvider)

    var message: String {
        switch self {
        case .empty:
            "Bitte einen Song-Link einfügen."
        case .notALink:
            "Das sieht nicht wie ein gültiger Link aus."
        case .unsupportedScheme:
            "Nur https-Links werden unterstützt."
        case .credentialsInURL:
            "Links mit eingebetteten Anmeldedaten werden aus Sicherheitsgründen abgelehnt."
        case .unsupportedHost:
            "Nicht unterstützter Anbieter. Erlaubt sind Links von Spotify, YouTube und Apple Music."
        case .unsupportedContent(let provider):
            "Dieser \(provider.displayName)-Link verweist nicht auf einen einzelnen Song."
        }
    }
}
