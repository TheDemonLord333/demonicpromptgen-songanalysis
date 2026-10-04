import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Spotify Web API (benötigt ein Benutzer-Token aus dem PKCE-Flow).
///
/// Hinweis: Seit Februar 2026 ist `limit` bei der Suche für Apps im Development Mode auf 10 begrenzt.
nonisolated struct SpotifyWebAPI: Sendable {
    static let searchLimit = 10

    struct Image: Decodable, Sendable {
        let url: String
        let width: Int?
    }

    struct Artist: Decodable, Sendable {
        let name: String?
    }

    struct Album: Decodable, Sendable {
        let images: [Image]?
    }

    struct Track: Decodable, Sendable {
        let id: String?
        let name: String?
        let artists: [Artist]?
        let album: Album?
    }

    struct SearchResponse: Decodable, Sendable {
        struct Page: Decodable, Sendable {
            let items: [Track?]
        }
        let tracks: Page?
    }

    let http: any HTTPDataLoading

    static func searchURL(query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.spotify.com"
        components.path = "/v1/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: String(searchLimit)),
        ]
        return components.url
    }

    func track(id: String, accessToken: String) async throws -> SongInfo? {
        guard SongLinkParser.isValidSpotifyID(id),
              let url = URL(string: "https://api.spotify.com/v1/tracks/\(id)") else {
            return nil
        }
        let track = try await http.decoded(Track.self, for: Self.authorized(url, token: accessToken))
        return Self.songInfo(from: track)
    }

    func search(_ query: String, accessToken: String) async throws -> [SongInfo] {
        guard let url = Self.searchURL(query: query) else { return [] }
        let response = try await http.decoded(SearchResponse.self, for: Self.authorized(url, token: accessToken))
        return (response.tracks?.items ?? []).compactMap { $0.flatMap(Self.songInfo(from:)) }
    }

    static func songInfo(from track: Track) -> SongInfo? {
        guard let id = track.id,
              SongLinkParser.isValidSpotifyID(id),
              let url = URL(string: "https://open.spotify.com/track/\(id)") else {
            return nil
        }
        let artists = (track.artists ?? []).compactMap(\.name).filter { !$0.isEmpty }
        // Mittlere Bildgröße bevorzugen (ca. 300 px), sonst das erste verfügbare Bild.
        let images = track.album?.images ?? []
        let image = images.first(where: { ($0.width ?? 0) >= 200 && ($0.width ?? 0) <= 400 }) ?? images.first
        return SongInfo(
            id: "\(MusicProvider.spotify.rawValue):\(id)",
            provider: .spotify,
            url: url,
            title: track.name,
            artist: artists.isEmpty ? nil : artists.joined(separator: ", "),
            artworkURL: image.flatMap { URL(string: $0.url) }
        )
    }

    static func authorized(_ url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
