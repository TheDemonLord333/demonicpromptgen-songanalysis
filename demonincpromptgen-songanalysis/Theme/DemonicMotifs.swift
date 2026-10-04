import SwiftUI

/// Zwei geschwungene Hörner – das dezente dämonische Markenzeichen.
nonisolated struct HornsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Linkes Horn
        path.move(to: CGPoint(x: rect.minX + w * 0.30, y: rect.minY + h))
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.02, y: rect.minY),
            control1: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.85),
            control2: CGPoint(x: rect.minX - w * 0.04, y: rect.minY + h * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.44, y: rect.minY + h * 0.88),
            control1: CGPoint(x: rect.minX + w * 0.14, y: rect.minY + h * 0.40),
            control2: CGPoint(x: rect.minX + w * 0.30, y: rect.minY + h * 0.70)
        )
        path.closeSubpath()

        // Rechtes Horn (gespiegelt)
        path.move(to: CGPoint(x: rect.maxX - w * 0.30, y: rect.minY + h))
        path.addCurve(
            to: CGPoint(x: rect.maxX - w * 0.02, y: rect.minY),
            control1: CGPoint(x: rect.maxX - w * 0.05, y: rect.minY + h * 0.85),
            control2: CGPoint(x: rect.maxX + w * 0.04, y: rect.minY + h * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - w * 0.44, y: rect.minY + h * 0.88),
            control1: CGPoint(x: rect.maxX - w * 0.14, y: rect.minY + h * 0.40),
            control2: CGPoint(x: rect.maxX - w * 0.30, y: rect.minY + h * 0.70)
        )
        path.closeSubpath()
        return path
    }
}

/// Schlichte, gezeichnete Rune (Algiz-ähnlich) als dekoratives Element.
nonisolated struct RuneShape: Shape {
    var variant: Int = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))
        switch variant % 3 {
        case 0:
            path.move(to: CGPoint(x: midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.move(to: CGPoint(x: midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case 1:
            path.move(to: CGPoint(x: midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3))
            path.addLine(to: CGPoint(x: midX, y: rect.midY))
        default:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.6))
        }
        return path
    }
}

/// Abschnittsüberschrift mit feiner Linie und kleinen Runen.
struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            LinearGradient(colors: [Theme.blurple.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    RuneShape(variant: index)
                        .stroke(Theme.textSecondary.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                        .frame(width: 7, height: 11)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

/// Statischer Hintergrund: dunkle Fläche mit sehr schwachen Lichthöfen an den Rändern.
struct DemonicBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.blurple.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 360
            )
            RadialGradient(
                colors: [Theme.spotifyGreen.opacity(0.08), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 420
            )
        }
        .accessibilityHidden(true)
    }
}
