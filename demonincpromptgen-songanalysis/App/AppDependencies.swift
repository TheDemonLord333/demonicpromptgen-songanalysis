import Foundation

/// Erstellt und verbindet Dienste und ViewModels (einfache Dependency Injection).
@MainActor
final class AppDependencies {
    let settings: AppSettings
    let spotify: OAuthProviderIntegration
    let youtube: OAuthProviderIntegration
    let appleMusic: AppleMusicIntegration
    let mainViewModel: MainViewModel
    let pickerViewModel: SongPickerViewModel
    let settingsViewModel: SettingsViewModel

    var integrations: [any ProviderIntegration] { [spotify, youtube, appleMusic] }

    init(
        configuration: ProviderConfiguration = ProviderConfiguration(infoDictionary: Bundle.main.infoDictionary),
        tokenStore: any TokenStoring = KeychainTokenStore(),
        defaults: UserDefaults = .standard,
        http: any HTTPDataLoading = URLSessionHTTPClient(),
        metadataService: (any SongMetadataFetching)? = nil,
        pasteboard: (any PasteboardWriting)? = nil
    ) {
        let settings = AppSettings(defaults: defaults)
        let authenticator = WebAuthenticator()

        let spotify = OAuthProviderIntegration(
            provider: .spotify,
            config: configuration.spotifyOAuth,
            tokenStore: tokenStore,
            http: http,
            authenticator: authenticator,
            accessDescription: "Benutzeranmeldung bei Spotify (OAuth 2.0 mit PKCE, ohne Client Secret). Es werden keine zusätzlichen Berechtigungen (Scopes) angefragt – die App greift nicht auf deine persönliche Mediathek oder Playlists zu. Das Token dient nur der Songsuche und dem Abruf von Titel, Künstler und Cover über die Spotify Web API.",
            setupInstructions: [
                "Im Spotify Developer Dashboard eine App anlegen (API: Web API).",
                "Redirect-URI eintragen: demonicpromptgen://spotify-callback (oder eigenen Wert in SPOTIFY_REDIRECT_URI).",
                "Client-ID in Config/Providers.local.xcconfig als SPOTIFY_CLIENT_ID eintragen. Kein Client Secret verwenden.",
                "Im Development Mode muss der App-Inhaber Spotify Premium haben; Testnutzer im Dashboard freischalten. Die Suche liefert dort maximal 10 Treffer.",
                "Ohne Einrichtung: Metadaten über das öffentliche Spotify-oEmbed (Titel und Cover, kein Künstler).",
            ],
            notConfiguredDetail: "Keine Spotify-Client-ID hinterlegt. Metadaten kommen ohne Anmeldung über das öffentliche oEmbed (Titel und Cover).",
            disconnectHint: nil,
            search: { [http] query, token in
                try await SpotifyWebAPI(http: http).search(query, accessToken: token)
            }
        )

        let youtube = OAuthProviderIntegration(
            provider: .youtube,
            config: configuration.youtubeOAuth,
            tokenStore: tokenStore,
            http: http,
            authenticator: authenticator,
            accessDescription: "Google-Anmeldung (OAuth 2.0 mit PKCE) mit dem Scope „youtube.readonly“. Der Scope erlaubt Lesezugriff auf dein YouTube-Konto; die App nutzt ihn ausschließlich für die Videosuche über die YouTube Data API. YouTube liefert Video- und Kanalnamen, keine gesicherte Künstlerzuordnung.",
            setupInstructions: [
                "In der Google Cloud Console ein Projekt anlegen und die „YouTube Data API v3“ aktivieren.",
                "OAuth-Zustimmungsbildschirm konfigurieren und den Scope youtube.readonly hinzufügen (im Testmodus Testnutzer eintragen).",
                "OAuth-Client vom Typ „iOS“ mit der Bundle-ID der App anlegen.",
                "Client-ID (…apps.googleusercontent.com) in Config/Providers.local.xcconfig als GOOGLE_IOS_CLIENT_ID eintragen. Die Redirect-URL leitet die App automatisch aus der umgekehrten Client-ID ab.",
                "Ohne Einrichtung: Metadaten über das öffentliche YouTube-oEmbed (Videotitel, Kanal, Vorschaubild).",
            ],
            notConfiguredDetail: "Keine Google-iOS-Client-ID hinterlegt. Metadaten kommen ohne Anmeldung über das öffentliche oEmbed (Videotitel und Kanal).",
            disconnectHint: nil,
            search: { [http] query, token in
                try await YouTubeDataAPI(http: http).search(query, accessToken: token)
            }
        )

        let appleMusic = AppleMusicIntegration(http: http)

        let service = metadataService ?? SongMetadataService(
            http: http,
            resolver: ShortLinkResolver(prober: URLSessionRedirectProber()),
            spotifyAccessToken: { [weak spotify] in
                await spotify?.accessTokenIfConnected()
            }
        )

        self.settings = settings
        self.spotify = spotify
        self.youtube = youtube
        self.appleMusic = appleMusic
        self.mainViewModel = MainViewModel(
            settings: settings,
            metadataService: service,
            pasteboard: pasteboard ?? SystemPasteboard()
        )
        self.pickerViewModel = SongPickerViewModel(
            integrations: [spotify, youtube, appleMusic],
            initialProvider: .appleMusic
        )
        self.settingsViewModel = SettingsViewModel(
            settings: settings,
            integrations: [spotify, youtube, appleMusic]
        )
    }
}
