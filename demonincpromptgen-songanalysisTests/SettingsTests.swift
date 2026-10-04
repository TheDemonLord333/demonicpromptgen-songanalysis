import Foundation
import Testing
@testable import demonincpromptgen_songanalysis

@MainActor
struct SettingsTests {
    @Test func settingsPersistAcrossInstances() {
        let suite = "tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        settings.promptConfiguration.audioCategories = [.bpm]
        settings.promptConfiguration.mode = .custom
        settings.rememberLastSongURL = true
        settings.recordSongURL(TestLinks.spotify)

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.promptConfiguration.audioCategories == [.bpm])
        #expect(reloaded.promptConfiguration.mode == .custom)
        #expect(reloaded.rememberLastSongURL)
        #expect(reloaded.lastSongURL == TestLinks.spotify)
    }

    @Test func invalidCustomTemplateIsNotSaved() {
        let settings = makeSettings()
        let viewModel = SettingsViewModel(settings: settings, integrations: [])
        viewModel.mode = .custom

        viewModel.customTemplateDraft = "Analysiere {songURL} bitte"
        #expect(viewModel.customTemplateError == nil)
        #expect(settings.promptConfiguration.customTemplate == "Analysiere {songURL} bitte")

        viewModel.customTemplateDraft = "Analysiere ohne Platzhalter"
        #expect(viewModel.customTemplateError == .missingPlaceholder)
        #expect(settings.promptConfiguration.customTemplate == "Analysiere {songURL} bitte")
    }

    @Test func insertPlaceholderFixesTemplate() {
        let viewModel = SettingsViewModel(settings: makeSettings(), integrations: [])
        viewModel.customTemplateDraft = "Mein Prompt"
        #expect(viewModel.customTemplateError == .missingPlaceholder)
        viewModel.insertPlaceholder()
        #expect(viewModel.customTemplateDraft == "Mein Prompt\n{songURL}")
        #expect(viewModel.customTemplateError == nil)
    }

    @Test func lastActiveCategoryCannotBeDisabled() {
        let settings = makeSettings()
        let viewModel = SettingsViewModel(settings: settings, integrations: [])
        for category in LyricsCategory.allCases { viewModel.set(category, enabled: false) }
        for category in AudioCategory.allCases where category != .genre { viewModel.set(category, enabled: false) }

        #expect(settings.promptConfiguration.audioCategories == [.genre])
        #expect(!viewModel.canToggleOff(AudioCategory.genre))
        viewModel.set(AudioCategory.genre, enabled: false)
        #expect(settings.promptConfiguration.audioCategories == [.genre])
        #expect(viewModel.categoryHint == SettingsViewModel.lastCategoryHint)

        viewModel.set(LyricsCategory.theme, enabled: true)
        #expect(viewModel.categoryHint == nil)
        #expect(viewModel.canToggleOff(AudioCategory.genre))
    }

    @Test func categorySelectionChangesPreview() {
        let viewModel = SettingsViewModel(settings: makeSettings(), integrations: [])
        viewModel.set(LyricsCategory.rhymeScheme, enabled: false)
        #expect(viewModel.previewText.contains("Thema, Wortwahl, Struktur"))
    }

    @Test func restoreDefaultsResetsEverything() {
        let settings = makeSettings()
        let viewModel = SettingsViewModel(settings: settings, integrations: [])
        viewModel.mode = .custom
        viewModel.customTemplateDraft = "kaputt"
        viewModel.includeOnlineToolsHint = false
        viewModel.restoreDefaults()

        #expect(settings.promptConfiguration == .default)
        #expect(viewModel.customTemplateDraft == PromptBuilder.defaultCustomTemplate)
        #expect(viewModel.customTemplateError == nil)
        #expect(viewModel.isDefaultConfiguration)
    }

    @Test func versionString() {
        #expect(SettingsViewModel.versionString(from: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "7"]) == "1.0 (7)")
    }
}
