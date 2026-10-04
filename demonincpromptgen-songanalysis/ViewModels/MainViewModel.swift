import Foundation
import Observation

/// ViewModel der Hauptansicht: URL-Eingabe, Metadaten, Prompt-Erstellung und Kopieren.
@MainActor
@Observable
final class MainViewModel {
    /// Rohtext des URL-Eingabefelds.
    var urlText: String = "" {
        didSet {
            guard urlText != oldValue else { return }
            handleInputChange()
        }
    }

    private(set) var linkState: LinkInputState = .empty
    private(set) var metadataState: MetadataState = .idle
    private(set) var generatedPrompt: GeneratedPrompt?
    /// Kurze Bestätigung nach dem Kopieren.
    private(set) var showsCopyConfirmation = false

    // Zähler als Auslöser für dezente Haptik (`sensoryFeedback`).
    private(set) var generateFeedbackTrigger = 0
    private(set) var copyFeedbackTrigger = 0
    private(set) var selectionFeedbackTrigger = 0

    let settings: AppSettings

    @ObservationIgnored private let metadataService: any SongMetadataFetching
    @ObservationIgnored private let pasteboard: any PasteboardWriting
    @ObservationIgnored private let debounceInterval: Duration
    @ObservationIgnored private let copyConfirmationDuration: Duration
    @ObservationIgnored private var metadataTask: Task<Void, Never>?
    @ObservationIgnored private var copyConfirmationTask: Task<Void, Never>?
    /// Wird bei jeder Auswahländerung erhöht. Antworten mit älterer Generation werden verworfen.
    @ObservationIgnored private(set) var metadataGeneration = 0
    /// Aufgelöste URL (z. B. nach Kurzlink-Auflösung) für die aktuelle Eingabe.
    @ObservationIgnored private var resolvedURL: URL?
    /// `true`, solange eine entprellte Anfrage noch nicht gestartet wurde.
    @ObservationIgnored private var isDebouncing = false

    init(
        settings: AppSettings,
        metadataService: any SongMetadataFetching,
        pasteboard: any PasteboardWriting,
        debounceInterval: Duration = .milliseconds(600),
        copyConfirmationDuration: Duration = .seconds(1.6)
    ) {
        self.settings = settings
        self.metadataService = metadataService
        self.pasteboard = pasteboard
        self.debounceInterval = debounceInterval
        self.copyConfirmationDuration = copyConfirmationDuration
        if let last = settings.lastSongURL, settings.rememberLastSongURL {
            urlText = last
            handleInputChange()
        }
    }

    // MARK: Abgeleitete Zustände

    var currentLink: SongLink? { linkState.link }

    var validationMessage: String? { linkState.errorMessage }

    var canGenerate: Bool { currentLink != nil }

    /// `true`, wenn sich Song-Link oder Prompt-Konfiguration seit der Generierung geändert haben.
    var isPromptStale: Bool {
        guard let generatedPrompt else { return false }
        return generatedPrompt.sourceLinkURL != currentLink?.url
            || generatedPrompt.configuration != settings.promptConfiguration
    }

    var canCopy: Bool {
        generatedPrompt != nil && !isPromptStale
    }

    /// URL, die in den Prompt eingesetzt wird: aufgelöste URL, sonst die normalisierte Eingabe.
    var promptSongURL: URL? {
        guard let link = currentLink else { return nil }
        if case .loaded(let song) = metadataState, metadataMatches(song: song, link: link) {
            return song.url
        }
        return resolvedURL ?? link.url
    }

    // MARK: Aktionen

    /// Bestätigung im Eingabefeld: Metadaten sofort (ohne Entprellung) abrufen.
    func submit() {
        guard let link = currentLink, isDebouncing else { return }
        if case .loading(let loadingLink) = metadataState, loadingLink == link {
            startMetadataFetch(for: link, debounce: false)
        }
    }

    /// Einfügen über `PasteButton`.
    func paste(_ strings: [String]) {
        guard let text = strings.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return
        }
        urlText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        submit()
    }

    func clearInput() {
        urlText = ""
    }

    /// Übernahme eines Songs aus dem Auswahl-Sheet (inkl. bereits bekannter Metadaten).
    func select(_ song: SongInfo) {
        selectionFeedbackTrigger += 1
        urlText = song.url.absoluteString
        guard let link = currentLink, link.songID == song.id else { return }
        // Laufende Anfrage abbrechen; die bekannten Metadaten gelten für genau diesen Link.
        cancelMetadataFetch()
        resolvedURL = song.url
        metadataState = song.hasMetadata
            ? .loaded(song)
            : .unavailable(link, message: MetadataError.noMetadata.message)
    }

    /// Erstellt den Prompt lokal und deterministisch – ohne künstliche Ladezeit.
    func generatePrompt() {
        guard let link = currentLink, let songURL = promptSongURL else { return }
        let configuration = settings.promptConfiguration
        let text = PromptBuilder.build(songURL: songURL.absoluteString, configuration: configuration)
        generatedPrompt = GeneratedPrompt(text: text, sourceLinkURL: link.url, configuration: configuration)
        hideCopyConfirmation()
        generateFeedbackTrigger += 1
    }

    /// Kopiert den vollständigen, aktuellen Prompt.
    func copyPrompt() {
        guard canCopy, let generatedPrompt else { return }
        pasteboard.copy(generatedPrompt.text)
        copyFeedbackTrigger += 1
        showsCopyConfirmation = true

        copyConfirmationTask?.cancel()
        let duration = copyConfirmationDuration
        copyConfirmationTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.showsCopyConfirmation = false
        }
    }

    // MARK: Interne Logik

    private func handleInputChange() {
        let newState: LinkInputState
        switch SongLinkParser.parse(urlText) {
        case .success(let link): newState = .valid(link)
        case .failure(.empty): newState = .empty
        case .failure(let error): newState = .invalid(error)
        }

        let previousLink = linkState.link
        linkState = newState
        hideCopyConfirmation()

        guard let link = newState.link else {
            cancelMetadataFetch()
            resolvedURL = nil
            metadataState = .idle
            if case .empty = newState { settings.recordSongURL(nil) }
            return
        }

        settings.recordSongURL(link.url.absoluteString)
        // Gleicher normalisierter Link (z. B. nur Trackingparameter entfernt): nichts neu laden.
        guard link != previousLink else { return }

        resolvedURL = nil
        startMetadataFetch(for: link, debounce: true)
    }

    private func startMetadataFetch(for link: SongLink, debounce: Bool) {
        cancelMetadataFetch()
        let generation = metadataGeneration
        metadataState = .loading(link)
        isDebouncing = debounce && debounceInterval > .zero

        let service = metadataService
        let delay = debounceInterval
        metadataTask = Task { [weak self] in
            if debounce, delay > .zero {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.isDebouncing = false
            }
            let result: Result<SongInfo, Error>
            do {
                result = .success(try await service.metadata(for: link))
            } catch {
                result = .failure(error)
            }
            self?.applyMetadataResult(result, for: link, generation: generation)
        }
    }

    private func applyMetadataResult(_ result: Result<SongInfo, Error>, for link: SongLink, generation: Int) {
        // Schutz vor veralteten Antworten: nur die neueste Auswahl darf den Zustand setzen.
        guard generation == metadataGeneration, currentLink == link else { return }
        metadataTask = nil

        switch result {
        case .success(let song):
            resolvedURL = song.url
            metadataState = song.hasMetadata
                ? .loaded(song)
                : .unavailable(link, message: MetadataError.noMetadata.message)
        case .failure(let error):
            metadataState = .unavailable(link, message: Self.message(for: error))
        }
    }

    private func cancelMetadataFetch() {
        metadataTask?.cancel()
        metadataTask = nil
        isDebouncing = false
        metadataGeneration += 1
    }

    private func hideCopyConfirmation() {
        copyConfirmationTask?.cancel()
        copyConfirmationTask = nil
        showsCopyConfirmation = false
    }

    private func metadataMatches(song: SongInfo, link: SongLink) -> Bool {
        guard let songID = link.songID else {
            // Kurzlink: Metadaten wurden für genau diese Eingabe geladen.
            return song.provider == link.provider
        }
        return songID == song.id
    }

    private static func message(for error: Error) -> String {
        switch error {
        case let error as ShortLinkError: error.message
        case let error as MetadataError: error.message
        case let error as NetworkError where error == .httpStatus(404) || error == .httpStatus(400):
            "Der Anbieter kennt diesen Link nicht oder gibt keine Metadaten frei."
        case let error as NetworkError where error == .httpStatus(401) || error == .unauthorized || error == .httpStatus(403):
            "Der Anbieter gibt für diesen Link keine öffentlichen Metadaten frei."
        default: NetworkError.userMessage(for: error)
        }
    }
}
