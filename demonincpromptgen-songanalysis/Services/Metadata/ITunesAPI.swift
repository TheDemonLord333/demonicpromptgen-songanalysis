import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Öffentliche iTunes Search/Lookup API von Apple (ohne Anmeldung, ohne Schlüssel).
/// Liefert Katalogdaten zu Apple-Music-Songs.
nonisolated struct ITunesAPI: Sendable {
    struct Response: Decodable, Sendable {
        let results: [Item]
    }

    struct Item: Decodable, Sendable {
        let wrapperType: String?
        let kind: String?
        let trackId: Int?
        let trackName: String?
        let artistName: String?
        let artworkUrl100: String?
        let trackViewUrl: String?
    }

    let http: any HTTPDataLoading

    static func lookupURL(songID: String, storefront: String?) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/lookup"
        var items = [URLQueryItem(name: "id", value: songID), URLQueryItem(name: "entity", value: "song")]
        if let storefront = validCountry(storefront) {
            items.append(URLQueryItem(name: "country", value: storefront))
        }
        components.queryItems = items
        return components.url
    }

    static func searchURL(term: String, country: String?) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/search"
        var items = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "25"),
        ]
        if let country = validCountry(country) {
            items.append(URLQueryItem(name: "country", value: country))
        }
        components.queryItems = items
        return components.url
    }

    static func validCountry(_ value: String?) -> String? {
        guard let value, value.count == 2, value.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        return value.lowercased()
    }

    func lookup(link: SongLink) async throws -> SongInfo? {
        guard case .appleMusicSong(let id, let storefront) = link.reference,
              let url = Self.lookupURL(songID: id, storefront: storefront) else {
            return nil
        }
        let response = try await http.decoded(Response.self, for: URLRequest(url: url))
        guard let item = response.results.first(where: { $0.trackId.map(String.init) == id }) else {
            return nil
        }
        return SongInfo(
            id: link.songID ?? "\(MusicProvider.appleMusic.rawValue):\(id)",
            provider: .appleMusic,
            url: link.url,
            title: item.trackName,
            artist: item.artistName,
            artworkURL: item.artworkUrl100.flatMap(URL.init(string:))
        )
    }

    func search(term: String, country: String?) async throws -> [SongInfo] {
        guard let url = Self.searchURL(term: term, country: country) else { return [] }
        let response = try await http.decoded(Response.self, for: URLRequest(url: url))
        return Self.songs(from: response)
    }

    static func songs(from response: Response) -> [SongInfo] {
        response.results.compactMap { item in
            guard item.kind == "song",
                  let viewURL = item.trackViewUrl,
                  case .success(let link) = SongLinkParser.parse(viewURL),
                  link.provider == .appleMusic,
                  let songID = link.songID else {
                return nil
            }
            return SongInfo(
                id: songID,
                provider: .appleMusic,
                url: link.url,
                title: item.trackName,
                artist: item.artistName,
                artworkURL: item.artworkUrl100.flatMap(URL.init(string:))
            )
        }
    }
}
