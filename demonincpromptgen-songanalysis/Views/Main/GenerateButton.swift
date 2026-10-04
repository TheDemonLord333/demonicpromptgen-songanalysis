import SwiftUI

/// Element 10: Hauptaktion über die gesamte Breite.
struct GenerateButton: View {
    let isEnabled: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 56

    var body: some View {
        Button(action: action) {
            Label("Prompt generieren", systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: height)
                .padding(.horizontal, 12)
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(!isEnabled)
        .accessibilityHint(isEnabled ? "Erstellt den Analyse-Prompt aus dem Song-Link." : "Füge zuerst einen gültigen Song-Link ein.")
        .accessibilityIdentifier("generatePromptButton")
    }
}

#Preview {
    VStack(spacing: 16) {
        GenerateButton(isEnabled: true, action: {})
        GenerateButton(isEnabled: false, action: {})
    }
    .padding()
    .background(Theme.background)
}
