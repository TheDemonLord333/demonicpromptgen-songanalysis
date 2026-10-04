import SwiftUI

/// Einstellungen: Konten & Anbieter, Prompt-Konfiguration, Allgemein, Datenschutz.
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isResetConfirmationPresented = false

    var body: some View {
        NavigationStack {
            Form {
                providersSection
                promptModeSection
                if viewModel.mode == .standard {
                    standardTemplateSections
                } else {
                    customTemplateSection
                }
                previewSection
                resetSection
                generalSection
                privacySection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.card, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("settingsDoneButton")
                }
            }
            .task { await viewModel.refreshStatuses() }
            .confirmationDialog(
                "Prompt-Einstellungen auf den Standard zurücksetzen?",
                isPresented: $isResetConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Standard wiederherstellen", role: .destructive) {
                    viewModel.restoreDefaults()
                }
            }
        }
        .tint(Theme.blurple)
        .preferredColorScheme(.dark)
    }

    // MARK: Konten und Anbieter

    private var providersSection: some View {
        Section {
            ForEach(viewModel.integrations, id: \.provider) { integration in
                NavigationLink {
                    ProviderDetailView(integration: integration)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: integration.provider.symbolName)
                            .foregroundStyle(integration.provider.badgeColor)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(integration.provider.displayName)
                                .foregroundStyle(Theme.textPrimary)
                            Text(integration.status.title)
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(Theme.card)
            }
        } header: {
            Text("Konten & Anbieter")
        } footer: {
            Text("Anbindungen dienen nur der Songauswahl und dem Abruf verfügbarer Metadaten. Sie führen keine Audioanalyse durch.")
        }
    }

    // MARK: Prompt

    private var promptModeSection: some View {
        Section {
            Picker("Modus", selection: $viewModel.mode) {
                ForEach(PromptMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Theme.card)
        } header: {
            Text("Prompt-Konfiguration")
        } footer: {
            Text(viewModel.mode == .standard
                 ? "Die Analysekategorien bestimmen den Inhalt. Ohne Änderungen entspricht der Prompt exakt der Standardvorlage."
                 : "Dein eigener Text wird verwendet; \(PromptConfiguration.songURLPlaceholder) wird durch den Song-Link ersetzt. Analysekategorien gelten in diesem Modus nicht.")
        }
    }

    @ViewBuilder
    private var standardTemplateSections: some View {
        Section {
            ForEach(LyricsCategory.allCases) { category in
                Toggle(category.displayName, isOn: Binding(
                    get: { viewModel.isEnabled(category) },
                    set: { viewModel.set(category, enabled: $0) }
                ))
                .disabled(!viewModel.canToggleOff(category))
                .listRowBackground(Theme.card)
            }
        } header: {
            Text("Lyrics")
        }

        Section {
            ForEach(AudioCategory.allCases) { category in
                Toggle(category.displayName, isOn: Binding(
                    get: { viewModel.isEnabled(category) },
                    set: { viewModel.set(category, enabled: $0) }
                ))
                .disabled(!viewModel.canToggleOff(category))
                .listRowBackground(Theme.card)
            }
        } header: {
            Text("Audio")
        } footer: {
            Text(viewModel.categoryHint ?? SettingsViewModel.lastCategoryHint)
        }

        Section {
            Toggle("Online-Tools-Hinweis", isOn: $viewModel.includeOnlineToolsHint)
                .disabled(!viewModel.onlineToolsHintApplies)
                .listRowBackground(Theme.card)
        } footer: {
            Text(viewModel.onlineToolsHintApplies
                 ? "Ergänzt: „Nutze für BPM, Akkorde wenn es nirgendswo zu finden ist online tools“ (nur aktive Kategorien)."
                 : "Gilt nur, wenn BPM oder Akkorde aktiv sind.")
        }
    }

    private var customTemplateSection: some View {
        Section {
            TextEditor(text: $viewModel.customTemplateDraft)
                .font(.body.monospaced())
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Eigene Vorlage")
                .listRowBackground(Theme.elevated)
            Button {
                viewModel.insertPlaceholder()
            } label: {
                Label("Platzhalter \(PromptConfiguration.songURLPlaceholder) einfügen", systemImage: "plus.square.on.square")
            }
            .listRowBackground(Theme.card)
        } header: {
            Text("Eigene Vorlage")
        } footer: {
            if let error = viewModel.customTemplateError {
                Label(error.message + " Bis dahin bleibt die zuletzt gültige Vorlage gespeichert.", systemImage: "exclamationmark.circle")
                    .foregroundStyle(Theme.danger)
            } else {
                Text("Gespeichert. \(PromptConfiguration.songURLPlaceholder) wird durch den Song-Link ersetzt.")
            }
        }
    }

    private var previewSection: some View {
        Section {
            Text(viewModel.previewText)
                .font(.footnote.monospaced())
                .foregroundStyle(Theme.textSecondary)
                .textSelection(.enabled)
                .listRowBackground(Theme.card)
        } header: {
            Text("Vorschau")
        }
    }

    private var resetSection: some View {
        Section {
            Button("Standard wiederherstellen", role: .destructive) {
                isResetConfirmationPresented = true
            }
            .disabled(viewModel.isDefaultConfiguration)
            .listRowBackground(Theme.card)
        }
    }

    // MARK: Allgemein

    private var generalSection: some View {
        Section {
            Toggle("Letzte Song-URL merken", isOn: $viewModel.rememberLastSongURL)
                .listRowBackground(Theme.card)
            LabeledContent("App-Version", value: viewModel.appVersion)
                .listRowBackground(Theme.card)
        } header: {
            Text("Allgemein")
        } footer: {
            Text("Wenn aktiv, wird der zuletzt eingegebene gültige Song-Link lokal gespeichert und beim nächsten Start wieder eingesetzt.")
        }
    }

    private var privacySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Lokal auf diesem Gerät gespeichert: Prompt-Einstellungen und – nur wenn aktiviert – der letzte Song-Link (UserDefaults). Anmelde-Tokens von Spotify und Google liegen verschlüsselt in der iOS-Keychain.")
                Text("Der Prompt wird lokal erstellt. Die App sendet ihn nirgendwohin und führt keine KI-Analyse durch.")
                Text("Für Metadaten und Suche fragt die App ausschließlich die Anbieter direkt an: Spotify (oEmbed bzw. Web API), YouTube (oEmbed bzw. Data API), Apple (iTunes Search/Lookup bzw. MusicKit). Dabei werden der Song-Link bzw. dein Suchbegriff übertragen. Cover werden von den Bildservern der Anbieter geladen. Es gibt keine Analyse- oder Werbedienste.")
            }
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
            .listRowBackground(Theme.card)
        } header: {
            Text("Datenschutz")
        }
    }
}

#if DEBUG
#Preview("Einstellungen") {
    let dependencies = AppDependencies.preview()
    return SettingsView(viewModel: dependencies.settingsViewModel)
}
#endif
