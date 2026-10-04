import Foundation

/// Prüfstatus der URL-Eingabe.
nonisolated enum LinkInputState: Equatable, Sendable {
    case empty
    case invalid(SongLinkError)
    case valid(SongLink)

    var link: SongLink? {
        if case .valid(let link) = self { return link }
        return nil
    }

    var errorMessage: String? {
        if case .invalid(let error) = self { return error.message }
        return nil
    }
}

/// Zustand der Songkarte.
nonisolated enum MetadataState: Equatable, Sendable {
    /// Noch keine Auswahl.
    case idle
    /// Metadaten werden geladen.
    case loading(SongLink)
    /// Metadaten verfügbar.
    case loaded(SongInfo)
    /// Metadaten nicht verfügbar – der Link bleibt trotzdem verwendbar.
    case unavailable(SongLink, message: String)
}

/// Zustand der Songsuche im Auswahl-Sheet.
nonisolated enum SearchState: Equatable, Sendable {
    case idle
    case searching
    case results([SongInfo])
    case noResults
    case failed(String)
}

/// Ein erzeugter Prompt samt der Eingaben, aus denen er entstanden ist.
nonisolated struct GeneratedPrompt: Equatable, Sendable {
    let text: String
    /// Normalisierte Eingabe-URL zum Zeitpunkt der Generierung (für die Veraltet-Prüfung).
    let sourceLinkURL: URL
    let configuration: PromptConfiguration
}
