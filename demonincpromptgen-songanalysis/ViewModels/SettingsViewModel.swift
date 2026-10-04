import Foundation
import Observation

/// ViewModel der Einstellungen: Prompt-Konfiguration, Anbieter, Allgemeines.
@MainActor
@Observable
final class SettingsViewModel {
    let settings: AppSettings
    let integrations: [any ProviderIntegration]

    /// Entwurf der eigenen Vorlage. Wird nur übernommen, wenn er gültig ist.
    var customTemplateDraft: String {
        didSet {
            guard customTemplateDraft != oldValue else { return }
            commitCustomTemplateIfValid()
        }
    }

    private(set) var customTemplateError: CustomTemplateError?
    /// Hinweis, wenn eine Kategorie nicht abgewählt werden darf.
    private(set) var categoryHint: String?

    @ObservationIgnored let appVersion: String

    static let examplePreviewURL = "https://open.spotify.com/track/…"

    init(settings: AppSettings, integrations: [any ProviderIntegration], bundle: Bundle = .main) {
        self.settings = settings
        self.integrations = integrations
        self.customTemplateDraft = settings.promptConfiguration.customTemplate
        self.appVersion = Self.versionString(from: bundle.infoDictionary)
    }

    var configuration: PromptConfiguration { settings.promptConfiguration }

    var mode: PromptMode {
        get { settings.promptConfiguration.mode }
        set { settings.promptConfiguration.mode = newValue }
    }

    var includeOnlineToolsHint: Bool {
        get { settings.promptConfiguration.includeOnlineToolsHint }
        set { settings.promptConfiguration.includeOnlineToolsHint = newValue }
    }

    var onlineToolsHintApplies: Bool {
        settings.promptConfiguration.audioCategories.contains { $0.supportsOnlineToolsHint }
    }

    var rememberLastSongURL: Bool {
        get { settings.rememberLastSongURL }
        set { settings.rememberLastSongURL = newValue }
    }

    var isDefaultConfiguration: Bool {
        settings.promptConfiguration == .default && customTemplateDraft == PromptConfiguration.default.customTemplate
    }

    /// Vorschau des Prompts mit Beispiel-URL.
    var previewText: String {
        PromptBuilder.build(songURL: Self.examplePreviewURL, configuration: settings.promptConfiguration)
    }

    // MARK: Kategorien

    func isEnabled(_ category: LyricsCategory) -> Bool {
        settings.promptConfiguration.lyricsCategories.contains(category)
    }

    func isEnabled(_ category: AudioCategory) -> Bool {
        settings.promptConfiguration.audioCategories.contains(category)
    }

    /// `false`, wenn es die letzte aktive Kategorie ist (mindestens eine muss aktiv bleiben).
    func canToggleOff(_ category: LyricsCategory) -> Bool {
        !(isEnabled(category) && activeCategoryCount == 1)
    }

    func canToggleOff(_ category: AudioCategory) -> Bool {
        !(isEnabled(category) && activeCategoryCount == 1)
    }

    func set(_ category: LyricsCategory, enabled: Bool) {
        var configuration = settings.promptConfiguration
        if enabled {
            configuration.lyricsCategories.insert(category)
        } else {
            guard canToggleOff(category) else {
                categoryHint = Self.lastCategoryHint
                return
            }
            configuration.lyricsCategories.remove(category)
        }
        categoryHint = nil
        settings.promptConfiguration = configuration
    }

    func set(_ category: AudioCategory, enabled: Bool) {
        var configuration = settings.promptConfiguration
        if enabled {
            configuration.audioCategories.insert(category)
        } else {
            guard canToggleOff(category) else {
                categoryHint = Self.lastCategoryHint
                return
            }
            configuration.audioCategories.remove(category)
        }
        categoryHint = nil
        settings.promptConfiguration = configuration
    }

    static let lastCategoryHint = "Mindestens eine Analysekategorie muss aktiv bleiben."

    private var activeCategoryCount: Int {
        settings.promptConfiguration.lyricsCategories.count + settings.promptConfiguration.audioCategories.count
    }

    // MARK: Eigene Vorlage

    func insertPlaceholder() {
        if customTemplateDraft.isEmpty || customTemplateDraft.hasSuffix("\n") {
            customTemplateDraft += PromptConfiguration.songURLPlaceholder
        } else {
            customTemplateDraft += "\n" + PromptConfiguration.songURLPlaceholder
        }
    }

    private func commitCustomTemplateIfValid() {
        customTemplateError = PromptBuilder.validateCustomTemplate(customTemplateDraft)
        guard customTemplateError == nil else { return }
        settings.promptConfiguration.customTemplate = customTemplateDraft
    }

    // MARK: Zurücksetzen

    func restoreDefaults() {
        settings.promptConfiguration = .default
        customTemplateDraft = PromptConfiguration.default.customTemplate
        customTemplateError = nil
        categoryHint = nil
    }

    // MARK: Anbieter

    func refreshStatuses() async {
        for integration in integrations {
            await integration.refreshStatus()
        }
    }

    static func versionString(from info: [String: Any]?) -> String {
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}
