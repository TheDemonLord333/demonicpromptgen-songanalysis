import SwiftUI

/// Element 8 (große Prompt-Karte) mit Element 9 (Kopieren unten rechts innerhalb der Karte).
struct PromptCardView: View {
    let prompt: GeneratedPrompt?
    let isStale: Bool
    let canCopy: Bool
    let showsCopyConfirmation: Bool
    let onCopy: () -> Void

    static let minimumHeight: CGFloat = 220

    @ScaledMetric(relativeTo: .body) private var copyButtonSize: CGFloat = 46
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isStale {
                staleNotice
            }
            ScrollView {
                promptText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    // Platz für den Kopierbutton, damit er keinen Text verdeckt.
                    .padding(.bottom, copyButtonSize + 16)
            }
            .scrollIndicators(.visible)
        }
        .frame(maxWidth: .infinity, minHeight: Self.minimumHeight, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottomTrailing) {
            copyButton
                .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .demonCard(tint: isStale ? Theme.warning : Theme.spotifyGreen, glow: prompt != nil && !isStale)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isStale)
    }

    @ViewBuilder
    private var promptText: some View {
        if let prompt {
            Text(prompt.text)
                .font(.body)
                .foregroundStyle(isStale ? Theme.textSecondary : Theme.textPrimary)
                .textSelection(.enabled)
                .lineSpacing(3)
                .accessibilityLabel(isStale ? "Veralteter Prompt: \(prompt.text)" : prompt.text)
                .accessibilityIdentifier("promptText")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "text.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Theme.blurple)
                    .accessibilityHidden(true)
                Text("Hier erscheint dein Analyse-Prompt.")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Füge oben einen Song-Link von Spotify, YouTube oder Apple Music ein oder wähle einen Song aus und tippe auf „Prompt generieren“. Metadaten oder eine Anmeldung sind dafür nicht nötig.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("promptPlaceholder")
        }
    }

    private var staleNotice: some View {
        Label {
            Text("Song-Link oder Prompt-Einstellungen wurden geändert. Tippe auf „Prompt generieren“, um den Prompt zu aktualisieren.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "arrow.triangle.2.circlepath")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.warning)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warning.opacity(0.12))
        .accessibilityIdentifier("staleNotice")
    }

    private var copyButton: some View {
        Button(action: onCopy) {
            HStack(spacing: 6) {
                Image(systemName: showsCopyConfirmation ? "checkmark" : "doc.on.doc")
                    .font(.body.weight(.semibold))
                if showsCopyConfirmation {
                    Text("Kopiert")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, showsCopyConfirmation ? 14 : 0)
            .frame(minWidth: copyButtonSize, minHeight: copyButtonSize)
        }
        .buttonStyle(IconButtonStyle(tint: showsCopyConfirmation ? Theme.spotifyGreen : Theme.blurple))
        .disabled(!canCopy)
        .accessibilityLabel("Prompt kopieren")
        .accessibilityValue(showsCopyConfirmation ? "Kopiert" : "")
        .accessibilityHint(canCopy ? "" : "Erst verfügbar, wenn ein aktueller Prompt generiert wurde.")
        .accessibilityIdentifier("copyPromptButton")
    }
}

#if DEBUG
#Preview("Prompt-Karte – Zustände") {
    VStack(spacing: 16) {
        PromptCardView(prompt: nil, isStale: false, canCopy: false, showsCopyConfirmation: false, onCopy: {})
        PromptCardView(prompt: PreviewData.prompt, isStale: false, canCopy: true, showsCopyConfirmation: true, onCopy: {})
        PromptCardView(prompt: PreviewData.prompt, isStale: true, canCopy: false, showsCopyConfirmation: false, onCopy: {})
    }
    .padding()
    .background(Theme.background)
}
#endif
