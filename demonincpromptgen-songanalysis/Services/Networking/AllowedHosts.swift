import Foundation

/// Zentrale Positivliste aller Hosts, die die App anfragen darf.
///
/// Es gibt bewusst keine Anfragen an beliebige, vom Benutzer eingegebene Hosts.
nonisolated enum AllowedHosts {
    /// API-Endpunkte für Metadaten, Suche und Token-Austausch (exakter Hostvergleich).
    static let apiHosts: Set<String> = [
        "open.spotify.com",       // Spotify oEmbed
        "api.spotify.com",        // Spotify Web API
        "accounts.spotify.com",   // Spotify OAuth-Token
        "www.youtube.com",        // YouTube oEmbed
        "www.googleapis.com",     // YouTube Data API v3
        "oauth2.googleapis.com",  // Google OAuth-Token / Widerruf
        "itunes.apple.com",       // Apple iTunes Search/Lookup API
    ]

    /// Domains für Cover-Bilder. Erlaubt sind die Domain selbst und Subdomains.
    static let artworkDomains: [String] = [
        "scdn.co",
        "spotifycdn.com",
        "ytimg.com",
        "ggpht.com",
        "googleusercontent.com",
        "mzstatic.com",
    ]

    static func normalizedHost(of url: URL) -> String? {
        guard let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host?.lowercased(),
              !host.isEmpty else {
            return nil
        }
        return host.hasSuffix(".") ? String(host.dropLast()) : host
    }

    static func isAllowedAPIRequest(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = normalizedHost(of: url) else {
            return false
        }
        return apiHosts.contains(host)
    }

    static func isAllowedArtworkURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = normalizedHost(of: url) else {
            return false
        }
        return artworkDomains.contains { domain in
            host == domain || host.hasSuffix("." + domain)
        }
    }
}
