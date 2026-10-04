import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// YouTube Data API v3 – Videosuche mit OAuth-Benutzer-Token (Scope `youtube.readonly`).
///
/// YouTube liefert Video- und Kanalinformationen, keine gesicherte Song-/Künstlerzuordnung.
nonisolated struct YouTubeDataAPI: Sendable {
    struct SearchResponse: Decodable, Sendable {
        let items: [Item]?
    }

    struct Item: Decodable, Sendable {
        struct ID: Decodable, Sendable {
            let videoId: String?
        }
        struct Snippet: Decodable, Sendable {
            let title: String?
            let channelTitle: String?
            let thumbnails: [String: Thumbnail]?
        }
        struct Thumbnail: Decodable, Sendable {
            let url: String
        }
        let id: ID?
        let snippet: Snippet?
    }

    let http: any HTTPDataLoading

    static func searchURL(query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.googleapis.com"
        components.path = "/youtube/v3/search"
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoCategoryId", value: "10"), // Kategorie „Musik“
            URLQueryItem(name: "maxResults", value: "20"),
            URLQueryItem(name: "q", value: query),
        ]
        return components.url
    }

    func search(_ query: String, accessToken: String) async throws -> [SongInfo] {
        guard let url = Self.searchURL(query: query) else { return [] }
        let response = try await http.decoded(SearchResponse.self, for: SpotifyWebAPI.authorized(url, token: accessToken))
        return Self.songs(from: response)
    }

    static func songs(from response: SearchResponse) -> [SongInfo] {
        (response.items ?? []).compactMap { item in
            guard let id = item.id?.videoId,
                  SongLinkParser.isValidYouTubeID(id),
                  let url = URL(string: "https://www.youtube.com/watch?v=\(id)") else {
                return nil
            }
            let thumbnails = item.snippet?.thumbnails ?? [:]
            let thumbnail = thumbnails["medium"] ?? thumbnails["high"] ?? thumbnails["default"]
            return SongInfo(
                id: "\(MusicProvider.youtube.rawValue):\(id)",
                provider: .youtube,
                url: url,
                title: item.snippet?.title.map(HTMLEntities.decode),
                artist: item.snippet?.channelTitle.map(HTMLEntities.decode),
                artworkURL: thumbnail.flatMap { URL(string: $0.url) }
            )
        }
    }
}

/// Die YouTube Data API liefert Titel HTML-maskiert (z. B. `&amp;`, `&#39;`).
nonisolated enum HTMLEntities {
    private static let named: [String: String] = [
        "&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">",
    ]

    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        for (entity, replacement) in named where entity != "&amp;" {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // `&amp;` zuletzt, damit doppelt maskierte Entitäten nicht doppelt dekodiert werden.
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }
}
