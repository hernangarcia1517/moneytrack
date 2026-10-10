import Foundation

nonisolated enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}

struct APIClient {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private static let unreachableCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
        .networkConnectionLost, .timedOut, .internationalRoamingOff, .dataNotAllowed,
    ]

    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()

    var baseURL: URL = APIConfig.baseURL
    var session: URLSession = APIClient.defaultSession

    func get<Response: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Response {
        try decode(await perform(.get, path, query: query, body: nil))
    }

    func send<Body: Encodable, Response: Decodable>(_ method: HTTPMethod, _ path: String, body: Body) async throws -> Response {
        try decode(await perform(method, path, query: [], body: encode(body)))
    }

    func delete(_ path: String) async throws {
        _ = try await perform(.delete, path, query: [], body: nil)
    }

    private func perform(_ method: HTTPMethod, _ path: String, query: [URLQueryItem], body: Data?) async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw APIError.invalidRequest }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        // Fastify rejects a Content-Type: application/json header on a request with no body.
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw Self.unreachableCodes.contains(error.code) ? APIError.unreachable : APIError.connection(error.code)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = try? Self.decoder.decode(ErrorBodyDTO.self, from: data)
            throw APIError.server(status: http.statusCode, message: body?.message ?? body?.error ?? "Request failed (\(http.statusCode)).")
        }
        return data
    }

    private func encode<Body: Encodable>(_ body: Body) throws -> Data {
        do { return try Self.encoder.encode(body) } catch { throw APIError.invalidRequest }
    }

    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do { return try Self.decoder.decode(Response.self, from: data) } catch { throw APIError.invalidResponse }
    }
}
