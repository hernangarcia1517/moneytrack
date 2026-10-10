import Foundation

nonisolated enum APIError: LocalizedError, Equatable {
    case unreachable
    case connection(URLError.Code)
    case server(status: Int, message: String)
    case invalidRequest
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unreachable: "Can't reach the server."
        case .connection(let code): "The connection failed (\(code.rawValue))."
        case .server(_, let message): message
        case .invalidRequest: "The app couldn't build the request."
        case .invalidResponse: "The server sent a response the app couldn't read."
        }
    }
}
