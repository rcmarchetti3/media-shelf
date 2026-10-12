// JSONValue.swift
// A Codable stand-in for the free-form `metadata` dict the backend stores
// per item (artist, year, label, director, seasons, whatever the source API
// returned). Swift has no `Any` that's Codable, so this enum is the bridge.

import Foundation

enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        }
    }

    /// Best-effort text for showing a metadata value in a list row.
    var displayString: String? {
        switch self {
        case .string(let s): return s.isEmpty ? nil : s
        case .number(let n):
            return n.rounded() == n ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "Yes" : "No"
        case .null: return nil
        case .array(let a):
            let parts = a.compactMap(\.displayString)
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        case .object: return nil
        }
    }

    var intValue: Int? {
        if case .number(let n) = self { return Int(n) }
        if case .string(let s) = self { return Int(s) }
        return nil
    }
}
