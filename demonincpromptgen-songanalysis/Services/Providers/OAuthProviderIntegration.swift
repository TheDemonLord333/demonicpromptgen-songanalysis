import Foundation
import Observation

/// Integration für Anbieter mit OAuth-2.0-Benutzeranmeldung (Authorization Code + PKCE):
/// Spotify (Web API) und YouTube (Google OAuth, YouTube Data API v3).
@MainActor
@Observable
final class OAuthProviderIntegration: ProviderIntegration {
    typealias SearchFunction = @Sendable (_ query: String, _ accessToken: String) async throws -> [SongInfo]

    let provider: MusicProvider
    let accessDescription: String
    let setupInstructions: [String]
    let disconnectHint: String?
    private(set) var status: ProviderStatus

    @ObservationIgnored private let config: OAuthProviderConfig?
    @ObservationIgnored private let tokens: OAuthTokenManager?
    @ObservationIgnored private let authenticator: any WebAuthenticating
    @ObservationIgnored private let searchFunction: SearchFunction
    @ObservationIgnored private let notConfiguredDetail: String
    @ObservationIgnored private var isConnecting = false

    init(
        provider: MusicProvider,
        config: OAuthProviderConfig?,
        tokenStore: any TokenStoring,
        http: any HTTPDataLoading,
        authenticator: any WebAuthenticating,
        accessDescription: String,
        setupInstructions: [String],
        notConfiguredDetail: String,
        disconnectHint: String?,
        search: @escaping SearchFunction
    ) {
        self.provider = provider
        self.config = config
        self.authenticator = authenticator
        self.accessDescription = accessDescription
        self.setupInstructions = setupInstructions
        self.notConfiguredDetail = notConfiguredDetail
        self.disconnectHint = disconnectHint
        self.searchFunction = search
        if let config {
            tokens = OAuthTokenManager(config: config, store: tokenStore, http: http, account: provider.rawValue)
            status = Self.disconnectedStatus()
        } else {
            tokens = nil
            status = .notConfigured(notConfiguredDetail)
        }
    }

    var isConfigured: Bool { config != nil }

    var canConnect: Bool {
        isConfigured && status.kind != .connecting && status.kind != .connected
    }

    var canDisconnect: Bool {
        status.kind == .connected || status.kind == .needsAttention && isConfigured
    }

    var searchAvailability: SearchAvailability {
        guard isConfigured else {
            return .unavailable(reason: "Die \(provider.displayName)-Suche ist noch nicht eingerichtet.")
        }
        guard status.kind == .connected else {
            return .unavailable(reason: "Für die \(provider.displayName)-Suche bitte zuerst in den Einstellungen verbinden.")
        }
        return .available(source: "\(provider.displayName) (angemeldet)")
    }

    func refreshStatus() async {
        guard let tokens else {
            status = .notConfigured(notConfiguredDetail)
            return
        }
        guard status.kind != .connecting else { return }
        status = await tokens.hasStoredToken()
            ? ProviderStatus(.connected, title: "Verbunden")
            : Self.disconnectedStatus()
    }

    /// Liefert ein gültiges Benutzertoken (z. B. für Metadaten), ohne Fehler nach außen zu geben.
    func accessTokenIfConnected() async -> String? {
        guard let tokens else { return nil }
        do {
            return try await tokens.validAccessToken()
        } catch OAuthError.sessionExpired {
            status = Self.expiredStatus()
            return nil
        } catch {
            return nil
        }
    }

    func connect() async {
        guard let config, let tokens else {
            status = .notConfigured(notConfiguredDetail)
            return
        }
        // Mehrere parallele Anmeldungen verhindern.
        guard !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }

        let pkce = PKCE.generate()
        let state = PKCE.randomState()
        guard let url = OAuthRequestFactory.authorizationURL(config: config, codeChallenge: pkce.codeChallenge, state: state),
              let callback = config.callback else {
            status = ProviderStatus(.needsAttention, title: "Konfiguration fehlerhaft", detail: "Redirect-URL oder Anmeldeadresse ist ungültig.")
            return
        }

        status = ProviderStatus(.connecting, title: "Anmeldung läuft …")
        do {
            let callbackURL = try await authenticator.authenticate(url: url, callback: callback)
            switch OAuthRequestFactory.authorizationCode(from: callbackURL, expectedState: state) {
            case .success(let code):
                try await tokens.exchange(code: code, codeVerifier: pkce.codeVerifier)
                status = ProviderStatus(.connected, title: "Verbunden")
            case .failure(let error):
                throw error
            }
        } catch OAuthError.cancelled {
            status = ProviderStatus(.disconnected, title: "Nicht verbunden", detail: OAuthError.cancelled.message)
        } catch let error as OAuthError {
            status = ProviderStatus(.needsAttention, title: "Anmeldung fehlgeschlagen", detail: error.message)
        } catch is CancellationError {
            status = Self.disconnectedStatus()
        } catch {
            status = ProviderStatus(.needsAttention, title: "Anmeldung fehlgeschlagen", detail: NetworkError.userMessage(for: error))
        }
    }

    func disconnect() async {
        guard let tokens else { return }
        await tokens.signOut()
        status = Self.disconnectedStatus()
    }

    func search(_ query: String) async throws -> [SongInfo] {
        guard let tokens else { throw OAuthError.notConfigured }
        do {
            let token = try await tokens.validAccessToken()
            return try await searchFunction(query, token)
        } catch OAuthError.sessionExpired {
            status = Self.expiredStatus()
            throw OAuthError.sessionExpired
        } catch NetworkError.unauthorized {
            await tokens.signOut()
            status = Self.expiredStatus()
            throw OAuthError.sessionExpired
        } catch OAuthError.notConnected {
            status = Self.disconnectedStatus()
            throw OAuthError.notConnected
        }
    }

    private static func disconnectedStatus() -> ProviderStatus {
        ProviderStatus(.disconnected, title: "Nicht verbunden", detail: "Eingerichtet – Anmeldung erforderlich, um die Suche zu nutzen.")
    }

    private static func expiredStatus() -> ProviderStatus {
        ProviderStatus(.needsAttention, title: "Anmeldung abgelaufen", detail: OAuthError.sessionExpired.message)
    }
}
