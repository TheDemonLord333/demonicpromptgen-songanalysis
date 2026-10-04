import Foundation
import Testing
@testable import demonincpromptgen_songanalysis

struct SongLinkParserTests {
    // MARK: Spotify

    @Test(arguments: [
        "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC",
        "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?si=abc123&utm_source=copy-link",
        "https://open.spotify.com/intl-de/track/4uLU6hMCjMI75M1A2tKUQC?si=x",
        "https://open.spotify.com/embed/track/4uLU6hMCjMI75M1A2tKUQC",
        "open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC",
        "http://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC",
        "HTTPS://OPEN.SPOTIFY.COM/track/4uLU6hMCjMI75M1A2tKUQC",
        "https://open.spotify.com./track/4uLU6hMCjMI75M1A2tKUQC",
        "spotify:track:4uLU6hMCjMI75M1A2tKUQC",
        "  https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC \n",
        "Hör dir das an: https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?si=1",
    ])
    func spotifyTrackLinksAreNormalized(input: String) throws {
        let link = try parsedLink(input)
        #expect(link.provider == .spotify)
        #expect(link.url.absoluteString == "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC")
        #expect(link.reference == .spotifyTrack(id: "4uLU6hMCjMI75M1A2tKUQC"))
        #expect(link.songID == "spotify:4uLU6hMCjMI75M1A2tKUQC")
    }

    @Test(arguments: [
        "https://open.spotify.com/album/4uLU6hMCjMI75M1A2tKUQC",
        "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M",
        "https://open.spotify.com/track/kurz",
        "spotify:album:4uLU6hMCjMI75M1A2tKUQC",
    ])
    func spotifyNonTrackLinksAreRejected(input: String) {
        #expect(throws: SongLinkError.unsupportedContent(.spotify)) { try parsedLink(input) }
    }

    @Test(arguments: ["https://spotify.link/AbCdEf123", "https://spoti.fi/3xyzAbc"])
    func spotifyShortLinksNeedResolution(input: String) throws {
        let link = try parsedLink(input)
        #expect(link.provider == .spotify)
        #expect(link.needsResolution)
        #expect(link.songID == nil)
    }

    // MARK: YouTube

    @Test(arguments: [
        ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://youtube.com/watch?v=dQw4w9WgXcQ&list=RD123&feature=share", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://m.youtube.com/watch?v=dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://youtu.be/dQw4w9WgXcQ?si=tracking", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://www.youtube.com/shorts/dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://www.youtube.com/embed/dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://www.youtube.com/live/dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://music.youtube.com/watch?v=dQw4w9WgXcQ&si=abc", "https://music.youtube.com/watch?v=dQw4w9WgXcQ"),
    ])
    func youtubeLinksAreNormalized(input: String, expected: String) throws {
        let link = try parsedLink(input)
        #expect(link.provider == .youtube)
        #expect(link.url.absoluteString == expected)
        #expect(link.reference == .youtubeVideo(id: "dQw4w9WgXcQ"))
    }

    @Test(arguments: [
        "https://www.youtube.com/watch?v=short",
        "https://www.youtube.com/@channel",
        "https://www.youtube.com/playlist?list=PL123",
        "https://youtu.be/",
    ])
    func youtubeNonVideoLinksAreRejected(input: String) {
        #expect(throws: SongLinkError.unsupportedContent(.youtube)) { try parsedLink(input) }
    }

    // MARK: Apple Music

    @Test func appleMusicAlbumLinkWithSongKeepsOnlySongParameter() throws {
        let link = try parsedLink("https://music.apple.com/de/album/never-gonna-give-you-up/1559523357?i=1559523359&ls=1&app=music")
        #expect(link.provider == .appleMusic)
        #expect(link.reference == .appleMusicSong(id: "1559523359", storefront: "de"))
        #expect(link.url.absoluteString == "https://music.apple.com/de/album/never-gonna-give-you-up/1559523357?i=1559523359")
    }

    @Test func appleMusicSongLink() throws {
        let link = try parsedLink("https://music.apple.com/us/song/never-gonna-give-you-up/1559523359")
        #expect(link.reference == .appleMusicSong(id: "1559523359", storefront: "us"))
        #expect(link.songID == "appleMusic:1559523359")
    }

    @Test func legacyITunesLinkWithIDPrefix() throws {
        let link = try parsedLink("https://itunes.apple.com/de/album/name/id1559523357?i=1559523359&uo=4")
        #expect(link.reference == .appleMusicSong(id: "1559523359", storefront: "de"))
    }

    @Test func appleMusicAlbumWithoutSongIsRejected() {
        #expect(throws: SongLinkError.unsupportedContent(.appleMusic)) {
            try parsedLink("https://music.apple.com/de/album/name/1559523357")
        }
    }

    @Test func appleShortLinkNeedsResolution() throws {
        let link = try parsedLink("https://apple.co/3AbCdEf")
        #expect(link.provider == .appleMusic)
        #expect(link.needsResolution)
    }

    // MARK: Täuschende und ungültige Eingaben

    @Test(arguments: [
        "https://open.spotify.com.evil.example/track/4uLU6hMCjMI75M1A2tKUQC",
        "https://evilopen.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC",
        "https://open-spotify.com/track/4uLU6hMCjMI75M1A2tKUQC",
        "https://evil.example/open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC",
        "https://evil.example/?u=https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC",
        "https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ",
        "https://notyoutu.be/dQw4w9WgXcQ",
        "https://music.apple.com.evil.example/de/song/x/1559523359",
        "https://xn--yutube-wqf.com/watch?v=dQw4w9WgXcQ",
        "https://soundcloud.com/artist/song",
    ])
    func deceptiveHostsAreRejected(input: String) {
        #expect(throws: SongLinkError.unsupportedHost) { try parsedLink(input) }
    }

    @Test func credentialsInURLAreRejected() {
        #expect(throws: SongLinkError.credentialsInURL) {
            try parsedLink("https://open.spotify.com@evil.example/track/4uLU6hMCjMI75M1A2tKUQC")
        }
        #expect(throws: SongLinkError.credentialsInURL) {
            try parsedLink("https://user:pass@open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC")
        }
    }

    @Test func unusualPortIsRejected() {
        #expect(throws: SongLinkError.unsupportedHost) {
            try parsedLink("https://open.spotify.com:8443/track/4uLU6hMCjMI75M1A2tKUQC")
        }
    }

    @Test(arguments: ["ftp://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC", "javascript://open.spotify.com/track/x"])
    func nonWebSchemesAreRejected(input: String) {
        #expect(throws: SongLinkError.unsupportedScheme) { try parsedLink(input) }
    }

    @Test func emptyAndGarbageInput() {
        #expect(throws: SongLinkError.empty) { try parsedLink("   ") }
        #expect(throws: SongLinkError.notALink) { try parsedLink("das ist kein link") }
    }

    @Test func errorMessagesAreGerman() {
        #expect(SongLinkError.unsupportedHost.message.contains("Spotify, YouTube und Apple Music"))
        #expect(SongLinkError.unsupportedContent(.youtube).message.contains("YouTube"))
    }

    // MARK: Hosts für Cover

    @Test func artworkHostsUseDotBoundary() throws {
        #expect(AllowedHosts.isAllowedArtworkURL(try #require(URL(string: "https://i.scdn.co/image/abc"))))
        #expect(AllowedHosts.isAllowedArtworkURL(try #require(URL(string: "https://is1-ssl.mzstatic.com/image/x.jpg"))))
        #expect(!AllowedHosts.isAllowedArtworkURL(try #require(URL(string: "https://evilscdn.co/image/abc"))))
        #expect(!AllowedHosts.isAllowedArtworkURL(try #require(URL(string: "https://i.scdn.co.evil.example/a"))))
        #expect(!AllowedHosts.isAllowedArtworkURL(try #require(URL(string: "http://i.scdn.co/image/abc"))))
    }

    @Test func apiHostsAreExact() throws {
        #expect(AllowedHosts.isAllowedAPIRequest(try #require(URL(string: "https://api.spotify.com/v1/search"))))
        #expect(!AllowedHosts.isAllowedAPIRequest(try #require(URL(string: "https://api.spotify.com.evil.example/v1"))))
        #expect(!AllowedHosts.isAllowedAPIRequest(try #require(URL(string: "https://example.com/oembed"))))
    }
}
