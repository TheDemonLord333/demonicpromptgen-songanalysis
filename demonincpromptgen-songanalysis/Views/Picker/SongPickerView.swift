import SwiftUI

/// Sheet zur Songauswahl: Anbieterauswahl, Suche, Ergebnisliste und Übernahme.
struct SongPickerView: View {
    @Bindable var viewModel: SongPickerViewModel
    let onSelect: (SongInfo) -> Void
    let onManualEntry: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Anbieter", selection: $viewModel.selectedProvider) {
                    ForEach(MusicProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("providerPicker")

                switch viewModel.availability {
                case .available(let source):
                    searchField
                    Text("Quelle: \(source)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    results
                case .unavailable(let reason):
                    unavailableCard(reason: reason)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Song auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.card, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .task { await viewModel.refreshStatuses() }
        }
        .tint(Theme.blurple)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: viewModel.selectedProvider)
        .onDisappear { viewModel.cancel() }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            TextField("Suche", text: $viewModel.query, prompt: Text("Titel oder Künstler suchen …").foregroundStyle(Theme.textSecondary))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
                .onSubmit { viewModel.retry() }
                .foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("songSearchField")
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 46)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(Theme.elevated))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Theme.blurple.opacity(isSearchFocused ? 0.8 : 0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var results: some View {
        switch viewModel.state {
        case .idle:
            hint("Mindestens \(SongPickerViewModel.minimumQueryLength) Zeichen eingeben, um zu suchen.")
            Spacer(minLength: 0)
        case .searching:
            HStack {
                Spacer()
                ProgressView("Suche läuft …")
                    .tint(Theme.textSecondary)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(.top, 24)
            Spacer(minLength: 0)
        case .noResults:
            ContentUnavailableView.search(text: viewModel.trimmedQuery)
        case .failed(let message):
            ContentUnavailableView {
                Label("Suche fehlgeschlagen", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Erneut versuchen") { viewModel.retry() }
                    .buttonStyle(.borderedProminent)
            }
        case .results(let songs):
            List(songs) { song in
                Button {
                    onSelect(song)
                    dismiss()
                } label: {
                    SongResultRow(song: song)
                }
                .listRowBackground(Theme.card)
                .accessibilityHint("Übernimmt diesen Song.")
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 8)
    }

    private func unavailableCard(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(reason, systemImage: "lock.circle")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let integration = viewModel.currentIntegration {
                ProviderStatusLabel(status: integration.status)
            }
            Text("Du kannst den Song-Link auch direkt aus der \(viewModel.selectedProvider.displayName)-App teilen und manuell einfügen – Prompt-Erstellung und Kopieren funktionieren ohne Anmeldung.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                onManualEntry()
                dismiss()
            } label: {
                Label("Link manuell einfügen", systemImage: "link")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(IconButtonStyle(tint: Theme.blurple))
            .accessibilityIdentifier("manualEntryButton")
        }
        .padding(16)
        .demonCard(tint: Theme.blurple)
    }
}

/// Ergebniszeile mit Cover, Titel und Künstler bzw. Kanal.
struct SongResultRow: View {
    let song: SongInfo

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: song.artworkURL, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title ?? "\(song.provider.titleLabel) nicht verfügbar")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text(song.artist.map { song.provider == .youtube ? "\(song.provider.creatorLabel): \($0)" : $0 }
                     ?? "\(song.provider.creatorLabel) nicht verfügbar")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Statusanzeige einer Integration.
struct ProviderStatusLabel: View {
    let status: ProviderStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if status.kind == .connecting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                        .accessibilityHidden(true)
                }
                Text(status.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            if let detail = status.detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch status.kind {
        case .notConfigured: "wrench.and.screwdriver"
        case .disconnected: "circle"
        case .connecting: "hourglass"
        case .connected: "checkmark.circle.fill"
        case .needsAttention: "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch status.kind {
        case .notConfigured: Theme.textSecondary
        case .disconnected: Theme.textSecondary
        case .connecting: Theme.blurple
        case .connected: Theme.spotifyGreen
        case .needsAttention: Theme.warning
        }
    }
}

#if DEBUG
#Preview("Songauswahl") {
    let dependencies = AppDependencies.preview()
    return SongPickerView(viewModel: dependencies.pickerViewModel, onSelect: { _ in }, onManualEntry: {})
}

#Preview("Ergebniszeilen") {
    List {
        SongResultRow(song: PreviewData.spotifySong)
        SongResultRow(song: PreviewData.youtubeVideo)
    }
    .preferredColorScheme(.dark)
}
#endif
