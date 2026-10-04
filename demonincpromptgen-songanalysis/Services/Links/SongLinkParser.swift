import Foundation

/// Prüft und normalisiert Song-Links von Spotify, YouTube und Apple Music.
///
/// - Validierung über `URLComponents`.
/// - Anbietererkennung ausschließlich über exakte Hostnamen (keine Teilstring-Vergleiche).
/// - Normalisierung baut die URL aus den erkannten IDs neu auf. Dadurch entfallen
///   Trackingparameter (`si`, `utm_*`, `feature`, …), ohne den Link ungültig zu machen.
nonisolated enum SongLinkParser {
    // MARK: Exakte Hostlisten

    static let spotifyHosts: Set<String> = ["open.spotify.com", "play.spotify.com"]
    static let spotifyShortLinkHosts: Set<String> = ["spotify.link", "spoti.fi"]
    static let youtubeHosts: Set<String> = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com",
        "youtube-nocookie.com", "www.youtube-nocookie.com",
    ]
    static let youtubeShortHosts: Set<String> = ["youtu.be"]
    static let appleMusicHosts: Set<String> = ["music.apple.com", "geo.music.apple.com", "itunes.apple.com"]
    static let appleShortLinkHosts: Set<String> = ["apple.co"]

    // MARK: Parsing

    static func parse(_ input: String) -> Result<SongLink, SongLinkError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }

        guard let candidate = extractCandidate(from: trimmed) else {
            return .failure(.notALink)
        }

        if candidate.lowercased().hasPrefix("spotify:") {
            return parseSpotifyURI(candidate)
        }

        let withScheme = candidate.contains("://") ? candidate : "https://" + candidate
        guard let components = URLComponents(string: withScheme),
              let rawScheme = components.scheme?.lowercased() else {
            return .failure(.notALink)
        }
        guard rawScheme == "https" || rawScheme == "http" else {
            return .failure(.unsupportedScheme)
        }
        if components.user != nil || components.password != nil {
            return .failure(.credentialsInURL)
        }
        guard var host = components.host?.lowercased(), !host.isEmpty else {
            return .failure(.notALink)
        }
        if host.hasSuffix(".") { host.removeLast() }
        if let port = components.port, port != 443, port != 80 {
            return .failure(.unsupportedHost)
        }

        let pathParts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        if spotifyHosts.contains(host) {
            return parseSpotify(pathParts: pathParts)
        }
        if spotifyShortLinkHosts.contains(host) {
            return shortLink(provider: .spotify, host: host, components: components)
        }
        if youtubeHosts.contains(host) {
            return parseYouTube(host: host, pathParts: pathParts, components: components)
        }
        if youtubeShortHosts.contains(host) {
            guard let id = pathParts.first, isValidYouTubeID(id) else {
                return .failure(.unsupportedContent(.youtube))
            }
            return youtubeLink(id: id, musicHost: false)
        }
        if appleMusicHosts.contains(host) {
            return parseAppleMusic(host: host, pathParts: pathParts, components: components)
        }
        if appleShortLinkHosts.contains(host) {
            return shortLink(provider: .appleMusic, host: host, components: components)
        }
        return .failure(.unsupportedHost)
    }

    /// Erlaubt Share-Texte wie „Hör dir das an: https://…“, indem das erste Link-Token gewählt wird.
    private static func extractCandidate(from text: String) -> String? {
        let tokens = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard tokens.count > 1 else { return tokens.first }
        return tokens.first { token in
            let lower = token.lowercased()
            return lower.hasPrefix("https://") || lower.hasPrefix("http://") || lower.hasPrefix("spotify:")
        }
    }

    // MARK: Spotify

    private static func parseSpotifyURI(_ uri: String) -> Result<SongLink, SongLinkError> {
        let parts = uri.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, parts[1].lowercased() == "track", isValidSpotifyID(parts[2]) else {
            return .failure(.unsupportedContent(.spotify))
        }
        return spotifyLink(id: parts[2])
    }

    private static func parseSpotify(pathParts: [String]) -> Result<SongLink, SongLinkError> {
        var parts = pathParts
        if let first = parts.first, first.lowercased().hasPrefix("intl-") { parts.removeFirst() }
        if parts.first?.lowercased() == "embed" { parts.removeFirst() }
        guard parts.count >= 2, parts[0].lowercased() == "track", isValidSpotifyID(parts[1]) else {
            return .failure(.unsupportedContent(.spotify))
        }
        return spotifyLink(id: parts[1])
    }

    private static func spotifyLink(id: String) -> Result<SongLink, SongLinkError> {
        guard let url = URL(string: "https://open.spotify.com/track/\(id)") else {
            return .failure(.notALink)
        }
        return .success(SongLink(provider: .spotify, url: url, reference: .spotifyTrack(id: id)))
    }

    static func isValidSpotifyID(_ id: String) -> Bool {
        id.count == 22 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    // MARK: YouTube

    private static func parseYouTube(host: String, pathParts: [String], components: URLComponents) -> Result<SongLink, SongLinkError> {
        let musicHost = host == "music.youtube.com"
        let id: String?
        switch pathParts.first?.lowercased() {
        case "watch":
            id = components.queryItems?.first(where: { $0.name == "v" })?.value
        case "shorts", "embed", "live", "v":
            id = pathParts.count >= 2 ? pathParts[1] : nil
        default:
            id = nil
        }
        guard let id, isValidYouTubeID(id) else {
            return .failure(.unsupportedContent(.youtube))
        }
        return youtubeLink(id: id, musicHost: musicHost)
    }

    private static func youtubeLink(id: String, musicHost: Bool) -> Result<SongLink, SongLinkError> {
        let base = musicHost ? "https://music.youtube.com" : "https://www.youtube.com"
        guard let url = URL(string: "\(base)/watch?v=\(id)") else {
            return .failure(.notALink)
        }
        return .success(SongLink(provider: .youtube, url: url, reference: .youtubeVideo(id: id)))
    }

    static func isValidYouTubeID(_ id: String) -> Bool {
        id.count == 11 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    // MARK: Apple Music

    private static func parseAppleMusic(host: String, pathParts: [String], components: URLComponents) -> Result<SongLink, SongLinkError> {
        var parts = pathParts
        var storefront: String?
        if let first = parts.first, first.count == 2, first.allSatisfy({ $0.isASCII && $0.isLetter }) {
            storefront = first.lowercased()
            parts.removeFirst()
        }
        guard let kind = parts.first?.lowercased() else {
            return .failure(.unsupportedContent(.appleMusic))
        }

        let songID: String?
        var keepSongQuery = false
        switch kind {
        case "song":
            songID = parts.count >= 2 ? appleNumericID(parts[parts.count - 1]) : nil
        case "album":
            songID = components.queryItems?
                .first(where: { $0.name == "i" })?
                .value
                .flatMap(appleNumericID)
            keepSongQuery = true
        default:
            songID = nil
        }
        guard let songID else {
            return .failure(.unsupportedContent(.appleMusic))
        }

        var normalized = URLComponents()
        normalized.scheme = "https"
        normalized.host = host
        normalized.percentEncodedPath = components.percentEncodedPath
        if keepSongQuery {
            // Nur der Song-Parameter `i` bleibt erhalten; Trackingparameter entfallen.
            normalized.queryItems = [URLQueryItem(name: "i", value: songID)]
        }
        guard let url = normalized.url else {
            return .failure(.notALink)
        }
        return .success(SongLink(
            provider: .appleMusic,
            url: url,
            reference: .appleMusicSong(id: songID, storefront: storefront)
        ))
    }

    private static func appleNumericID(_ value: String) -> String? {
        let digits = value.lowercased().hasPrefix("id") ? String(value.dropFirst(2)) : value
        guard !digits.isEmpty, digits.count <= 20, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return nil
        }
        return digits
    }

    // MARK: Kurzlinks

    private static func shortLink(provider: MusicProvider, host: String, components: URLComponents) -> Result<SongLink, SongLinkError> {
        let path = components.percentEncodedPath
        guard path.count > 1 else {
            return .failure(.unsupportedContent(provider))
        }
        var normalized = URLComponents()
        normalized.scheme = "https"
        normalized.host = host
        normalized.percentEncodedPath = path
        guard let url = normalized.url else {
            return .failure(.notALink)
        }
        return .success(SongLink(provider: provider, url: url, reference: .shortLink))
    }
}
