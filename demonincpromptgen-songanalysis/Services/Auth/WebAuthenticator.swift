import AuthenticationServices
import UIKit

/// Startet eine Web-Anmeldung über `ASWebAuthenticationSession` (kein eingebetteter WebView,
/// kein Scraping). Verhindert parallele Anmeldungen.
@MainActor
protocol WebAuthenticating: AnyObject {
    func authenticate(url: URL, callback: OAuthCallback) async throws -> URL
}

@MainActor
final class WebAuthenticator: NSObject, WebAuthenticating, ASWebAuthenticationPresentationContextProviding {
    private var activeSession: ASWebAuthenticationSession?

    func authenticate(url: URL, callback: OAuthCallback) async throws -> URL {
        guard activeSession == nil else {
            throw OAuthError.alreadyInProgress
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            // Explizit @Sendable: ASWebAuthenticationSession ruft den Handler außerhalb des Swift-Actor-Kontexts auf.
            let completion: @Sendable (URL?, Error?) -> Void = { callbackURL, error in
                // Starke Referenz ist unkritisch: Der Zyklus endet, sobald `activeSession` geleert wird.
                Task { @MainActor in
                    self.activeSession = nil
                }
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let authError = error as? ASWebAuthenticationSessionError,
                          authError.code == .canceledLogin {
                    continuation.resume(throwing: OAuthError.cancelled)
                } else {
                    continuation.resume(throwing: OAuthError.providerError("web_auth_failed"))
                }
            }

            let session: ASWebAuthenticationSession
            if #available(iOS 17.4, *) {
                let sessionCallback: ASWebAuthenticationSession.Callback
                switch callback {
                case .customScheme(let scheme):
                    sessionCallback = .customScheme(scheme)
                case .https(let host, let path):
                    sessionCallback = .https(host: host, path: path)
                }
                session = ASWebAuthenticationSession(url: url, callback: sessionCallback, completionHandler: completion)
            } else {
                guard case .customScheme(let scheme) = callback else {
                    continuation.resume(throwing: OAuthError.unsupportedCallback)
                    return
                }
                session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme, completionHandler: completion)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session

            if !session.start() {
                activeSession = nil
                continuation.resume(throwing: OAuthError.providerError("web_auth_not_started"))
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
            return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
        }
    }
}
