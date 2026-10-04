import SwiftUI

/// Zentrale Design-Tokens: dunkel, dämonisch, Spotify-Grün und Discord-Lilablau.
enum Theme {
    // MARK: Farben

    static let background = Color(hex: 0x09090F)
    static let card = Color(hex: 0x15151F)
    static let elevated = Color(hex: 0x1E1E2D)
    static let spotifyGreen = Color(hex: 0x1DB954)
    static let blurple = Color(hex: 0x5865F2)
    static let textPrimary = Color(hex: 0xF5F5FA)
    static let textSecondary = Color(hex: 0xA6A6BA)

    // Ergänzende Statusfarben (Fehler, Hinweis).
    static let danger = Color(hex: 0xF2556B)
    static let warning = Color(hex: 0xF5B84B)

    /// Text auf grüner Hauptaktion (hoher Kontrast).
    static let onGreen = Color(hex: 0x09090F)

    static let actionGradient = LinearGradient(
        colors: [spotifyGreen, Color(hex: 0x1AA88A), blurple.opacity(0.9)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let hornGradient = LinearGradient(
        colors: [spotifyGreen, blurple],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    // MARK: Maße

    enum Radius {
        static let card: CGFloat = 20
        static let control: CGFloat = 14
    }

    enum Spacing {
        static let screen: CGFloat = 20
        static let section: CGFloat = 24
        static let item: CGFloat = 10
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension MusicProvider {
    var symbolName: String {
        switch self {
        case .spotify: "waveform"
        case .youtube: "play.rectangle.fill"
        case .appleMusic: "music.note"
        }
    }

    var badgeColor: Color {
        switch self {
        case .spotify: Theme.spotifyGreen
        case .youtube: Color(hex: 0xFF5A5A)
        case .appleMusic: Color(hex: 0xFC5C7D)
        }
    }
}

// MARK: Karten

struct DemonCardModifier: ViewModifier {
    var tint: Color
    var glow: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(tint.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: glow ? tint.opacity(0.18) : .clear, radius: 14, y: 0)
    }
}

extension View {
    /// Abgerundete Karte mit dezenter farbiger Kontur und optionalem Glow (nur außen, nie hinter Text).
    func demonCard(tint: Color = Theme.blurple, glow: Bool = false) -> some View {
        modifier(DemonCardModifier(tint: tint, glow: glow))
    }
}

// MARK: Button-Stile

/// Kompakter, runder Symbolbutton (Lilablau für Einstellungen und Songauswahl).
struct IconButtonStyle: ButtonStyle {
    var tint: Color = Theme.blurple

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, tint: tint)
    }

    private struct IconButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .foregroundStyle(isEnabled ? Theme.textPrimary : Theme.textSecondary.opacity(0.6))
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(configuration.isPressed ? tint.opacity(0.45) : tint.opacity(isEnabled ? 0.22 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(tint.opacity(isEnabled ? 0.7 : 0.2), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
    }
}

/// Hauptaktion in Spotify-Grün mit dezentem Grün-Lilablau-Verlauf.
struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryBody(configuration: configuration)
    }

    private struct PrimaryBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .foregroundStyle(isEnabled ? Theme.onGreen : Theme.textSecondary)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(isEnabled ? AnyShapeStyle(Theme.actionGradient) : AnyShapeStyle(Theme.elevated))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(isEnabled ? Theme.spotifyGreen.opacity(0.9) : Theme.textSecondary.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: isEnabled ? Theme.spotifyGreen.opacity(configuration.isPressed ? 0.15 : 0.35) : .clear, radius: 16, y: 4)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }
}
