// APIError.swift
// Everything APIClient can throw. Views show `errorDescription` as-is.

import Foundation

enum APIError: LocalizedError, Sendable {
    case noServer
    case invalidURL
    case unauthorized
    case http(status: Int, detail: String?)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .noServer:
            "No server set. Add your MediaShelf address in Settings."
        case .invalidURL:
            "That server address doesn't look right."
        case .unauthorized:
            "Your session expired. Sign in again."
        case .http(let status, let detail):
            detail ?? "Server returned \(status)."
        case .decoding(let what):
            "Couldn't read the server's reply (\(what))."
        case .transport(let what):
            what
        }
    }
}

/// FastAPI's default error body: {"detail": "..."} or {"detail": [...]}.
struct FastAPIErrorBody: Decodable {
    let detail: JSONValue?

    var message: String? {
        switch detail {
        case .string(let s): s
        case .array(let items):
            items.compactMap { item -> String? in
                if case .object(let o) = item { return o["msg"]?.displayString }
                return item.displayString
            }.joined(separator: "\n")
        default: nil
        }
    }
}
