import Foundation

/// Öffentliche Entwicklerkonfiguration der Anbieter, gelesen aus der Info.plist
/// (befüllt über `Config/Providers.xcconfig` bzw. `Config/Providers.local.xcconfig`).
///
/// Enthält nur öffentliche Client-IDs und Redirect-URLs – keine Secrets.
nonisolated struct ProviderConfiguration: Equatable, Sendable {
    static let spotifyClientIDKey = "SpotifyClientID"
    static let spotifyRedirectURIKey = "SpotifyRedirectURI"
    static let googleClientIDKey = "GoogleIOSClientID"

    let spotifyClientID: String?
    let spotifyRedirectURI: URL?
    let googleClientID: String?

    static let empty = ProviderConfiguration(spotifyClientID: nil, spotifyRedirectURI: nil, googleClientID: nil)

    init(spotifyClientID: String?, spotifyRedirectURI: URL?, googleClientID: String?) {
        self.spotifyClientID = spotifyClientID
        self.spotifyRedirectURI = spotifyRedirectURI
        self.googleClientID = googleClientID
    }

    init(infoDictionary: [String: Any]?) {
        let info = infoDictionary ?? [:]
        spotifyClientID = Self.cleanValue(info[Self.spotifyClientIDKey])
        spotifyRedirectURI = Self.cleanValue(info[Self.spotifyRedirectURIKey]).flatMap(Self.validRedirectURI)
        googleClientID = Self.cleanValue(info[Self.googleClientIDKey]).flatMap { value in
            value.hasSuffix(".apps.googleusercontent.com") ? value : nil
        }
    }

    /// Leere oder nicht ersetzte Build-Variablen (`$(…)`) gelten als „nicht eingerichtet“.
    static func cleanValue(_ raw: Any?) -> String? {
        guard let string = (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty,
              !string.contains("$(") else {
            return nil
        }
        return string
    }

    static func validRedirectURI(_ value: String) -> URL? {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              let url = components.url else {
            return nil
        }
        if scheme == "https" {
            return components.host?.isEmpty == false ? url : nil
        }
        // Eigenes URL-Schema: keine Web-Schemata, keine leeren Hosts/Pfade.
        let forbidden: Set<String> = ["http", "file", "javascript", "data"]
        guard !forbidden.contains(scheme), (components.host?.isEmpty == false || !components.path.isEmpty) else {
            return nil
        }
        return url
    }

    // MARK: Spotify

    var spotifyOAuth: OAuthProviderConfig? {
        guard let clientID = spotifyClientID,
              let redirectURI = spotifyRedirectURI,
              let authorize = URL(string: "https://accounts.spotify.com/authorize"),
              let token = URL(string: "https://accounts.spotify.com/api/token") else {
            return nil
        }
        return OAuthProviderConfig(
            authorizeEndpoint: authorize,
            tokenEndpoint: token,
            revokeEndpoint: nil, // Spotify bietet keinen Widerrufs-Endpunkt für Apps an.
            clientID: clientID,
            redirectURI: redirectURI,
            scopes: [], // Suche und Track-Metadaten benötigen keine zusätzlichen Scopes.
            additionalAuthorizeParameters: [:]
        )
    }

    // MARK: Google / YouTube

    /// Für iOS-OAuth-Clients nutzt Google die umgekehrte Client-ID als URL-Schema.
    var googleRedirectURI: URL? {
        guard let clientID = googleClientID else { return nil }
        let identifier = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        guard !identifier.isEmpty,
              identifier.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else {
            return nil
        }
        return URL(string: "com.googleusercontent.apps.\(identifier):/oauth2redirect")
    }

    var youtubeOAuth: OAuthProviderConfig? {
        guard let clientID = googleClientID,
              let redirectURI = googleRedirectURI,
              let authorize = URL(string: "https://accounts.google.com/o/oauth2/v2/auth"),
              let token = URL(string: "https://oauth2.googleapis.com/token"),
              let revoke = URL(string: "https://oauth2.googleapis.com/revoke") else {
            return nil
        }
        return OAuthProviderConfig(
            authorizeEndpoint: authorize,
            tokenEndpoint: token,
            revokeEndpoint: revoke,
            clientID: clientID,
            redirectURI: redirectURI,
            scopes: ["https://www.googleapis.com/auth/youtube.readonly"],
            additionalAuthorizeParameters: [:]
        )
    }
}
