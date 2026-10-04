import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated enum NetworkError: Error, Equatable, Sendable {
    case hostNotAllowed
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpStatus(Int)
    case decoding
    case offline
    case timedOut

    var message: String {
        switch self {
        case .hostNotAllowed: "Diese Adresse darf die App nicht anfragen."
        case .invalidResponse: "Der Anbieter hat eine ungültige Antwort geliefert."
        case .unauthorized: "Die Anmeldung ist abgelaufen oder ungültig."
        case .rateLimited: "Zu viele Anfragen. Bitte später erneut versuchen."
        case .httpStatus(let code): "Der Anbieter hat mit Fehler \(code) geantwortet."
        case .decoding: "Die Antwort des Anbieters konnte nicht gelesen werden."
        case .offline: "Keine Internetverbindung."
        case .timedOut: "Zeitüberschreitung bei der Anfrage."
        }
    }

    /// Ordnet beliebige Fehler einer verständlichen Meldung zu.
    static func userMessage(for error: Error) -> String {
        if let networkError = error as? NetworkError { return networkError.message }
        if let urlError = error as? URLError { return from(urlError).message }
        return "Die Anfrage ist fehlgeschlagen."
    }

    static func from(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: .offline
        case .timedOut: .timedOut
        default: .invalidResponse
        }
    }
}

/// Abstraktion für HTTP-Anfragen, damit Dienste testbar bleiben.
nonisolated protocol HTTPDataLoading: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension HTTPDataLoading {
    /// Lädt und dekodiert JSON. Prüft Statuscodes und bildet sie auf `NetworkError` ab.
    nonisolated func decoded<T: Decodable>(_ type: T.Type, for request: URLRequest) async throws -> T {
        let (data, response) = try await data(for: request)
        switch response.statusCode {
        case 200...299:
            break
        case 401:
            throw NetworkError.unauthorized
        case 429:
            throw NetworkError.rateLimited
        default:
            throw NetworkError.httpStatus(response.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding
        }
    }
}

/// `URLSession`-basierter Client, der ausschließlich Hosts aus `AllowedHosts.apiHosts` anfragt.
nonisolated struct URLSessionHTTPClient: HTTPDataLoading {
    private let session: URLSession

    init(session: URLSession = URLSessionHTTPClient.makeDefaultSession()) {
        self.session = session
    }

    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url, AllowedHosts.isAllowedAPIRequest(url) else {
            throw NetworkError.hostNotAllowed
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            return (data, http)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw NetworkError.from(error)
        }
    }
}
