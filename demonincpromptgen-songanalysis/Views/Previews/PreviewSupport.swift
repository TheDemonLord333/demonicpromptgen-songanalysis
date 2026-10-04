#if DEBUG
import Foundation

/// Demo-Daten ausschließlich für SwiftUI-Previews. Nicht im produktiven Ablauf verwendet.
enum PreviewData {
    private static func url(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/preview")
    }

    static let spotifyLink = SongLink(
        provider: .spotify,
        url: url("https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC"),
        reference: .spotifyTrack(id: "4uLU6hMCjMI75M1A2tKUQC")
    )

    static let spotifySong = SongInfo(
        id: "spotify:4uLU6hMCjMI75M1A2tKUQC",
        provider: .spotify,
        url: url("https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC"),
        title: "Preview-Titel (Demo)",
        artist: "Preview-Künstler (Demo)",
        artworkURL: nil
    )

    static let youtubeVideo = SongInfo(
        id: "youtube:dQw4w9WgXcQ",
        provider: .youtube,
        url: url("https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        title: "Preview-Video (Demo)",
        artist: "Preview-Kanal (Demo)",
        artworkURL: nil
    )

    static let prompt = GeneratedPrompt(
        text: PromptBuilder.build(songURL: spotifyLink.url.absoluteString, configuration: .default),
        sourceLinkURL: spotifyLink.url,
        configuration: .default
    )
}

/// Metadatendienst für Previews – liefert nie echte Netzwerkdaten.
struct PreviewMetadataService: SongMetadataFetching {
    func metadata(for link: SongLink) async throws -> SongInfo {
        throw MetadataError.noMetadata
    }
}

/// Zwischenablage für Previews.
final class PreviewPasteboard: PasteboardWriting {
    func copy(_ text: String) {}
}

extension AppDependencies {
    /// Abhängigkeiten ohne Anbieterkonfiguration, Keychain oder Netzwerk-Metadaten.
    static func preview() -> AppDependencies {
        let suite = "preview.\(UUID().uuidString)"
        return AppDependencies(
            configuration: .empty,
            tokenStore: InMemoryTokenStore(),
            defaults: UserDefaults(suiteName: suite) ?? .standard,
            metadataService: PreviewMetadataService(),
            pasteboard: PreviewPasteboard()
        )
    }
}
#endif
