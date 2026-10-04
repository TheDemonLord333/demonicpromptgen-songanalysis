import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import demonincpromptgen_songanalysis

struct ShortLinkResolverTests {
    @Test func resolvesSpotifyShortLinkViaAllowedHops() async throws {
        let prober = MapRedirectProber(map: [
            "https://spotify.link/AbC": "https://spotify.app.link/AbC?_p=1",
            "https://spotify.app.link/AbC?_p=1": "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?si=x",
        ])
        let resolved = try await ShortLinkResolver(prober: prober).resolve(try parsedLink("https://spotify.link/AbC"))
        #expect(resolved.reference == .spotifyTrack(id: "4uLU6hMCjMI75M1A2tKUQC"))
    }

    @Test func rejectsRedirectToForeignHost() async throws {
        let prober = MapRedirectProber(map: ["https://apple.co/xyz": "https://evil.example/music.apple.com"])
        await #expect(throws: ShortLinkError.foreignHost) {
            try await ShortLinkResolver(prober: prober).resolve(try parsedLink("https://apple.co/xyz"))
        }
    }

    @Test func rejectsRedirectToOtherProvider() async throws {
        let prober = MapRedirectProber(map: ["https://spoti.fi/x": "https://music.apple.com/de/song/x/1559523359"])
        await #expect(throws: ShortLinkError.foreignHost) {
            try await ShortLinkResolver(prober: prober).resolve(try parsedLink("https://spoti.fi/x"))
        }
    }

    @Test func stopsAfterMaximumRedirects() async throws {
        let prober = MapRedirectProber(map: [
            "https://spotify.link/a": "https://spotify.app.link/b",
            "https://spotify.app.link/b": "https://spotify.app.link/c",
            "https://spotify.app.link/c": "https://spotify.app.link/d",
            "https://spotify.app.link/d": "https://spotify.app.link/e",
            "https://spotify.app.link/e": "https://spotify.app.link/f",
            "https://spotify.app.link/f": "https://spotify.app.link/g",
        ])
        await #expect(throws: ShortLinkError.tooManyRedirects) {
            try await ShortLinkResolver(prober: prober).resolve(try parsedLink("https://spotify.link/a"))
        }
    }

    @Test func missingRedirectIsReported() async throws {
        await #expect(throws: ShortLinkError.notResolvable) {
            try await ShortLinkResolver(prober: MapRedirectProber(map: [:])).resolve(try parsedLink("https://apple.co/x"))
        }
    }

    @Test func redirectToNonSongIsRejected() async throws {
        let prober = MapRedirectProber(map: ["https://spotify.link/a": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M"])
        await #expect(throws: ShortLinkError.notASong) {
            try await ShortLinkResolver(prober: prober).resolve(try parsedLink("https://spotify.link/a"))
        }
    }
}

struct ProviderAPITests {
    @Test func youtubeOEmbedLabelsChannelNotArtist() throws {
        let link = try parsedLink(TestLinks.youtube)
        let response = OEmbedAPI.Response(title: "Offizielles Video", authorName: "Kanalname", thumbnailURL: "https://i.ytimg.com/vi/x/hq.jpg")
        let song = OEmbedAPI.songInfo(from: response, link: link, songID: try #require(link.songID))
        #expect(song.title == "Offizielles Video")
        #expect(song.artist == "Kanalname")
        #expect(song.provider.creatorLabel == "Kanal")
        #expect(song.artworkURL != nil)
    }

    @Test func spotifyOEmbedDoesNotInventArtist() throws {
        let link = try parsedLink(TestLinks.spotify)
        let response = OEmbedAPI.Response(title: "Songtitel", authorName: nil, thumbnailURL: "https://image-cdn-ak.spotifycdn.com/image/x")
        let song = OEmbedAPI.songInfo(from: response, link: link, songID: try #require(link.songID))
        #expect(song.title == "Songtitel")
        #expect(song.artist == nil)
    }

    @Test func untrustedArtworkHostIsDropped() throws {
        let link = try parsedLink(TestLinks.youtube)
        let response = OEmbedAPI.Response(title: "T", authorName: nil, thumbnailURL: "https://tracker.example/pixel.png")
        let song = OEmbedAPI.songInfo(from: response, link: link, songID: try #require(link.songID))
        #expect(song.artworkURL == nil)
    }

    @Test func iTunesSearchMapsSongs() throws {
        let json = """
        {"resultCount":2,"results":[
          {"wrapperType":"track","kind":"song","trackId":1559523359,"trackName":"Titel","artistName":"Künstler",
           "artworkUrl100":"https://is1-ssl.mzstatic.com/image/thumb/100x100bb.jpg",
           "trackViewUrl":"https://music.apple.com/de/album/titel/1559523357?i=1559523359&uo=4"},
          {"wrapperType":"track","kind":"music-video","trackId":1,"trackName":"Video","trackViewUrl":"https://music.apple.com/de/music-video/x/1"}
        ]}
        """
        let response = try JSONDecoder().decode(ITunesAPI.Response.self, from: Data(json.utf8))
        let songs = ITunesAPI.songs(from: response)
        #expect(songs.count == 1)
        #expect(songs.first?.id == "appleMusic:1559523359")
        #expect(songs.first?.url.absoluteString == "https://music.apple.com/de/album/titel/1559523357?i=1559523359")
        #expect(songs.first?.artist == "Künstler")
    }

    @Test func spotifyTrackMapping() throws {
        let json = """
        {"id":"4uLU6hMCjMI75M1A2tKUQC","name":"Titel","artists":[{"name":"A"},{"name":"B"}],
         "album":{"images":[{"url":"https://i.scdn.co/image/640","width":640},{"url":"https://i.scdn.co/image/300","width":300}]}}
        """
        let track = try JSONDecoder().decode(SpotifyWebAPI.Track.self, from: Data(json.utf8))
        let song = try #require(SpotifyWebAPI.songInfo(from: track))
        #expect(song.artist == "A, B")
        #expect(song.artworkURL?.absoluteString == "https://i.scdn.co/image/300")
        #expect(song.url.absoluteString == TestLinks.spotify)
    }

    @Test func spotifySearchURLRespectsLimit() throws {
        let url = try #require(SpotifyWebAPI.searchURL(query: "a & b"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first(where: { $0.name == "limit" })?.value == "10")
        #expect(items.first(where: { $0.name == "q" })?.value == "a & b")
    }

    @Test func youtubeSearchDecodesHTMLEntities() throws {
        let json = """
        {"items":[{"id":{"videoId":"dQw4w9WgXcQ"},"snippet":{"title":"Rock &amp; Roll &#39;Live&#39;","channelTitle":"Kanal &quot;X&quot;",
          "thumbnails":{"medium":{"url":"https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg"}}}},
          {"id":{"channelId":"abc"},"snippet":{"title":"Kanal"}}]}
        """
        let response = try JSONDecoder().decode(YouTubeDataAPI.SearchResponse.self, from: Data(json.utf8))
        let songs = YouTubeDataAPI.songs(from: response)
        #expect(songs.count == 1)
        #expect(songs.first?.title == "Rock & Roll 'Live'")
        #expect(songs.first?.artist == "Kanal \"X\"")
        #expect(HTMLEntities.decode("&amp;#39;") == "&#39;")
    }

    @Test func metadataServiceUsesOEmbedWithoutSpotifyLogin() async throws {
        let http = StubHTTPClient(stubs: [
            "/oembed": [.init(status: 200, body: #"{"title":"Songtitel","thumbnail_url":"https://i.scdn.co/image/abc"}"#)],
        ])
        let service = SongMetadataService(
            http: http,
            resolver: ShortLinkResolver(prober: MapRedirectProber(map: [:])),
            spotifyAccessToken: { nil }
        )
        let song = try await service.metadata(for: try parsedLink(TestLinks.spotify))
        #expect(song.title == "Songtitel")
        #expect(song.artist == nil)
        #expect(http.requests.first?.url?.host == "open.spotify.com")
    }

    @Test func metadataServiceUsesITunesLookupForAppleMusic() async throws {
        let http = StubHTTPClient(stubs: [
            "/lookup": [.init(status: 200, body: #"{"results":[{"kind":"song","trackId":1559523359,"trackName":"T","artistName":"K"}]}"#)],
        ])
        let service = SongMetadataService(
            http: http,
            resolver: ShortLinkResolver(prober: MapRedirectProber(map: [:])),
            spotifyAccessToken: { nil }
        )
        let song = try await service.metadata(for: try parsedLink(TestLinks.apple))
        #expect(song.title == "T")
        #expect(song.artist == "K")
        let query = http.requests.first?.url?.query ?? ""
        #expect(query.contains("id=1559523359"))
        #expect(query.contains("country=de"))
    }
}

struct OAuthTests {
    private let config = OAuthProviderConfig(
        authorizeEndpoint: testURL("https://accounts.spotify.com/authorize"),
        tokenEndpoint: testURL("https://accounts.spotify.com/api/token"),
        revokeEndpoint: nil,
        clientID: "client123",
        redirectURI: testURL("demonicpromptgen://spotify-callback"),
        scopes: [],
        additionalAuthorizeParameters: [:]
    )

    @Test func authorizationURLContainsPKCEParameters() throws {
        let url = try #require(OAuthRequestFactory.authorizationURL(config: config, codeChallenge: "challenge", state: "state1"))
        let items = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(items["code_challenge_method"] == "S256")
        #expect(items["code_challenge"] == "challenge")
        #expect(items["response_type"] == "code")
        #expect(items["redirect_uri"] == "demonicpromptgen://spotify-callback")
        #expect(items["client_secret"] == nil)
        #expect(config.callback == .customScheme("demonicpromptgen"))
    }

    @Test func tokenRequestIsFormEncodedWithoutSecret() throws {
        let request = OAuthRequestFactory.tokenRequest(config: config, code: "a b&c", codeVerifier: "verifier")
        let body = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
        #expect(request.httpMethod == "POST")
        #expect(body.contains("code=a%20b%26c"))
        #expect(body.contains("code_verifier=verifier"))
        #expect(!body.contains("secret"))
    }

    @Test func callbackParsingChecksState() throws {
        let ok = try #require(URL(string: "demonicpromptgen://spotify-callback?code=xyz&state=s1"))
        #expect(OAuthRequestFactory.authorizationCode(from: ok, expectedState: "s1") == .success("xyz"))
        #expect(OAuthRequestFactory.authorizationCode(from: ok, expectedState: "other") == .failure(.stateMismatch))
        let denied = try #require(URL(string: "demonicpromptgen://spotify-callback?error=access_denied&state=s1"))
        #expect(OAuthRequestFactory.authorizationCode(from: denied, expectedState: "s1") == .failure(.accessDenied))
    }

    @Test func tokenManagerRefreshesExpiredTokenOnce() async throws {
        let store = InMemoryTokenStore(tokens: [
            "spotify": OAuthToken(accessToken: "old", refreshToken: "refresh", expiresAt: Date(timeIntervalSinceNow: -10)),
        ])
        let http = StubHTTPClient(stubs: [
            "/api/token": [.init(status: 200, body: #"{"access_token":"new","expires_in":3600}"#)],
        ])
        let manager = OAuthTokenManager(config: config, store: store, http: http, account: "spotify")

        async let first = manager.validAccessToken()
        async let second = manager.validAccessToken()
        let tokens = try await [first, second]
        #expect(tokens == ["new", "new"])
        #expect(http.requestCount == 1)
        // Refresh-Token bleibt erhalten, wenn keines neu geliefert wird.
        #expect(try store.loadToken(account: "spotify")?.refreshToken == "refresh")
    }

    @Test func invalidRefreshTokenEndsSession() async throws {
        let store = InMemoryTokenStore(tokens: [
            "spotify": OAuthToken(accessToken: "old", refreshToken: "revoked", expiresAt: Date(timeIntervalSinceNow: -10)),
        ])
        let http = StubHTTPClient(stubs: ["/api/token": [.init(status: 400, body: #"{"error":"invalid_grant"}"#)]])
        let manager = OAuthTokenManager(config: config, store: store, http: http, account: "spotify")
        await #expect(throws: OAuthError.sessionExpired) { try await manager.validAccessToken() }
        #expect(try store.loadToken(account: "spotify") == nil)
        #expect(await manager.hasStoredToken() == false)
    }

    @Test func missingTokenMeansNotConnected() async {
        let manager = OAuthTokenManager(config: config, store: InMemoryTokenStore(), http: StubHTTPClient(stubs: [:]), account: "spotify")
        await #expect(throws: OAuthError.notConnected) { try await manager.validAccessToken() }
    }
}

struct ProviderConfigurationTests {
    @Test func emptyOrUnexpandedValuesMeanNotConfigured() {
        let config = ProviderConfiguration(infoDictionary: [
            "SpotifyClientID": "",
            "SpotifyRedirectURI": "$(SPOTIFY_REDIRECT_URI)",
            "GoogleIOSClientID": "  ",
        ])
        #expect(config.spotifyOAuth == nil)
        #expect(config.youtubeOAuth == nil)
        #expect(ProviderConfiguration(infoDictionary: nil) == .empty)
    }

    @Test func googleRedirectUsesReversedClientID() throws {
        let config = ProviderConfiguration(infoDictionary: ["GoogleIOSClientID": "123-abc.apps.googleusercontent.com"])
        #expect(config.googleRedirectURI?.absoluteString == "com.googleusercontent.apps.123-abc:/oauth2redirect")
        #expect(config.youtubeOAuth?.callback == .customScheme("com.googleusercontent.apps.123-abc"))
        #expect(config.youtubeOAuth?.scopes == ["https://www.googleapis.com/auth/youtube.readonly"])
    }

    @Test func spotifyConfiguredWithClientIDAndRedirect() {
        let config = ProviderConfiguration(infoDictionary: [
            "SpotifyClientID": "abc",
            "SpotifyRedirectURI": "demonicpromptgen://spotify-callback",
        ])
        #expect(config.spotifyOAuth?.clientID == "abc")
        #expect(ProviderConfiguration.validRedirectURI("javascript:alert(1)") == nil)
        #expect(ProviderConfiguration.validRedirectURI("http://example.com/cb") == nil)
    }
}
