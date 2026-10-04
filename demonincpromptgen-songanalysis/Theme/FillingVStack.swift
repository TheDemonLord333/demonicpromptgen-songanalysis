import SwiftUI

/// Markiert die Unteransicht, die den verbleibenden Platz in `FillingVStack` erhält.
nonisolated struct FillsRemainingSpaceKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    func fillsRemainingSpace() -> some View {
        layoutValue(key: FillsRemainingSpaceKey.self, value: true)
    }
}

/// Vertikales Layout für scrollbare Bildschirme: Ist genug Platz vorhanden, erhält die markierte
/// Unteransicht den gesamten Restplatz bis `minimumHeight`. Reicht der Platz nicht (kleine Displays,
/// große Schrift, Tastatur), behält sie ihre Mindesthöhe und der Inhalt wird scrollbar.
/// Keine starren Bildschirmkoordinaten.
struct FillingVStack: Layout {
    var minimumHeight: CGFloat

    struct Measurement {
        var heights: [CGFloat]
        var fixedTotal: CGFloat
        var flexibleMinimum: CGFloat
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let measurement = measure(width: width, subviews: subviews)
        let needed = measurement.fixedTotal + measurement.flexibleMinimum
        return CGSize(width: width, height: max(minimumHeight, needed))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let measurement = measure(width: bounds.width, subviews: subviews)
        let flexibleHeight = max(measurement.flexibleMinimum, bounds.height - measurement.fixedTotal)
        var y = bounds.minY
        for (index, subview) in subviews.enumerated() {
            let height = subview[FillsRemainingSpaceKey.self] ? flexibleHeight : measurement.heights[index]
            subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: height)
            )
            y += height
        }
    }

    private func measure(width: CGFloat, subviews: Subviews) -> Measurement {
        var heights: [CGFloat] = []
        var fixed: CGFloat = 0
        var flexibleMinimum: CGFloat = 0
        for subview in subviews {
            if subview[FillsRemainingSpaceKey.self] {
                // Mindesthöhe der flexiblen Ansicht (z. B. über `frame(minHeight:)` festgelegt).
                let minimum = subview.sizeThatFits(ProposedViewSize(width: width, height: 0)).height
                flexibleMinimum += minimum
                heights.append(minimum)
            } else {
                let height = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
                fixed += height
                heights.append(height)
            }
        }
        return Measurement(heights: heights, fixedTotal: fixed, flexibleMinimum: flexibleMinimum)
    }
}
