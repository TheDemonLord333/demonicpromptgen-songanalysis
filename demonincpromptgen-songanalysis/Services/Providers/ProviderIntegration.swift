import Foundation

/// Ob und womit eine Songsuche gerade möglich ist.
nonisolated enum SearchAvailability: Equatable, Sendable {
    /// Suche möglich; `source` beschreibt die tatsächlich genutzte Datenquelle.
    case available(source: String)
    /// Suche nicht möglich; `reason` erklärt den tatsächlichen Grund.
    case unavailable(reason: String)
}

/// Gemeinsame Schnittstelle der Anbieterintegrationen (Spotify, YouTube, Apple Music).
///
/// Integrationen dienen nur der Songauswahl und dem Abruf verfügbarer Metadaten –
/// sie führen keine Audioanalyse durch.
@MainActor
protocol ProviderIntegration: AnyObject {
    var provider: MusicProvider { get }
    /// Tatsächlicher Verbindungs- bzw. Konfigurationsstatus.
    var status: ProviderStatus { get }
    var searchAvailability: SearchAvailability { get }
    var canConnect: Bool { get }
    var canDisconnect: Bool { get }
    /// Hinweis, falls Trennen technisch nicht in der App möglich ist.
    var disconnectHint: String? { get }
    /// Was die Anmeldung erlaubt (Benutzeranmeldung / Mediathek / nur Suche).
    var accessDescription: String { get }
    /// Was Entwickler einrichten müssen.
    var setupInstructions: [String] { get }

    func refreshStatus() async
    func connect() async
    func disconnect() async
    func search(_ query: String) async throws -> [SongInfo]
}
