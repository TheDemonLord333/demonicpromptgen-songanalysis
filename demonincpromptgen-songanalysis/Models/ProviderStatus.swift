import Foundation

/// Tatsächlicher Verbindungs- bzw. Konfigurationsstatus einer Anbieterintegration.
nonisolated struct ProviderStatus: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Entwicklerkonfiguration fehlt (z. B. keine Client-ID hinterlegt).
        case notConfigured
        /// Konfiguriert, aber kein Benutzer angemeldet bzw. keine Berechtigung.
        case disconnected
        /// Anmeldung läuft.
        case connecting
        /// Angemeldet bzw. berechtigt.
        case connected
        /// Handlungsbedarf, z. B. abgelaufene Anmeldung oder verweigerter Zugriff.
        case needsAttention
    }

    let kind: Kind
    let title: String
    let detail: String?

    init(_ kind: Kind, title: String, detail: String? = nil) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }

    static func notConfigured(_ detail: String? = nil) -> ProviderStatus {
        ProviderStatus(.notConfigured, title: "Noch nicht eingerichtet", detail: detail)
    }
}
