import Foundation

/// Speicher für sensible OAuth-Tokens. In der App: Keychain (`KeychainTokenStore`).
nonisolated protocol TokenStoring: Sendable {
    func loadToken(account: String) throws -> OAuthToken?
    func saveToken(_ token: OAuthToken, account: String) throws
    func deleteToken(account: String) throws
}

/// Flüchtiger Speicher für Tests und Previews.
nonisolated final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [String: OAuthToken]

    init(tokens: [String: OAuthToken] = [:]) {
        self.tokens = tokens
    }

    func loadToken(account: String) throws -> OAuthToken? {
        lock.lock()
        defer { lock.unlock() }
        return tokens[account]
    }

    func saveToken(_ token: OAuthToken, account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        tokens[account] = token
    }

    func deleteToken(account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        tokens[account] = nil
    }
}
