# Demonic Prompt Gen - Songanalyse

iOS-App (Swift, SwiftUI, MVVM), die aus einem Song-Link von **Spotify**, **YouTube** oder **Apple Music** einen Analyse-Prompt erstellt und kopierbar macht.

Den Prompt erstellt die App **lokal und deterministisch**. Sie führt selbst keine KI-Songanalyse durch, braucht keinen KI-API-Schlüssel und für die Hauptfunktion auch keine Anmeldung.

Standardausgabe (der Platzhalter wird durch die gewählte Song-URL ersetzt):

```
Analysiere mir dieses Lied:
https://open.spotify.com/track/…
Lyrics:
Thema, Wortwahl, Reimart, Struktur
Audio:
BPM, Akkorde, Style of Music, Genre
Nutze für BPM, Akkorde wenn es nirgendswo zu finden ist online tools
```

---

## Voraussetzungen

| | Version |
|---|---|
| Xcode | 26.x (das Projekt wurde mit Xcode 26.3 angelegt; Projektformat 77 mit synchronisierten Ordnern) |
| iOS Deployment Target | **17.0** |
| Swift | Swift-6.2-Compiler im Swift-5-Sprachmodus, Default Actor Isolation `MainActor`, „Approachable Concurrency“ |
| Externe Abhängigkeiten | keine (nur Apple-Frameworks: SwiftUI, Observation, AuthenticationServices, MusicKit, CryptoKit, Security) |

## Öffnen und Starten

1. `demonincpromptgen-songanalysis.xcodeproj` in Xcode öffnen.
2. Schema **demonincpromptgen-songanalysis** und einen iPhone-Simulator (iOS 17 oder neuer) wählen.
3. **⌘R** zum Starten, **⌘U** für die Tests.

Ohne weitere Einrichtung funktionieren URL-Eingabe, Metadaten über öffentliche Endpunkte, Prompt-Erstellung, Kopieren und die Apple-Music-Suche über die öffentliche iTunes-API.

## Bundle-ID und Signing

- Bundle-ID: `me.thedemonlord333.demonincpromptgen-songanalysis` (Tests: `…Tests`, `…UITests`)
- Signing: *Automatically manage signing*. Im Projekt ist das Team `LWL7HM459L` eingetragen. Wer ein anderes Konto nutzt, ändert unter *Target › Signing & Capabilities* Team und Bundle-ID.
- Anzeigename (`CFBundleDisplayName`): **Demonic Prompt Gen - Songanalyse**, gesetzt über `INFOPLIST_KEY_CFBundleDisplayName`. Auf dem Homescreen kürzt iOS lange Namen automatisch.

## Was direkt funktioniert und was eine Einrichtung braucht

| Funktion | Ohne Einrichtung | Mit Einrichtung |
|---|---|---|
| Link einfügen, prüfen, normalisieren | ✅ | – |
| Prompt erstellen (Standard und eigene Vorlage) | ✅ | – |
| Prompt kopieren | ✅ | – |
| Einstellungen lokal speichern | ✅ | – |
| Spotify-Metadaten | ✅ Titel und Cover über öffentliches oEmbed (**kein Künstler**) | Titel, Künstler und Cover über die Web API, nach Spotify-Anmeldung |
| Spotify-Suche | ❌ „Noch nicht eingerichtet“ | ✅ nach Anmeldung (Client-ID nötig) |
| YouTube-Metadaten | ✅ Videotitel, **Kanal** und Vorschaubild über öffentliches oEmbed | – |
| YouTube-Suche | ❌ „Noch nicht eingerichtet“ | ✅ nach Google-Anmeldung (iOS-OAuth-Client nötig) |
| Apple-Music-Metadaten | ✅ öffentliche iTunes Lookup API | – |
| Apple-Music-Suche | ✅ öffentliche iTunes Search API | über MusicKit, nach Berechtigung und mit aktiviertem App-Service |
| Kurzlinks (`spotify.link`, `spoti.fi`, `apple.co`) | ✅ höchstens 5 Weiterleitungen, jedes Ziel wird gegen eine Hostliste geprüft | – |

Ohne Zugangsdaten gibt es weder simulierte Verbindungen noch erfundene Suchergebnisse. Demo-Daten stehen nur in Previews (`#if DEBUG`) und in den Tests.

## Anbieter einrichten

Alle Werte sind **öffentlich** (Client-IDs und Redirect-URLs). Client Secrets oder private Schlüssel gehören nicht in die App, und es ist **kein Backend nötig**: Beide OAuth-Anbieter unterstützen den Authorization-Code-Flow mit PKCE für öffentliche Clients.

1. `Config/Providers.local.example.xcconfig` nach `Config/Providers.local.xcconfig` kopieren. Diese Datei ist per `.gitignore` ausgeschlossen.
2. Die eigenen Werte eintragen. `Config/Providers.xcconfig` bindet die lokale Datei per `#include?` ein.
3. Die Werte landen über `Resources/Info.plist` in den Schlüsseln `SpotifyClientID`, `SpotifyRedirectURI` und `GoogleIOSClientID`. Leere Werte bedeuten „Noch nicht eingerichtet“.

### Spotify (Web API, OAuth 2.0 Authorization Code + PKCE)

- Im [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) eine App anlegen und *Web API* auswählen.
- **Redirect-URI** im Dashboard eintragen, exakt so: `demonicpromptgen://spotify-callback`
  - Ein anderer Wert wird in `SPOTIFY_REDIRECT_URI` eingetragen. In xcconfig-Dateien beginnt `//` einen Kommentar, deshalb lautet die Schreibweise dort `demonicpromptgen:/$()/spotify-callback`.
  - Seit 2025 verlangt Spotify HTTPS oder Loopback-IP-Adressen; eigene Schemata sind laut Spotify weiterhin erlaubt. Wird ein eigenes Schema abgelehnt, funktioniert auch eine HTTPS-Redirect-URL (Universal Link mit Associated Domains, ab iOS 17.4 über `ASWebAuthenticationSession.Callback.https`).
- `SPOTIFY_CLIENT_ID` eintragen. **Kein Client Secret.**
- Scopes: keine. Suche und Track-Metadaten brauchen keine Berechtigung, und die App liest weder die persönliche Mediathek noch Playlists.
- Einschränkungen von Spotify (Stand 2026):
  - Im *Development Mode* muss der App-Inhaber Spotify Premium haben.
  - Testnutzer müssen im Dashboard freigeschaltet werden.
  - Die Suche liefert höchstens 10 Treffer (`limit=10`).
  - Refresh-Tokens laufen nach spätestens sechs Monaten ab.
- Spotify bietet keinen Widerrufs-Endpunkt an. „Trennen“ löscht das Token aus der Keychain; den App-Zugriff selbst widerruft man unter spotify.com › Konto › Apps.

### YouTube (YouTube Data API v3, Google OAuth 2.0 + PKCE)

- In der [Google Cloud Console](https://console.cloud.google.com/) ein Projekt anlegen und die **YouTube Data API v3** aktivieren.
- Den OAuth-Zustimmungsbildschirm konfigurieren, Scope `https://www.googleapis.com/auth/youtube.readonly`. Im Testmodus Testnutzer eintragen.
- Einen OAuth-Client vom Typ **iOS** mit der Bundle-ID der App anlegen.
- Die Client-ID (`…apps.googleusercontent.com`) als `GOOGLE_IOS_CLIENT_ID` eintragen.
- **Redirect-URL**: Die App leitet sie automatisch aus der umgekehrten Client-ID ab, zum Beispiel `com.googleusercontent.apps.1234-abcd:/oauth2redirect`. Das ist das von Google für iOS-Clients vorgesehene Schema.
- „Trennen“ widerruft das Token über `https://oauth2.googleapis.com/revoke` und löscht es lokal.
- YouTube liefert Video- und Kanalinformationen. Die App beschriftet sie als **Video** und **Kanal** und behauptet keine Künstlerzuordnung.

### Apple Music (MusicKit und öffentliche iTunes-API)

- Im Apple Developer Portal unter *Identifiers › App-ID* den **App-Service „MusicKit“** aktivieren. Ein privater Schlüssel oder ein Developer Token gehört nicht in die App, iOS erzeugt die Tokens automatisch.
- „Verbinden“ ruft `MusicAuthorization.request()` auf. Widerrufen lässt sich das nur in den iOS-Einstellungen (*Datenschutz & Sicherheit › Medien & Apple Music*). Die App zeigt diesen Hinweis an und bietet keinen wirkungslosen „Trennen“-Knopf.
- Ohne Berechtigung oder ohne App-Service suchen Metadaten und Suche über die öffentliche **iTunes Search/Lookup API** von Apple. Die Quelle wird in der Oberfläche angezeigt.

### Capabilities, Redirect-URLs und Info.plist-Einträge

| Was | Wert |
|---|---|
| Capabilities (Entitlements) | **keine nötig**: Keychain ohne Access Group; `ASWebAuthenticationSession` fängt die Redirects selbst ab, deshalb gibt es keine `CFBundleURLTypes` |
| App-Service | *MusicKit* (Developer Portal, App-ID), nur für die MusicKit-Suche |
| Redirect Spotify | `demonicpromptgen://spotify-callback` (anpassbar) |
| Redirect Google | `com.googleusercontent.apps.<CLIENT-ID-PRÄFIX>:/oauth2redirect` (automatisch) |
| `CFBundleDisplayName` | `Demonic Prompt Gen - Songanalyse` |
| `NSAppleMusicUsageDescription` | gesetzt (Pflicht für `MusicAuthorization.request()`) |
| `UIUserInterfaceStyle` | `Dark` |
| `SpotifyClientID`, `SpotifyRedirectURI`, `GoogleIOSClientID` | aus `Config/Providers*.xcconfig` |
| `PrivacyInfo.xcprivacy` | kein Tracking; UserDefaults mit Begründung `CA92.1` |

## Sicherheit und Stabilität

- **Link-Prüfung** mit `URLComponents`:
  - Anbieter werden nur über exakte Hostnamen erkannt, nicht über Teilstrings. `open.spotify.com.evil.example` und `user@host`-Tricks werden abgelehnt, ebenso fremde Ports und Schemata außer http(s).
- **Normalisierung**: Die App baut den Link aus der erkannten ID neu auf. Trackingparameter wie `si`, `utm_*` oder `feature` entfallen dabei, der Link bleibt aber gültig. Bei Apple-Music-Album-Links bleibt `?i=` (die Song-ID) erhalten.
- **Netzwerk** nur zu einer festen Liste von Hosts (`AllowedHosts`); Cover-Bilder nur von den CDN-Domains der Anbieter. Anfragen an beliebige eingegebene Hosts gibt es nicht.
- **Tokens** liegen in der Keychain (`AfterFirstUnlockThisDeviceOnly`) und werden nie geloggt.
  - Abgelaufene Tokens erneuert ein `actor` (bei parallelen Aufrufen nur einmal). Bei `invalid_grant` endet die Sitzung sauber.
  - Gegen CSRF prüft die App den `state`-Parameter.
  - Parallele Anmeldungen werden verhindert, abgebrochene Anmeldungen sauber behandelt.
- **Metadaten**:
  - Anfragen werden entprellt (600 ms) und bei einem Auswahlwechsel abgebrochen.
  - Ein Generationszähler verwirft verspätete ältere Antworten.
- **Prompt-Status**:
  - Ändern sich Song-Link oder Prompt-Konfiguration nach der Generierung, wird der Prompt als veraltet markiert und das Kopieren gesperrt, bis neu generiert wird.
- Im produktiven Code gibt es keine Force-Unwraps, kein `try!` und kein `fatalError`.

## Projektstruktur

```
demonincpromptgen-songanalysis/
├── App/            Einstieg (@main) und Dependency Injection
├── Models/         SongInfo, SongLink, PromptConfiguration, Zustände, ProviderStatus
├── ViewModels/     MainViewModel, SongPickerViewModel, SettingsViewModel
├── Views/          Main/ (Elemente 1–10), Picker/, Settings/, Components/, Previews/
├── Services/
│   ├── Links/      SongLinkParser, ShortLinkResolver
│   ├── Metadata/   oEmbed, iTunes, Spotify Web API, YouTube Data API, SongMetadataService
│   ├── Networking/ HTTP-Client mit Host-Positivliste
│   ├── Prompt/     PromptBuilder (deterministisch)
│   ├── Auth/       PKCE, OAuth-Anfragen, Token-Manager, ASWebAuthenticationSession
│   ├── Providers/  Spotify/YouTube (OAuth), Apple Music (MusicKit), Konfiguration
│   ├── Storage/    AppSettings (UserDefaults), Keychain
│   └── Clipboard/  UIPasteboard
├── Theme/          Design-Tokens, Button-Stile, dämonische Motive, adaptives Layout
└── Resources/      Assets (AppIcon), Info.plist, PrivacyInfo.xcprivacy
demonincpromptgen-songanalysisTests/    Swift Testing (Unit-Tests)
demonincpromptgen-songanalysisUITests/  XCTest-UI-Tests (Hauptablauf)
Config/                                 Providers.xcconfig (+ lokale Vorlage)
```

## Layout

Die Anordnung folgt der nummerierten Skizze:

- **Kopfbereich**: Titel mit Hörnern oben links (1), Zahnrad oben rechts (2).
- **Songauswahl**: „Song auswählen“ (3), URL-Feld mit Löschen- und `PasteButton` (4), Songauswahl-Button direkt rechts daneben (5), Songkarte (6).
- **Prompt**: „Generierter Prompt“ (7), große scrollbare Prompt-Karte (8) mit Kopierbutton unten rechts innerhalb der Karte (9).
- **Hauptaktion**: „Prompt generieren“ über die volle Breite (10).

Das eigene Layout `FillingVStack` gibt der Prompt-Karte auf großen Displays den Restplatz. Auf kleinen Displays, bei großer Schrift oder offener Tastatur behält die Karte ihre Mindesthöhe und die Seite wird scrollbar. Starre Koordinaten gibt es nicht.

## Tests

- `PromptBuilderTests`: exakte Standardausgabe, Ersetzung von `{songURL}`, Kategorieauswahl, Online-Tools-Hinweis, Validierung eigener Vorlagen.
- `SongLinkParserTests`: Spotify-, YouTube- und Apple-Music-Formate, Share- und Kurzlinks, Entfernen von Trackingparametern, **täuschende Hostnamen**, Anmeldedaten in URLs, Ports, Schemata.
- `ServicesTests`: Kurzlink-Auflösung (Hostprüfung, Limit), API-Mapping (kein erfundener Künstler, HTML-Entitäten), OAuth (PKCE-Parameter, `state`, einmalige Token-Erneuerung, `invalid_grant`), Konfiguration.
- `MainViewModelTests`: **veraltete Metadaten** (eine ältere Antwort überschreibt keine neuere Auswahl), **veraltete Prompts** (URL- oder Konfigurationsänderung sperrt das Kopieren), Kopieren, Auswahl aus dem Picker, Kurzlinks.
- `SettingsTests`: Speicherung, ungültige Vorlage wird nicht gespeichert, mindestens eine Kategorie bleibt aktiv, „Standard wiederherstellen“.
- `PKCETests`: RFC-7636-Testvektor.
- UI-Tests: Hauptablauf ohne Anmeldung, Validierungsmeldung, Einstellungen öffnen und schließen.

## App-Icon

- Quelle: Repository `TheDemonLord333/demonicpromptgen-songanalysis`, Commit `272b1a329b872521dd3ba17af0882a21482b2384`, Datei `Neon-Musikdokument mit Hörnern.png`
  (raw: `https://raw.githubusercontent.com/TheDemonLord333/demonicpromptgen-songanalysis/272b1a329b872521dd3ba17af0882a21482b2384/Neon-Musikdokument%20mit%20H%C3%B6rnern.png`)
- Prüfung: PNG, 1254 × 1254, 8 Bit RGB **ohne Alphakanal** (also deckend, kein Hintergrund nötig), dekodiert fehlerfrei. SHA-256 der Quelle: `54cc30dc3ec8224d254d8f1c1b642e4cdd225c4569cce5261af5833ab628e3c2`
- Verarbeitung: Lanczos-Skalierung auf 1024 × 1024. Motiv, Farben und Proportionen bleiben erhalten; es gibt keine zusätzlichen Schriftzüge, Rahmen oder Rundungen.
- Ablage: `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`, als Einzelgröße 1024 × 1024 (Standard und Dark-Variante), wie es Xcode 14 und neuer erwarten. Das Target nutzt `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.
