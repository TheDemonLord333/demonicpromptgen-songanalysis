import SwiftUI

/// Hauptansicht nach Skizze: Kopf (1, 2), Songauswahl (3–6), Prompt (7–9), Generieren (10).
struct MainView: View {
    @Bindable var viewModel: MainViewModel
    let dependencies: AppDependencies

    @State private var isSettingsPresented = false
    @State private var isPickerPresented = false
    @State private var focusFieldAfterPicker = false
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                FillingVStack(minimumHeight: proxy.size.height) {
                    HeaderView { isSettingsPresented = true }
                        .padding(.top, 12)

                    // Angenehmer, aber anpassungsfähiger Abstand statt starrer Höhe aus der Skizze.
                    SectionHeader(title: "Song auswählen")
                        .padding(.top, headerGap(for: proxy.size.height))

                    SongInputRow(viewModel: viewModel, isFocused: $isURLFieldFocused) {
                        isURLFieldFocused = false
                        isPickerPresented = true
                    }
                    .padding(.top, Theme.Spacing.item)

                    SongCardView(state: viewModel.metadataState)
                        .padding(.top, 12)

                    SectionHeader(title: "Generierter Prompt")
                        .padding(.top, Theme.Spacing.section)

                    PromptCardView(
                        prompt: viewModel.generatedPrompt,
                        isStale: viewModel.isPromptStale,
                        canCopy: viewModel.canCopy,
                        showsCopyConfirmation: viewModel.showsCopyConfirmation,
                        onCopy: viewModel.copyPrompt
                    )
                    .padding(.top, Theme.Spacing.item)
                    .fillsRemainingSpace()

                    GenerateButton(isEnabled: viewModel.canGenerate) {
                        isURLFieldFocused = false
                        viewModel.generatePrompt()
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(DemonicBackground().ignoresSafeArea())
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: dependencies.settingsViewModel)
        }
        .sheet(isPresented: $isPickerPresented, onDismiss: {
            if focusFieldAfterPicker {
                focusFieldAfterPicker = false
                isURLFieldFocused = true
            }
        }) {
            SongPickerView(
                viewModel: dependencies.pickerViewModel,
                onSelect: { song in viewModel.select(song) },
                onManualEntry: { focusFieldAfterPicker = true }
            )
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.generateFeedbackTrigger)
        .sensoryFeedback(.success, trigger: viewModel.copyFeedbackTrigger)
        .sensoryFeedback(.selection, trigger: viewModel.selectionFeedbackTrigger)
        .onChange(of: viewModel.copyFeedbackTrigger) {
            AccessibilityNotification.Announcement("Prompt kopiert").post()
        }
    }

    private func headerGap(for height: CGFloat) -> CGFloat {
        min(max(height * 0.05, 16), 44)
    }
}

#if DEBUG
#Preview("Leer") {
    let dependencies = AppDependencies.preview()
    return MainView(viewModel: dependencies.mainViewModel, dependencies: dependencies)
}

#Preview("Song mit Prompt") {
    let dependencies = AppDependencies.preview()
    dependencies.mainViewModel.select(PreviewData.spotifySong)
    dependencies.mainViewModel.generatePrompt()
    return MainView(viewModel: dependencies.mainViewModel, dependencies: dependencies)
}

#Preview("Prompt veraltet") {
    let dependencies = AppDependencies.preview()
    dependencies.mainViewModel.select(PreviewData.spotifySong)
    dependencies.mainViewModel.generatePrompt()
    dependencies.mainViewModel.select(PreviewData.youtubeVideo)
    return MainView(viewModel: dependencies.mainViewModel, dependencies: dependencies)
}

#Preview("Ungültiger Link, große Schrift") {
    let dependencies = AppDependencies.preview()
    dependencies.mainViewModel.urlText = "https://example.com/song"
    return MainView(viewModel: dependencies.mainViewModel, dependencies: dependencies)
        .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
