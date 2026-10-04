import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Konfiguration eines OAuth-2.0-Anbieters für den Authorization-Code-Flow mit PKCE.
/// Enthält ausschließlich öffentliche Werte – niemals ein Client Secret.
nonisolated struct OAuthProviderConfig: Equatable, Sendable {
    let authorizeEndpoint: URL
    let tokenEndpoint: URL
    let revokeEndpoint: URL?
    let clientID: String
    let redirectURI: URL
    let scopes: [String]
    let additionalAuthorizeParameters: [String: String]

    /// Callback, den `ASWebAuthenticationSession` abfangen soll.
    var callback: OAuthCallback? {
        guard let scheme = redirectURI.scheme else { return nil }
        if scheme.lowercased() == "https" {
            guard let host = redirectURI.host else { return nil }
            return .https(host: host, path: redirectURI.path.isEmpty ? "/" : redirectURI.path)
        }
        return .customScheme(scheme)
    }
}

nonisolated enum OAuthCallback: Equatable, Sendable {
    case customScheme(String)
    case https(host: String, path: String)
}

/// Gespeichertes Token (Keychain).
nonisolated struct OAuthToken: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    func isValid(at date: Date, leeway: TimeInterval = 60) -> Bool {
        expiresAt.timeIntervalSince(date) > leeway
    }
}

/// Antwort des Token-Endpunkts (RFC 6749).
nonisolated struct OAuthTokenResponse: Decodable, Sendable {
    let accessToken: String
    let tokenType: String?
    let expiresIn: Int?
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }

    /// Wandelt die Antwort in ein Token um. Fehlt ein neues Refresh-Token, bleibt das bisherige erhalten.
    func token(issuedAt date: Date, previousRefreshToken: String?) -> OAuthToken {
        OAuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken ?? previousRefreshToken,
            expiresAt: date.addingTimeInterval(TimeInterval(expiresIn ?? 3600))
        )
    }
}

nonisolated enum OAuthError: Error, Equatable, Sendable {
    case notConfigured
    case alreadyInProgress
    case cancelled
    case accessDenied
    case stateMismatch
    case missingCode
    case providerError(String)
    case notConnected
    case sessionExpired
    case unsupportedCallback
    case tokenExchangeFailed

    var message: String {
        switch self {
        case .notConfigured: "Diese Integration ist noch nicht eingerichtet."
        case .alreadyInProgress: "Eine Anmeldung läuft bereits."
        case .cancelled: "Anmeldung abgebrochen."
        case .accessDenied: "Der Zugriff wurde nicht erlaubt."
        case .stateMismatch: "Die Anmeldung konnte nicht sicher bestätigt werden. Bitte erneut versuchen."
        case .missingCode: "Der Anbieter hat keinen Autorisierungscode geliefert."
        case .providerError(let code): "Der Anbieter hat die Anmeldung abgelehnt (\(code))."
        case .notConnected: "Nicht verbunden."
        case .sessionExpired: "Die Anmeldung ist abgelaufen. Bitte erneut verbinden."
        case .unsupportedCallback: "Die konfigurierte Redirect-URL wird auf diesem iOS nicht unterstützt."
        case .tokenExchangeFailed: "Das Token konnte nicht abgerufen werden."
        }
    }
}

/// Erzeugt die Anfragen des PKCE-Flows. Reine Funktionen, daher gut testbar.
nonisolated enum OAuthRequestFactory {
    static func authorizationURL(config: OAuthProviderConfig, codeChallenge: String, state: String) -> URL? {
        guard var components = URLComponents(url: config.authorizeEndpoint, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var items = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI.absoluteString),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "state", value: state),
        ]
        if !config.scopes.isEmpty {
            items.append(URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")))
        }
        for key in config.additionalAuthorizeParameters.keys.sorted() {
            items.append(URLQueryItem(name: key, value: config.additionalAuthorizeParameters[key]))
        }
        components.queryItems = items
        return components.url
    }

    static func tokenRequest(config: OAuthProviderConfig, code: String, codeVerifier: String) -> URLRequest {
        formRequest(url: config.tokenEndpoint, parameters: [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", config.redirectURI.absoluteString),
            ("client_id", config.clientID),
            ("code_verifier", codeVerifier),
        ])
    }

    static func refreshRequest(config: OAuthProviderConfig, refreshToken: String) -> URLRequest {
        formRequest(url: config.tokenEndpoint, parameters: [
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("client_id", config.clientID),
        ])
    }

    static func revokeRequest(config: OAuthProviderConfig, token: String) -> URLRequest? {
        guard let endpoint = config.revokeEndpoint else { return nil }
        return formRequest(url: endpoint, parameters: [("token", token)])
    }

    static func formRequest(url: URL, parameters: [(String, String)]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters
            .map { "\(formEncode($0.0))=\(formEncode($0.1))" }
            .joined(separator: "&")
            .data(using: .utf8)
        return request
    }

    /// Nur „unreserved“-Zeichen aus RFC 3986 bleiben unkodiert.
    private static let formAllowed = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? value
    }

    /// Wertet die Callback-URL aus und prüft den `state`-Parameter.
    static func authorizationCode(from callbackURL: URL, expectedState: String) -> Result<String, OAuthError> {
        guard let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems else {
            return .failure(.missingCode)
        }
        func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }

        if let error = value("error") {
            return .failure(error == "access_denied" ? .accessDenied : .providerError(error))
        }
        guard value("state") == expectedState else {
            return .failure(.stateMismatch)
        }
        guard let code = value("code"), !code.isEmpty else {
            return .failure(.missingCode)
        }
        return .success(code)
    }
}
