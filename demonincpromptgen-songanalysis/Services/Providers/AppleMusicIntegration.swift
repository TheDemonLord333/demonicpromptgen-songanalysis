import Foundation
import MusicKit
import Observation

/// Apple-Music-Integration.
///
/// - Mit MusicKit-Berechtigung: Katalogsuche über `MusicCatalogSearchRequest`
///   (erfordert den aktivierten App-Service „MusicKit“ für die Bundle-ID).
/// - Ohne Berechtigung: öffentliche iTunes Search API von Apple (ohne Anmeldung).
/// Auf die persönliche Mediathek wird nicht zugegriffen.
@MainActor
@Observable
final class AppleMusicIntegration: ProviderIntegration {
    let provider: MusicProvider = .appleMusic
    let disconnectHint: String? = "Die MusicKit-Berechtigung kann nur in den iOS-Einstellungen widerrufen werden: Einstellungen › Datenschutz & Sicherheit › Medien & Apple Music."
    let accessDescription = """
    „Verbinden“ fragt die iOS-Berechtigung für Apple Music (MusicKit) an. Die App nutzt sie ausschließlich für die Katalogsuche – \
    sie liest nicht deine persönliche Mediathek. Ohne Berechtigung sucht die App über die öffentliche iTunes Search API von Apple.
    """
    let setupInstructions = [
        "Im Apple Developer Portal unter Identifiers › App-ID den App-Service „MusicKit“ aktivieren (kein privater Schlüssel in der App nötig – Tokens erzeugt iOS automatisch).",
        "Info.plist-Eintrag NSAppleMusicUsageDescription ist bereits gesetzt.",
        "Ohne diese Einrichtung funktionieren Metadaten und Suche über die öffentliche iTunes-API weiterhin.",
    ]

    private(set) var authorization: MusicAuthorization.Status
    private(set) var musicKitProblem: String?

    @ObservationIgnored private let iTunes: ITunesAPI
    @ObservationIgnored private var isRequesting = false

    init(http: any HTTPDataLoading) {
        iTunes = ITunesAPI(http: http)
        authorization = MusicAuthorization.currentStatus
    }

    var status: ProviderStatus {
        switch authorization {
        case .authorized:
            if let musicKitProblem {
                return ProviderStatus(.needsAttention, title: "MusicKit nicht verfügbar", detail: musicKitProblem)
            }
            return ProviderStatus(.connected, title: "Verbunden (MusicKit)", detail: "Katalogsuche über Apple Music.")
        case .notDetermined:
            return ProviderStatus(.disconnected, title: "Nicht verbunden", detail: "Suche und Metadaten nutzen die öffentliche iTunes-API von Apple.")
        case .denied:
            return ProviderStatus(.needsAttention, title: "Zugriff verweigert", detail: "Änderbar unter Einstellungen › Datenschutz & Sicherheit › Medien & Apple Music. Die öffentliche Suche bleibt verfügbar.")
        case .restricted:
            return ProviderStatus(.needsAttention, title: "Eingeschränkt", detail: "Apple Music ist auf diesem Gerät eingeschränkt. Die öffentliche Suche bleibt verfügbar.")
        @unknown default:
            return ProviderStatus(.disconnected, title: "Unbekannter Status")
        }
    }

    var canConnect: Bool {
        authorization == .notDetermined && !isRequesting
    }

    var canDisconnect: Bool { false }

    var searchAvailability: SearchAvailability {
        if authorization == .authorized, musicKitProblem == nil {
            return .available(source: "Apple Music (MusicKit)")
        }
        return .available(source: "Öffentliche iTunes-Suche von Apple")
    }

    func refreshStatus() async {
        authorization = MusicAuthorization.currentStatus
    }

    func connect() async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }
        authorization = await MusicAuthorization.request()
    }

    func disconnect() async {
        // Technisch nicht in der App möglich – siehe `disconnectHint`.
        authorization = MusicAuthorization.currentStatus
    }

    func search(_ query: String) async throws -> [SongInfo] {
        if authorization == .authorized, musicKitProblem == nil {
            do {
                return try await searchWithMusicKit(query)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Häufigste Ursache: App-Service „MusicKit“ ist für die Bundle-ID nicht aktiviert.
                musicKitProblem = "MusicKit-Anfrage fehlgeschlagen. Prüfe den App-Service „MusicKit“ im Developer Portal. Die öffentliche iTunes-Suche wird verwendet."
            }
        }
        try Task.checkCancellation()
        return try await iTunes.search(term: query, country: Locale.current.region?.identifier)
    }

    private func searchWithMusicKit(_ query: String) async throws -> [SongInfo] {
        var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
        request.limit = 25
        let response = try await request.response()
        return response.songs.compactMap { song -> SongInfo? in
            guard let url = song.url,
                  case .success(let link) = SongLinkParser.parse(url.absoluteString),
                  link.provider == .appleMusic,
                  let songID = link.songID else {
                return nil
            }
            return SongInfo(
                id: songID,
                provider: .appleMusic,
                url: link.url,
                title: song.title,
                artist: song.artistName,
                artworkURL: song.artwork?.url(width: 300, height: 300)
            )
        }
    }
}
