// Models.swift
// Codable types matching backend/app/schemas/*.py. Property names are camelCase
// here and snake_case on the wire; APIClient's decoder does the conversion.
// Keep these dumb. No logic, no formatting, just the shape of the JSON.

import Foundation

// MARK: - Auth (schemas/auth.py)

struct TokenResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
}

struct LoginRequest: Encodable, Sendable {
    let username: String
    let password: String
}

struct RegisterRequest: Encodable, Sendable {
    let username: String
    let email: String
    let password: String
    let displayName: String
}

struct RefreshRequest: Encodable, Sendable {
    let refreshToken: String
}

struct User: Codable, Identifiable, Sendable {
    let id: UUID
    let username: String
    let email: String
    let displayName: String
    let role: String
    let isActive: Bool
    let createdAt: Date

    var isAdmin: Bool { role == "admin" }
}

// MARK: - Users (schemas/user.py)

struct UserListItem: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let username: String
    let displayName: String
    let role: String
}

struct UserUpdateRequest: Encodable, Sendable {
    var displayName: String?
    var email: String?
}

// MARK: - Collection (schemas/collection.py)

struct CollectionItem: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: UUID
    let mediaType: MediaType
    let externalId: String?
    let title: String
    let imageUrl: String?
    let metadata: [String: JSONValue]
    let rating: Int?
    let status: String?
    let notes: String?
    let tags: [String]
    let isFavorite: Bool
    let addedAt: Date
    let updatedAt: Date
    let addedByName: String?

    var itemStatus: ItemStatus? { status.map(ItemStatus.init(rawValue:)) }
    var imageURL: URL? { imageUrl.flatMap(URL.init(string:)) }

    /// TV only. Mirrors the fallback in ItemDetailPage.tsx: older shows may
    /// only have TMDB's raw `seasons_count`.
    var currentSeason: Int? { metadata["current_season"]?.intValue }
    var totalSeasons: Int? {
        metadata["total_seasons"]?.intValue ?? metadata["seasons_count"]?.intValue
    }
}

struct CollectionItemCreate: Encodable, Sendable {
    let mediaType: MediaType
    let externalId: String?
    let title: String
    let imageUrl: String?
    let metadata: [String: JSONValue]
    var rating: Int? = nil
    var status: String? = nil
    var notes: String? = nil
    var tags: [String] = []
    var isFavorite: Bool = false
}

struct CollectionPage: Codable, Sendable {
    let items: [CollectionItem]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int

    var hasMore: Bool { page < totalPages }
}

struct CollectionStats: Codable, Sendable {
    let total: Int
    let vinyl: Int
    let book: Int
    let movie: Int
    let show: Int
    let documentary: Int
    let audiobook: Int

    func count(for type: MediaType) -> Int {
        switch type {
        case .vinyl: vinyl
        case .book: book
        case .movie: movie
        case .show: show
        case .documentary: documentary
        case .audiobook: audiobook
        }
    }
}

// MARK: - Search (schemas/search.py)

struct SearchResult: Codable, Identifiable, Sendable, Hashable {
    let externalId: String
    let title: String
    let subtitle: String?
    let imageUrl: String?
    let mediaType: String
    let year: String?
    let metadata: [String: JSONValue]

    /// external_id is only unique per source, so combine with media type.
    var id: String { "\(mediaType):\(externalId)" }
    var imageURL: URL? { imageUrl.flatMap(URL.init(string:)) }
}

struct SearchPage: Codable, Sendable {
    let results: [SearchResult]
    let total: Int
    let page: Int
    let totalPages: Int
}
