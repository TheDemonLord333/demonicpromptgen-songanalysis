import CryptoKit
import Foundation

/// Proof Key for Code Exchange (RFC 7636) mit Methode `S256`.
nonisolated struct PKCE: Sendable {
    let codeVerifier: String
    let codeChallenge: String

    private static let unreserved = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// Erzeugt einen zufälligen Verifier (64 Zeichen) und die zugehörige Challenge.
    static func generate() -> PKCE {
        let verifier = randomString(length: 64)
        return PKCE(codeVerifier: verifier, codeChallenge: challenge(for: verifier))
    }

    static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncoded(Data(digest))
    }

    /// Zufälliger, URL-sicherer `state`-Wert zum Schutz vor CSRF.
    static func randomState() -> String {
        randomString(length: 32)
    }

    static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomString(length: Int) -> String {
        // SystemRandomNumberGenerator ist auf Apple-Plattformen kryptografisch sicher.
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).compactMap { _ in unreserved.randomElement(using: &generator) })
    }
}
