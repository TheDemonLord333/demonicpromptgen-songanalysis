import SwiftUI
import UIKit

/// Details einer Anbieterintegration: tatsächlicher Status, Verbinden/Trennen, Zugriff, Einrichtung.
struct ProviderDetailView: View {
    let integration: any ProviderIntegration
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                ProviderStatusLabel(status: integration.status)
                    .listRowBackground(Theme.card)
            } header: {
                Text("Status")
            }

            Section {
                if integration.canConnect {
                    Button {
                        Task { await integration.connect() }
                    } label: {
                        Label("Verbinden", systemImage: "person.badge.key")
                    }
                    .listRowBackground(Theme.card)
                }
                if integration.status.kind == .connecting {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Anmeldung läuft …")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.card)
                }
                if integration.canDisconnect {
                    Button(role: .destructive) {
                        Task { await integration.disconnect() }
                    } label: {
                        Label("Trennen", systemImage: "person.badge.minus")
                    }
                    .listRowBackground(Theme.card)
                }
                if let hint = integration.disconnectHint {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        Button("iOS-Einstellungen öffnen") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                    .listRowBackground(Theme.card)
                }
                if integration.status.kind == .notConfigured {
                    Text("Ohne Einrichtung funktionieren URL-Eingabe, Prompt-Erstellung und Kopieren trotzdem vollständig.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .listRowBackground(Theme.card)
                }
            } header: {
                Text("Verbindung")
            }

            Section {
                Text(integration.accessDescription)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .listRowBackground(Theme.card)
                availabilityRow
                    .listRowBackground(Theme.card)
            } header: {
                Text("Zugriff & Suche")
            }

            Section {
                ForEach(Array(integration.setupInstructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.footnote.monospacedDigit().weight(.bold))
                            .foregroundStyle(Theme.blurple)
                        Text(step)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.card)
                }
            } header: {
                Text("Einrichtung (Entwickler)")
            } footer: {
                Text("Details und benötigte Redirect-URLs stehen in der README des Projekts. Die App enthält keine Client Secrets.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(integration.provider.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await integration.refreshStatus() }
    }

    @ViewBuilder
    private var availabilityRow: some View {
        switch integration.searchAvailability {
        case .available(let source):
            Label("Suche verfügbar – Quelle: \(source)", systemImage: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(Theme.spotifyGreen)
        case .unavailable(let reason):
            Label(reason, systemImage: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
