import Foundation
import Testing
@testable import demonincpromptgen_songanalysis

@MainActor
struct MainViewModelTests {
    private func song(_ link: String, title: String) throws -> SongInfo {
        let parsed = try parsedLink(link)
        return SongInfo(
            id: try #require(parsed.songID),
            provider: parsed.provider,
            url: parsed.url,
            title: title,
            artist: "Künstler",
            artworkURL: nil
        )
    }

    private func makeViewModel(
        service: any SongMetadataFetching,
        settings: AppSettings? = nil,
        pasteboard: RecordingPasteboard? = nil
    ) -> MainViewModel {
        MainViewModel(
            settings: settings ?? makeSettings(),
            metadataService: service,
            pasteboard: pasteboard ?? RecordingPasteboard(),
            debounceInterval: .zero,
            copyConfirmationDuration: .milliseconds(30)
        )
    }

    // MARK: Generierung

    @Test func generatesDefaultPromptWithoutMetadata() {
        let viewModel = makeViewModel(service: StaticMetadataService(result: .failure(.httpStatus(404))))
        #expect(!viewModel.canGenerate)
        viewModel.urlText = TestLinks.spotify + "?si=tracking"
        #expect(viewModel.canGenerate)

        viewModel.generatePrompt()
        #expect(viewModel.generatedPrompt?.text == PromptBuilder.build(songURL: TestLinks.spotify, configuration: .default))
        #expect(viewModel.canCopy)
    }

    @Test func invalidLinkDisablesGenerationAndShowsMessage() {
        let viewModel = makeViewModel(service: StaticMetadataService(result: .failure(.httpStatus(404))))
        viewModel.urlText = "https://example.com/song"
        #expect(!viewModel.canGenerate)
        #expect(viewModel.validationMessage == SongLinkError.unsupportedHost.message)
        viewModel.generatePrompt()
        #expect(viewModel.generatedPrompt == nil)
    }

    @Test func unavailableMetadataKeepsLinkUsable() async {
        let viewModel = makeViewModel(service: StaticMetadataService(result: .failure(.httpStatus(404))))
        viewModel.urlText = TestLinks.youtube
        let becameUnavailable = await eventually {
            if case .unavailable = viewModel.metadataState { return true }
            return false
        }
        #expect(becameUnavailable)
        #expect(viewModel.canGenerate)
        viewModel.generatePrompt()
        #expect(viewModel.generatedPrompt?.text.contains(TestLinks.youtube) == true)
    }

    // MARK: Veraltete Ausgabe

    @Test func changingURLMarksPromptStaleAndDisablesCopy() {
        let pasteboard = RecordingPasteboard()
        let viewModel = makeViewModel(service: StaticMetadataService(result: .failure(.httpStatus(404))), pasteboard: pasteboard)
        viewModel.urlText = TestLinks.spotify
        viewModel.generatePrompt()
        #expect(!viewModel.isPromptStale)

        viewModel.urlText = TestLinks.spotifyOther
        #expect(viewModel.isPromptStale)
        #expect(!viewModel.canCopy)
        viewModel.copyPrompt()
        #expect(pasteboard.copied.isEmpty)

        viewModel.generatePrompt()
        #expect(!viewModel.isPromptStale)
        #expect(viewModel.generatedPrompt?.text.contains(TestLinks.spotifyOther) == true)
    }

    @Test func removingOnlyTrackingParametersDoesNotMarkStale() {
        let viewModel = makeViewModel(service: StaticMetadataService(result: .failure(.httpStatus(404))))
        viewModel.urlText = TestLinks.spotify
        viewModel.generatePrompt()
        viewModel.urlText = TestLinks.spotify + "?si=neu"
        #expect(!viewModel.isPromptStale)
    }

    @Test func changingConfigurationMarksPromptStale() {
        let settings = makeSettings()
        let viewModel = makeViewModel(service: StaticMetadataService(result: .failure(.httpStatus(404))), settings: settings)
        viewModel.urlText = TestLinks.spotify
        viewModel.generatePrompt()

        settings.promptConfiguration.includeOnlineToolsHint = false
        #expect(viewModel.isPromptStale)
        #expect(!viewModel.canCopy)

        settings.promptConfiguration.includeOnlineToolsHint = true
        #expect(!viewModel.isPromptStale)
    }

    @Test func clearingInputMarksPromptStale() {
        let viewModel = makeViewModel(service: StaticMetadataService(result: .failure(.httpStatus(404))))
        viewModel.urlText = TestLinks.spotify
        viewModel.generatePrompt()
        viewModel.clearInput()
        #expect(viewModel.isPromptStale)
        #expect(!viewModel.canCopy)
        #expect(viewModel.metadataState == .idle)
    }

    // MARK: Kopieren

    @Test func copyWritesFullPromptAndShowsConfirmation() async {
        let pasteboard = RecordingPasteboard()
        let viewModel = makeViewModel(service: StaticMetadataService(result: .failure(.httpStatus(404))), pasteboard: pasteboard)
        viewModel.urlText = TestLinks.apple
        viewModel.generatePrompt()
        viewModel.copyPrompt()

        #expect(pasteboard.copied == [viewModel.generatedPrompt?.text ?? "-"])
        #expect(viewModel.showsCopyConfirmation)
        #expect(viewModel.copyFeedbackTrigger == 1)

        let hidden = await eventually { !viewModel.showsCopyConfirmation }
        #expect(hidden)
    }

    @Test func regeneratingResetsCopyConfirmation() {
        let viewModel = makeViewModel(service: StaticMetadataService(result: .failure(.httpStatus(404))))
        viewModel.urlText = TestLinks.spotify
        viewModel.generatePrompt()
        viewModel.copyPrompt()
        #expect(viewModel.showsCopyConfirmation)
        viewModel.generatePrompt()
        #expect(!viewModel.showsCopyConfirmation)
        #expect(viewModel.canCopy)
    }

    // MARK: Metadaten

    @Test func olderMetadataResponseDoesNotOverwriteNewerSelection() async throws {
        let service = ControlledMetadataService()
        let viewModel = makeViewModel(service: service)
        let first = try parsedLink(TestLinks.spotify)
        let second = try parsedLink(TestLinks.spotifyOther)

        viewModel.urlText = TestLinks.spotify
        await service.waitForRequest(first.url)
        viewModel.urlText = TestLinks.spotifyOther
        await service.waitForRequest(second.url)

        // Neuere Antwort zuerst, danach die verspätete ältere.
        await service.complete(second.url, with: try song(TestLinks.spotifyOther, title: "Neu"))
        let loadedNew = await eventually {
            if case .loaded(let song) = viewModel.metadataState { return song.title == "Neu" }
            return false
        }
        #expect(loadedNew)

        await service.complete(first.url, with: try song(TestLinks.spotify, title: "Alt"))
        try await Task.sleep(for: .milliseconds(30))
        guard case .loaded(let current) = viewModel.metadataState else {
            Issue.record("Erwartet: geladene Metadaten")
            return
        }
        #expect(current.title == "Neu")
    }

    @Test func lateResponseAfterClearingIsIgnored() async throws {
        let service = ControlledMetadataService()
        let viewModel = makeViewModel(service: service)
        let link = try parsedLink(TestLinks.youtube)

        viewModel.urlText = TestLinks.youtube
        await service.waitForRequest(link.url)
        viewModel.clearInput()
        await service.complete(link.url, with: try song(TestLinks.youtube, title: "Zu spät"))
        try await Task.sleep(for: .milliseconds(30))
        #expect(viewModel.metadataState == .idle)
    }

    @Test func pickerSelectionUsesKnownMetadataAndCancelsFetch() async throws {
        let service = ControlledMetadataService()
        let viewModel = makeViewModel(service: service)
        let selected = try song(TestLinks.spotify, title: "Ausgewählt")

        viewModel.select(selected)
        #expect(viewModel.metadataState == .loaded(selected))
        #expect(viewModel.selectionFeedbackTrigger == 1)

        // Eine eventuell gestartete Anfrage darf die Auswahl nicht überschreiben.
        await service.complete(selected.url, with: try song(TestLinks.spotify, title: "Überschrieben"))
        try await Task.sleep(for: .milliseconds(30))
        #expect(viewModel.metadataState == .loaded(selected))
    }

    @Test func resolvedShortLinkURLIsUsedInPrompt() async throws {
        let resolved = try song(TestLinks.spotify, title: "Titel")
        let viewModel = makeViewModel(service: StaticMetadataService(result: .success(resolved)))
        viewModel.urlText = "https://spotify.link/AbCdEf123"
        let loaded = await eventually {
            if case .loaded = viewModel.metadataState { return true }
            return false
        }
        #expect(loaded)
        viewModel.generatePrompt()
        #expect(viewModel.generatedPrompt?.text.contains(TestLinks.spotify) == true)
    }

    // MARK: Letzte URL merken

    @Test func remembersLastURLOnlyWhenEnabled() {
        let settings = makeSettings()
        let viewModel = makeViewModel(service: StaticMetadataService(result: .failure(.httpStatus(404))), settings: settings)
        viewModel.urlText = TestLinks.spotify
        #expect(settings.lastSongURL == nil)

        settings.rememberLastSongURL = true
        viewModel.urlText = TestLinks.youtube
        #expect(settings.lastSongURL == TestLinks.youtube)

        settings.rememberLastSongURL = false
        #expect(settings.lastSongURL == nil)
    }
}
