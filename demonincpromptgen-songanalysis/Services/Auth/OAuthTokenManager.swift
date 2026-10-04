import Foundation

/// Verwaltet das OAuth-Token eines Anbieters: Laden, Austausch, Erneuerung und Abmeldung.
///
/// Als `actor` umgesetzt, damit parallele Aufrufe nur eine einzige Token-Erneuerung auslösen.
/// Tokens werden nie geloggt.
actor OAuthTokenManager {
    private let config: OAuthProviderConfig
    private let store: any TokenStoring
    private let http: any HTTPDataLoading
    private let account: String
    private let now: @Sendable () -> Date

    private var cachedToken: OAuthToken?
    private var didLoad = false
    private var refreshTask: Task<OAuthToken, Error>?

    init(
        config: OAuthProviderConfig,
        store: any TokenStoring,
        http: any HTTPDataLoading,
        account: String,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.config = config
        self.store = store
        self.http = http
        self.account = account
        self.now = now
    }

    /// `true`, wenn ein Token (ggf. erneuerbar) gespeichert ist.
    func hasStoredToken() -> Bool {
        currentToken() != nil
    }

    /// Liefert ein gültiges Access-Token und erneuert es bei Bedarf.
    func validAccessToken() async throws -> String {
        guard let token = currentToken() else {
            throw OAuthError.notConnected
        }
        if token.isValid(at: now()) {
            return token.accessToken
        }
        guard let refreshToken = token.refreshToken else {
            removeToken()
            throw OAuthError.sessionExpired
        }

        if let running = refreshTask {
            return try await running.value.accessToken
        }

        let task = Task { () throws -> OAuthToken in
            let request = OAuthRequestFactory.refreshRequest(config: config, refreshToken: refreshToken)
            let response = try await http.decoded(OAuthTokenResponse.self, for: request)
            return response.token(issuedAt: now(), previousRefreshToken: refreshToken)
        }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            let refreshed = try await task.value
            persist(refreshed)
            return refreshed.accessToken
        } catch let error as NetworkError {
            switch error {
            case .httpStatus(400), .unauthorized:
                // Refresh-Token ungültig oder widerrufen (`invalid_grant`).
                removeToken()
                throw OAuthError.sessionExpired
            default:
                throw error
            }
        }
    }

    /// Tauscht einen Autorisierungscode gegen ein Token (PKCE, ohne Client Secret).
    func exchange(code: String, codeVerifier: String) async throws {
        let request = OAuthRequestFactory.tokenRequest(config: config, code: code, codeVerifier: codeVerifier)
        let response: OAuthTokenResponse
        do {
            response = try await http.decoded(OAuthTokenResponse.self, for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw OAuthError.tokenExchangeFailed
        }
        persist(response.token(issuedAt: now(), previousRefreshToken: nil))
    }

    /// Meldet ab: widerruft das Token beim Anbieter (falls unterstützt) und löscht es lokal.
    func signOut() async {
        let token = currentToken()
        removeToken()
        if let token,
           let request = OAuthRequestFactory.revokeRequest(config: config, token: token.refreshToken ?? token.accessToken) {
            _ = try? await http.data(for: request)
        }
    }

    private func currentToken() -> OAuthToken? {
        if !didLoad {
            cachedToken = try? store.loadToken(account: account)
            didLoad = true
        }
        return cachedToken
    }

    private func persist(_ token: OAuthToken) {
        cachedToken = token
        didLoad = true
        try? store.saveToken(token, account: account)
    }

    private func removeToken() {
        cachedToken = nil
        didLoad = true
        try? store.deleteToken(account: account)
    }
}
