import Foundation

nonisolated enum PromptMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case standard
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: "Standardvorlage"
        case .custom: "Eigene Vorlage"
        }
    }
}

nonisolated enum LyricsCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case theme
    case wording
    case rhymeScheme
    case structure

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .theme: "Thema"
        case .wording: "Wortwahl"
        case .rhymeScheme: "Reimart"
        case .structure: "Struktur"
        }
    }
}

nonisolated enum AudioCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case bpm
    case chords
    case styleOfMusic
    case genre

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bpm: "BPM"
        case .chords: "Akkorde"
        case .styleOfMusic: "Style of Music"
        case .genre: "Genre"
        }
    }

    /// Kategorien, für die der Online-Tools-Hinweis gilt.
    var supportsOnlineToolsHint: Bool {
        self == .bpm || self == .chords
    }
}

/// Lokal gespeicherte Konfiguration der Prompt-Erstellung.
nonisolated struct PromptConfiguration: Codable, Equatable, Sendable {
    static let songURLPlaceholder = "{songURL}"

    var mode: PromptMode
    var lyricsCategories: Set<LyricsCategory>
    var audioCategories: Set<AudioCategory>
    var includeOnlineToolsHint: Bool
    var customTemplate: String

    init(
        mode: PromptMode = .standard,
        lyricsCategories: Set<LyricsCategory> = Set(LyricsCategory.allCases),
        audioCategories: Set<AudioCategory> = Set(AudioCategory.allCases),
        includeOnlineToolsHint: Bool = true,
        customTemplate: String = PromptBuilder.defaultCustomTemplate
    ) {
        self.mode = mode
        self.lyricsCategories = lyricsCategories
        self.audioCategories = audioCategories
        self.includeOnlineToolsHint = includeOnlineToolsHint
        self.customTemplate = customTemplate
    }

    static let `default` = PromptConfiguration()

    var hasAnyCategory: Bool {
        !lyricsCategories.isEmpty || !audioCategories.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case mode, lyricsCategories, audioCategories, includeOnlineToolsHint, customTemplate
    }

    /// Tolerantes Dekodieren: Fehlende oder ungültige Werte fallen auf den Standard zurück.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = PromptConfiguration.default
        mode = (try? container.decodeIfPresent(PromptMode.self, forKey: .mode)) ?? fallback.mode
        lyricsCategories = (try? container.decodeIfPresent(Set<LyricsCategory>.self, forKey: .lyricsCategories)) ?? fallback.lyricsCategories
        audioCategories = (try? container.decodeIfPresent(Set<AudioCategory>.self, forKey: .audioCategories)) ?? fallback.audioCategories
        includeOnlineToolsHint = (try? container.decodeIfPresent(Bool.self, forKey: .includeOnlineToolsHint)) ?? fallback.includeOnlineToolsHint
        let template = (try? container.decodeIfPresent(String.self, forKey: .customTemplate)) ?? nil
        if let template, PromptBuilder.validateCustomTemplate(template) == nil {
            customTemplate = template
        } else {
            customTemplate = fallback.customTemplate
        }
        if !hasAnyCategory {
            lyricsCategories = fallback.lyricsCategories
            audioCategories = fallback.audioCategories
        }
    }
}
