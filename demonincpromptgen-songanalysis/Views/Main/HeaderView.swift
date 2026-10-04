import SwiftUI

/// Element 1 (App-Name oben links) und Element 2 (Einstellungen oben rechts).
struct HeaderView: View {
    static let appTitle = "Demonic Prompt Gen - Songanalyse"

    let onOpenSettings: () -> Void
    @ScaledMetric(relativeTo: .title) private var hornWidth: CGFloat = 30

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HornsShape()
                .fill(Theme.hornGradient)
                .frame(width: hornWidth, height: hornWidth * 0.7)
                .shadow(color: Theme.blurple.opacity(0.45), radius: 6)
                .padding(.top, 6)
                .accessibilityHidden(true)

            Text(Self.appTitle)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(IconButtonStyle(tint: Theme.blurple))
            .accessibilityLabel("Einstellungen")
            .accessibilityIdentifier("settingsButton")
        }
    }
}

#Preview {
    HeaderView(onOpenSettings: {})
        .padding()
        .background(Theme.background)
}
