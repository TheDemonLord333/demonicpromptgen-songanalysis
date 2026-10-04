import Foundation
import Testing
@testable import demonincpromptgen_songanalysis

struct PromptBuilderTests {
    private let url = "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC"

    @Test func defaultPromptMatchesTemplateExactly() {
        let expected = """
        Analysiere mir dieses Lied:
        https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC
        Lyrics:
        Thema, Wortwahl, Reimart, Struktur
        Audio:
        BPM, Akkorde, Style of Music, Genre
        Nutze für BPM, Akkorde wenn es nirgendswo zu finden ist online tools
        """
        #expect(PromptBuilder.build(songURL: url, configuration: .default) == expected)
    }

    @Test func defaultPromptIsDeterministic() {
        let first = PromptBuilder.build(songURL: url, configuration: .default)
        let second = PromptBuilder.build(songURL: url, configuration: .default)
        #expect(first == second)
    }

    @Test func customTemplateReplacesEveryPlaceholder() {
        var configuration = PromptConfiguration.default
        configuration.mode = .custom
        configuration.customTemplate = "Song: {songURL}\nNochmal: {songURL}"
        #expect(PromptBuilder.build(songURL: url, configuration: configuration) == "Song: \(url)\nNochmal: \(url)")
    }

    @Test func customModeIgnoresCategorySelection() {
        var configuration = PromptConfiguration.default
        configuration.mode = .custom
        configuration.customTemplate = "Nur {songURL}"
        configuration.lyricsCategories = []
        #expect(PromptBuilder.build(songURL: url, configuration: configuration) == "Nur \(url)")
    }

    @Test func defaultCustomTemplateEqualsStandardOutput() {
        var configuration = PromptConfiguration.default
        configuration.mode = .custom
        #expect(PromptBuilder.build(songURL: url, configuration: configuration)
            == PromptBuilder.build(songURL: url, configuration: .default))
    }

    @Test func categorySelectionKeepsTemplateOrder() {
        var configuration = PromptConfiguration.default
        configuration.lyricsCategories = [.structure, .theme]
        configuration.audioCategories = [.genre, .chords]
        let expected = """
        Analysiere mir dieses Lied:
        \(url)
        Lyrics:
        Thema, Struktur
        Audio:
        Akkorde, Genre
        Nutze für Akkorde wenn es nirgendswo zu finden ist online tools
        """
        #expect(PromptBuilder.build(songURL: url, configuration: configuration) == expected)
    }

    @Test func emptyLyricsSectionIsOmitted() {
        var configuration = PromptConfiguration.default
        configuration.lyricsCategories = []
        let prompt = PromptBuilder.build(songURL: url, configuration: configuration)
        #expect(!prompt.contains("Lyrics:"))
        #expect(prompt.contains("Audio:\nBPM, Akkorde, Style of Music, Genre"))
    }

    @Test func onlineToolsHintCanBeDisabled() {
        var configuration = PromptConfiguration.default
        configuration.includeOnlineToolsHint = false
        let prompt = PromptBuilder.build(songURL: url, configuration: configuration)
        #expect(!prompt.contains("online tools"))
        #expect(prompt.hasSuffix("BPM, Akkorde, Style of Music, Genre"))
    }

    @Test func onlineToolsHintOmittedWithoutBPMOrChords() {
        var configuration = PromptConfiguration.default
        configuration.audioCategories = [.genre]
        let prompt = PromptBuilder.build(songURL: url, configuration: configuration)
        #expect(!prompt.contains("online tools"))
    }

    @Test func customTemplateValidation() {
        #expect(PromptBuilder.validateCustomTemplate("Analysiere {songURL}") == nil)
        #expect(PromptBuilder.validateCustomTemplate("Analysiere den Song") == .missingPlaceholder)
        #expect(PromptBuilder.validateCustomTemplate("   \n ") == .empty)
        #expect(PromptBuilder.validateCustomTemplate("{songurl}") == .missingPlaceholder)
    }

    @Test func decodingRejectsInvalidStoredTemplate() throws {
        let json = #"{"mode":"custom","customTemplate":"ohne Platzhalter","lyricsCategories":[],"audioCategories":[]}"#
        let configuration = try JSONDecoder().decode(PromptConfiguration.self, from: Data(json.utf8))
        #expect(configuration.customTemplate == PromptBuilder.defaultCustomTemplate)
        #expect(configuration.hasAnyCategory)
        #expect(configuration.mode == .custom)
    }
}