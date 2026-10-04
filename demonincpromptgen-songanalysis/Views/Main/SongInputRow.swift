import SwiftUI

/// Element 4 (URL-Eingabefeld) und Element 5 (Songauswahl rechts daneben).
struct SongInputRow: View {
    @Bindable var viewModel: MainViewModel
    var isFocused: FocusState<Bool>.Binding
    let onPickSong: () -> Void

    @ScaledMetric(relativeTo: .body) private var controlHeight: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                inputField
                pickerButton
            }
            if let message = viewModel.validationMessage {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("validationMessage")
            }
        }
    }

    private var inputField: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)

            TextField(
                "Song-Link",
                text: $viewModel.urlText,
                prompt: Text("Song-Link einfügen …").foregroundStyle(Theme.textSecondary)
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.URL)
            .submitLabel(.done)
            .focused(isFocused)
            .onSubmit { viewModel.submit() }
            .foregroundStyle(Theme.textPrimary)
            .tint(Theme.spotifyGreen)
            .accessibilityIdentifier("songURLField")

            if !viewModel.urlText.isEmpty {
                Button {
                    viewModel.clearInput()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minWidth: 32, minHeight: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Eingabe löschen")
            }

            PasteButton(payloadType: String.self) { strings in
                Task { @MainActor in
                    viewModel.paste(strings)
                }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
            .tint(Theme.blurple)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: controlHeight)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isFocused.wrappedValue ? 1.5 : 1)
        )
    }

    private var pickerButton: some View {
        Button(action: onPickSong) {
            Image(systemName: "music.note.list")
                .font(.title3.weight(.semibold))
                .frame(width: controlHeight, height: controlHeight)
        }
        .buttonStyle(IconButtonStyle(tint: Theme.blurple))
        .accessibilityLabel("Song auswählen")
        .accessibilityIdentifier("songPickerButton")
    }

    private var borderColor: Color {
        switch viewModel.linkState {
        case .invalid: Theme.danger.opacity(0.8)
        case .valid: Theme.spotifyGreen.opacity(0.6)
        case .empty: isFocused.wrappedValue ? Theme.blurple.opacity(0.8) : Theme.blurple.opacity(0.3)
        }
    }
}
