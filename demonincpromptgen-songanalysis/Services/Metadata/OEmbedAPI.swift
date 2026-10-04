import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Öffentliche oEmbed-Endpunkte von Spotify und YouTube (ohne Anmeldung, ohne Schlüssel).
nonisolated struct OEmbedAPI: Sendable {
    struct Response: Decodable, Sendable {
        let title: String?
        let authorName: String?
        let thumbnailURL: String?

        enum CodingKeys: String, CodingKey {
            case title
            case authorName = "author_name"
            case thumbnailURL = "thumbnail_url"
        }
    }

    let http: any HTTPDataLoading

    static func requestURL(for link: SongLink) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        switch link.provider {
        case .spotify:
            components.host = "open.spotify.com"
            components.path = "/oembed"
            components.queryItems = [URLQueryItem(name: "url", value: link.url.absoluteString)]
        case .youtube:
            components.host = "www.youtube.com"
            components.path = "/oembed"
            // oEmbed von YouTube akzeptiert nur www.youtube.com-Links zuverlässig.
            let videoURL: String
            if case .youtubeVideo(let id) = link.reference {
                videoURL = "https://www.youtube.com/watch?v=\(id)"
            } else {
                videoURL = link.url.absoluteString
            }
            components.queryItems = [
                URLQueryItem(name: "url", value: videoURL),
                URLQueryItem(name: "format", value: "json"),
            ]
        case .appleMusic:
            return nil
        }
        return components.url
    }

    func metadata(for link: SongLink) async throws -> SongInfo {
        guard let songID = link.songID, let url = Self.requestURL(for: link) else {
            throw NetworkError.invalidResponse
        }
        let response = try await http.decoded(Response.self, for: URLRequest(url: url))
        return Self.songInfo(from: response, link: link, songID: songID)
    }

    static func songInfo(from response: Response, link: SongLink, songID: String) -> SongInfo {
        // Bei Spotify ist `author_name` nicht zuverlässig als Künstler dokumentiert und wird daher
        // nicht als Künstler übernommen. Bei YouTube ist es der Kanalname (als „Kanal“ beschriftet).
        let creator = link.provider == .youtube ? response.authorName : nil
        return SongInfo(
            id: songID,
            provider: link.provider,
            url: link.url,
            title: response.title,
            artist: creator,
            artworkURL: response.thumbnailURL.flatMap(URL.init(string:))
        )
    }
}
