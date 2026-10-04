import Foundation

/// Liefert verfügbare Metadaten zu einem geprüften Song-Link.
nonisolated protocol SongMetadataFetching: Sendable {
    /// Löst Kurzlinks auf und lädt Titel, Künstler bzw. Kanal und Cover.
    /// - Returns: Songinformationen; einzelne Felder können fehlen.
    func metadata(for link: SongLink) async throws -> SongInfo
}

nonisolated enum MetadataError: Error, Equatable, Sendable {
    case noMetadata

    var message: String {
        "Der Anbieter hat keine Metadaten zu diesem Link geliefert."
    }
}

/// Standardimplementierung über offizielle, öffentliche Endpunkte:
/// - Spotify: Web API, falls verbunden; sonst öffentliches oEmbed.
/// - YouTube: öffentliches oEmbed (Videotitel und Kanal).
/// - Apple Music: öffentliche iTunes Lookup API.
nonisolated struct SongMetadataService: SongMetadataFetching {
    let http: any HTTPDataLoading
    let resolver: ShortLinkResolver
    /// Liefert ein gültiges Spotify-Benutzertoken, sofern verbunden.
    let spotifyAccessToken: @Sendable () async -> String?

    func metadata(for link: SongLink) async throws -> SongInfo {
        let resolved = try await resolver.resolve(link)
        try Task.checkCancellation()

        switch resolved.reference {
        case .spotifyTrack(let id):
            if let token = await spotifyAccessToken(),
               let song = try? await SpotifyWebAPI(http: http).track(id: id, accessToken: token),
               song.hasMetadata {
                return song
            }
            try Task.checkCancellation()
            return try await OEmbedAPI(http: http).metadata(for: resolved)
        case .youtubeVideo:
            return try await OEmbedAPI(http: http).metadata(for: resolved)
        case .appleMusicSong:
            guard let song = try await ITunesAPI(http: http).lookup(link: resolved) else {
                throw MetadataError.noMetadata
            }
            return song
        case .shortLink:
            throw ShortLinkError.notResolvable
        }
    }
}
