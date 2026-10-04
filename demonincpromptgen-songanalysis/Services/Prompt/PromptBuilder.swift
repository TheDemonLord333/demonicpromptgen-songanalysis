import Foundation

/// Fehler bei der Prüfung einer benutzerdefinierten Vorlage.
nonisolated enum CustomTemplateError: Error, Equatable, Sendable {
    case empty
    case missingPlaceholder

    var message: String {
        switch self {
        case .empty:
            "Die Vorlage darf nicht leer sein."
        case .missingPlaceholder:
            "Die Vorlage muss den Platzhalter \(PromptConfiguration.songURLPlaceholder) enthalten."
        }
    }
}

/// Deterministische, lokale Prompt-Erstellung. Keine Netzwerkzugriffe, keine KI.
nonisolated enum PromptBuilder {
    static let introLine = "Analysiere mir dieses Lied:"
    static let lyricsHeading = "Lyrics:"
    static let audioHeading = "Audio:"

    /// Vorbelegung für den benutzerdefinierten Modus – entspricht der Standardvorlage.
    static let defaultCustomTemplate = """
    Analysiere mir dieses Lied:
    {songURL}
    Lyrics:
    Thema, Wortwahl, Reimart, Struktur
    Audio:
    BPM, Akkorde, Style of Music, Genre
    Nutze für BPM, Akkorde wenn es nirgendswo zu finden ist online tools
    """

    /// Erstellt den Prompt für eine Song-URL.
    ///
    /// Mit `PromptConfiguration.default` entspricht das Ergebnis exakt der Standardvorlage.
    static func build(songURL: String, configuration: PromptConfiguration) -> String {
        switch configuration.mode {
        case .custom:
            return configuration.customTemplate.replacingOccurrences(
                of: PromptConfiguration.songURLPlaceholder,
                with: songURL
            )
        case .standard:
            return buildStandard(songURL: songURL, configuration: configuration)
        }
    }

    /// Prüft eine benutzerdefinierte Vorlage. Gibt `nil` zurück, wenn sie gültig ist.
    static func validateCustomTemplate(_ template: String) -> CustomTemplateError? {
        if template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .empty
        }
        if !template.contains(PromptConfiguration.songURLPlaceholder) {
            return .missingPlaceholder
        }
        return nil
    }

    private static func buildStandard(songURL: String, configuration: PromptConfiguration) -> String {
        var lines = [introLine, songURL]

        // Reihenfolge folgt immer der Standardvorlage, unabhängig von der Auswahlreihenfolge.
        let lyrics = LyricsCategory.allCases.filter(configuration.lyricsCategories.contains)
        if !lyrics.isEmpty {
            lines.append(lyricsHeading)
            lines.append(lyrics.map(\.displayName).joined(separator: ", "))
        }

        let audio = AudioCategory.allCases.filter(configuration.audioCategories.contains)
        if !audio.isEmpty {
            lines.append(audioHeading)
            lines.append(audio.map(\.displayName).joined(separator: ", "))
        }

        let hintCategories = audio.filter(\.supportsOnlineToolsHint)
        if configuration.includeOnlineToolsHint, !hintCategories.isEmpty {
            let names = hintCategories.map(\.displayName).joined(separator: ", ")
            lines.append("Nutze für \(names) wenn es nirgendswo zu finden ist online tools")
        }

        return lines.joined(separator: "\n")
    }
}
