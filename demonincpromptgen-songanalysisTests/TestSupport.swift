import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import demonincpromptgen_songanalysis

/// Testdaten – ausschließlich für Tests.
enum TestLinks {
    static let spotify = "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC"
    static let spotifyID = "4uLU6hMCjMI75M1A2tKUQC"
    static let spotifyOther = "https://open.spotify.com/track/7ouMYWpwJ422jRcDASZB7P"
    static let youtube = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    static let apple = "https://music.apple.com/de/album/never-gonna-give-you-up/1559523357?i=1559523359"
}

/// Erzeugt eine URL ohne Force-Unwrap; ungültige Testkonstanten fallen auf eine erkennbare Datei-URL zurück.
func testURL(_ string: String) -> URL {
    URL(string: string) ?? URL(fileURLWithPath: "/invalid-test-url")
}

func parsedLink(_ string: String) throws -> SongLink {
    try SongLinkParser.parse(string).get()
}

@MainActor
final class RecordingPasteboard: PasteboardWriting {
    private(set) var copied: [String] = []
    func copy(_ text: String) { copied.append(text) }
}

/// Metadatendienst, dessen Antworten der Test gezielt und in beliebiger Reihenfolge freigibt.
/// Ignoriert Abbrüche absichtlich, um verspätete Antworten zu simulieren.
actor ControlledMetadataService: SongMetadataFetching {
    private var pending: [URL: CheckedContinuation<SongInfo, Error>] = [:]
    private var requested: [URL] = []

    nonisolated func metadata(for link: SongLink) async throws -> SongInfo {
        try await register(link)
    }

    private func register(_ link: SongLink) async throws -> SongInfo {
        requested.append(link.url)
        return try await withCheckedThrowingContinuation { continuation in
            pending[link.url] = continuation
        }
    }

    func requestedURLs() -> [URL] { requested }

    func complete(_ url: URL, with song: SongInfo) {
        pending.removeValue(forKey: url)?.resume(returning: song)
    }

    func fail(_ url: URL, with error: Error) {
        pending.removeValue(forKey: url)?.resume(throwing: error)
    }

    /// Wartet, bis eine Anfrage für die URL eingegangen ist.
    func waitForRequest(_ url: URL) async {
        for _ in 0..<500 where pending[url] == nil {
            try? await Task.sleep(for: .milliseconds(2))
        }
    }
}

/// Liefert sofort ein festes Ergebnis.
struct StaticMetadataService: SongMetadataFetching {
    let result: Result<SongInfo, NetworkError>
    func metadata(for link: SongLink) async throws -> SongInfo {
        try result.get()
    }
}

/// HTTP-Fake mit vordefinierten Antworten pro Pfad.
final class StubHTTPClient: HTTPDataLoading, @unchecked Sendable {
    struct Stub {
        let status: Int
        let body: String
    }

    private let lock = NSLock()
    private var stubs: [String: [Stub]]
    private(set) var requests: [URLRequest] = []

    init(stubs: [String: [Stub]]) {
        self.stubs = stubs
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.count
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url, AllowedHosts.isAllowedAPIRequest(url) else {
            throw NetworkError.hostNotAllowed
        }
        guard let stub = nextStub(for: request) else {
            throw NetworkError.httpStatus(404)
        }
        guard let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: nil) else {
            throw NetworkError.invalidResponse
        }
        return (Data(stub.body.utf8), response)
    }

    private func nextStub(for request: URLRequest) -> Stub? {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
        guard let key = request.url?.path, var queue = stubs[key], !queue.isEmpty else {
            return nil
        }
        let stub = queue.count > 1 ? queue.removeFirst() : queue[0]
        stubs[key] = queue
        return stub
    }
}

/// Weiterleitungs-Fake: bildet URL → nächste URL ab.
struct MapRedirectProber: RedirectProbing {
    let map: [String: String]
    func redirectTarget(of url: URL) async throws -> URL? {
        map[url.absoluteString].flatMap(URL.init(string:))
    }
}

@MainActor
func makeSettings() -> AppSettings {
    let suite = "tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    return AppSettings(defaults: defaults)
}

/// Wartet kurz, bis eine Bedingung erfüllt ist (für asynchrone Zustandsänderungen auf dem MainActor).
@MainActor
func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<500 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(2))
    }
    return condition()
}
