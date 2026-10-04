import SwiftUI

/// Element 6: kompakte Songkarte (Cover links, Titel und Künstler rechts, Anbieter-Badge).
struct SongCardView: View {
    let state: MetadataState

    @ScaledMetric(relativeTo: .body) private var artworkSize: CGFloat = 64

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ArtworkView(url: artworkURL, size: artworkSize, isLoading: isLoading)
            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .demonCard(tint: Theme.blurple)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("songCard")
    }

    private var artworkURL: URL? {
        if case .loaded(let song) = state { return song.artworkURL }
        return nil
    }

    private var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            Text("Noch kein Song ausgewählt")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Link einfügen oder über die Songauswahl suchen.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)

        case .loading(let link):
            ProviderBadge(provider: link.provider)
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .tint(Theme.textSecondary)
                Text("Metadaten werden geladen …")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

        case .loaded(let song):
            ProviderBadge(provider: song.provider)
            Text(song.title ?? "\(song.provider.titleLabel) nicht verfügbar")
                .font(.headline)
                .foregroundStyle(song.title == nil ? Theme.textSecondary : Theme.textPrimary)
                .lineLimit(2)
            Text(creatorLine(for: song))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)

        case .unavailable(let link, let message):
            ProviderBadge(provider: link.provider)
            Text("Keine Metadaten verfügbar")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Label("Der Link kann trotzdem verwendet werden.", systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(Theme.spotifyGreen)
        }
    }

    private func creatorLine(for song: SongInfo) -> String {
        guard let artist = song.artist else {
            return "\(song.provider.creatorLabel) nicht verfügbar"
        }
        // YouTube liefert Kanalnamen – als solche beschriften, keine Künstlerzuordnung behaupten.
        return song.provider == .youtube ? "\(song.provider.creatorLabel): \(artist)" : artist
    }
}

#if DEBUG
#Preview("Songkarte – Zustände") {
    ScrollView {
        VStack(spacing: 12) {
            SongCardView(state: .idle)
            SongCardView(state: .loading(PreviewData.spotifyLink))
            SongCardView(state: .loaded(PreviewData.spotifySong))
            SongCardView(state: .loaded(PreviewData.youtubeVideo))
            SongCardView(state: .unavailable(PreviewData.spotifyLink, message: MetadataError.noMetadata.message))
        }
        .padding()
    }
    .background(Theme.background)
}
#endif
