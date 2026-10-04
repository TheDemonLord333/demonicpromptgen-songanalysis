import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated enum ShortLinkError: Error, Equatable, Sendable {
    case notResolvable
    case foreignHost
    case tooManyRedirects
    case notASong

    var message: String {
        switch self {
        case .notResolvable:
            "Der Kurzlink konnte nicht aufgelöst werden. Der Link bleibt für den Prompt verwendbar."
        case .foreignHost:
            "Der Kurzlink leitet auf eine nicht erlaubte Adresse weiter."
        case .tooManyRedirects:
            "Der Kurzlink hat zu viele Weiterleitungen."
        case .notASong:
            "Der Kurzlink führt nicht zu einem einzelnen Song."
        }
    }
}

/// Liefert das Ziel einer einzelnen HTTP-Weiterleitung, ohne ihr automatisch zu folgen.
nonisolated protocol RedirectProbing: Sendable {
    /// - Returns: Absolute Ziel-URL der Weiterleitung oder `nil`, wenn keine Weiterleitung erfolgt.
    func redirectTarget(of url: URL) async throws -> URL?
}

/// Löst Kurzlinks mit einer begrenzten Anzahl von Weiterleitungen auf.
/// Jeder Zwischenschritt wird erneut gegen eine exakte Hostliste des Anbieters geprüft.
nonisolated struct ShortLinkResolver: Sendable {
    static let maxRedirects = 5

    static let allowedHops: [MusicProvider: Set<String>] = [
        .spotify: ["spotify.link", "spoti.fi", "spotify.app.link", "open.spotify.com"],
        .appleMusic: ["apple.co", "music.apple.com", "geo.music.apple.com", "itunes.apple.com"],
        .youtube: ["youtu.be", "www.youtube.com", "youtube.com", "m.youtube.com", "music.youtube.com"],
    ]

    let prober: any RedirectProbing

    func resolve(_ link: SongLink) async throws -> SongLink {
        guard link.needsResolution else { return link }
        guard Self.isAllowedHop(link.url, provider: link.provider) else {
            throw ShortLinkError.foreignHost
        }

        var current = link.url
        for _ in 0..<Self.maxRedirects {
            try Task.checkCancellation()
            guard let next = try await prober.redirectTarget(of: current) else {
                throw ShortLinkError.notResolvable
            }
            guard Self.isAllowedHop(next, provider: link.provider) else {
                throw ShortLinkError.foreignHost
            }
            switch SongLinkParser.parse(next.absoluteString) {
            case .success(let parsed) where parsed.provider == link.provider && !parsed.needsResolution:
                return parsed
            case .success(let parsed) where parsed.needsResolution:
                current = parsed.url
            case .success, .failure:
                // Erlaubter Zwischenhost (z. B. spotify.app.link) ohne erkennbaren Song.
                guard let host = AllowedHosts.normalizedHost(of: next),
                      !SongLinkParser.spotifyHosts.contains(host),
                      !SongLinkParser.appleMusicHosts.contains(host) else {
                    throw ShortLinkError.notASong
                }
                current = next
            }
        }
        throw ShortLinkError.tooManyRedirects
    }

    static func isAllowedHop(_ url: URL, provider: MusicProvider) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = AllowedHosts.normalizedHost(of: url),
              let allowed = allowedHops[provider] else {
            return false
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if components?.user != nil || components?.password != nil { return false }
        return allowed.contains(host)
    }
}

/// `RedirectProbing` über `URLSession`, das automatische Weiterleitungen unterbindet
/// und nur den `Location`-Header einer 3xx-Antwort auswertet.
nonisolated final class URLSessionRedirectProber: RedirectProbing, @unchecked Sendable {
    // Unveränderlich nach der Initialisierung; URLSession ist threadsicher.
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration, delegate: RedirectBlockingDelegate(), delegateQueue: nil)
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    func redirectTarget(of url: URL) async throws -> URL? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (300...399).contains(http.statusCode),
              let location = http.value(forHTTPHeaderField: "Location"),
              let target = URL(string: location, relativeTo: url)?.absoluteURL else {
            return nil
        }
        return target
    }
}

/// Unterbindet automatische Weiterleitungen; der Resolver prüft jeden Schritt selbst.
nonisolated private final class RedirectBlockingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
