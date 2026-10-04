import SwiftUI

/// Cover mit Lade- und Fehlerplatzhalter. Lädt nur bereits geprüfte Cover-URLs.
struct ArtworkView: View {
    let url: URL?
    var size: CGFloat = 64
    var isLoading = false

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder(loading: false, failed: true)
                    case .empty:
                        placeholder(loading: true, failed: false)
                    @unknown default:
                        placeholder(loading: false, failed: false)
                    }
                }
            } else {
                placeholder(loading: isLoading, failed: false)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .strokeBorder(Theme.blurple.opacity(0.35), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private func placeholder(loading: Bool, failed: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: [Theme.elevated, Theme.blurple.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if loading {
                ProgressView()
                    .tint(Theme.textSecondary)
            } else {
                VStack(spacing: 2) {
                    HornsShape()
                        .fill(Theme.hornGradient)
                        .frame(width: size * 0.34, height: size * 0.16)
                        .opacity(0.7)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .foregroundStyle(failed ? Theme.textSecondary.opacity(0.5) : Theme.textSecondary)
                }
            }
        }
    }
}

/// Kleines Anbieter-Badge.
struct ProviderBadge: View {
    let provider: MusicProvider

    var body: some View {
        Label(provider.displayName, systemImage: provider.symbolName)
            .font(.caption2.weight(.bold))
            .foregroundStyle(provider.badgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(provider.badgeColor.opacity(0.14)))
            .overlay(Capsule().strokeBorder(provider.badgeColor.opacity(0.45), lineWidth: 1))
            .accessibilityLabel("Anbieter: \(provider.displayName)")
    }
}
