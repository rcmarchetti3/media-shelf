// APIClient.swift
// One thin async client for /api/v1. Mirrors frontend/src/lib/api.ts:
// attach the access token, on 401 try one refresh, then retry once.
//
// It's an actor so the refresh dance can't run twice at the same time.
// Every method here maps to exactly one backend route; the route is in the
// doc comment so you can cross-reference backend/app/api/v1/*/router.py.

import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var refreshTask: Task<Bool, Never>?

    /// Called once when a refresh fails and the tokens are cleared, so
    /// AuthStore can drop the app back to sign in. Set by AuthStore.
    private var onSessionExpired: (@Sendable () -> Void)?

    func setSessionExpiredHandler(_ handler: @escaping @Sendable () -> Void) {
        onSessionExpired = handler
    }

    init(session: URLSession = .shared) {
        self.session = session

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom(Self.decodeDate)
        self.decoder = decoder
    }

    // MARK: - Auth (auth/router.py)

    /// POST /auth/login
    func login(username: String, password: String) async throws -> TokenResponse {
        let tokens: TokenResponse = try await send(
            .post, "/auth/login", body: LoginRequest(username: username, password: password),
            authenticated: false)
        store(tokens)
        return tokens
    }

    /// POST /auth/register
    func register(_ request: RegisterRequest) async throws -> TokenResponse {
        let tokens: TokenResponse = try await send(
            .post, "/auth/register", body: request, authenticated: false)
        store(tokens)
        return tokens
    }

    /// GET /auth/me
    func me() async throws -> User {
        try await send(.get, "/auth/me")
    }

    func signOut() {
        Keychain.clearTokens()
    }

    var hasSession: Bool { Keychain.get(.refreshToken) != nil }

    // MARK: - Collection (collection/router.py)

    struct CollectionQuery: Sendable {
        var mediaType: MediaType? = nil
        var status: ItemStatus? = nil
        var isFavorite: Bool? = nil
        var tags: [String] = []
        var q: String? = nil
        var sortBy: String = "added_at"
        var sortOrder: String = "desc"
        var page: Int = 1
        var pageSize: Int = 24

        var items: [URLQueryItem] {
            var out: [URLQueryItem] = [
                .init(name: "sort_by", value: sortBy),
                .init(name: "sort_order", value: sortOrder),
                .init(name: "page", value: String(page)),
                .init(name: "page_size", value: String(pageSize)),
            ]
            if let mediaType { out.append(.init(name: "media_type", value: mediaType.rawValue)) }
            if let status { out.append(.init(name: "status", value: status.rawValue)) }
            if let isFavorite { out.append(.init(name: "is_favorite", value: isFavorite ? "true" : "false")) }
            if let q, !q.isEmpty { out.append(.init(name: "q", value: q)) }
            for tag in tags { out.append(.init(name: "tags", value: tag)) }
            return out
        }
    }

    /// GET /collection/
    func listCollection(_ query: CollectionQuery = .init()) async throws -> CollectionPage {
        try await send(.get, "/collection/", query: query.items)
    }

    /// GET /collection/stats
    func collectionStats() async throws -> CollectionStats {
        try await send(.get, "/collection/stats")
    }

    /// GET /collection/{id}
    func collectionItem(_ id: UUID) async throws -> CollectionItem {
        try await send(.get, "/collection/\(id.uuidString.lowercased())")
    }

    /// POST /collection/
    func addToCollection(_ item: CollectionItemCreate) async throws -> CollectionItem {
        try await send(.post, "/collection/", body: item)
    }

    /// PATCH /collection/{id}
    /// Takes a raw dictionary so a field can be set to JSON null on purpose
    /// (clearing a rating, for example). Keys are snake_case as the API wants.
    func updateCollectionItem(_ id: UUID, fields: [String: JSONValue]) async throws -> CollectionItem {
        try await send(.patch, "/collection/\(id.uuidString.lowercased())", body: fields)
    }

    /// DELETE /collection/{id}
    func deleteCollectionItem(_ id: UUID) async throws {
        try await sendVoid(.delete, "/collection/\(id.uuidString.lowercased())")
    }

    // MARK: - Search (search/router.py)

    /// GET /search/{vinyl|books|movies|shows}?q=&page=
    func search(_ type: MediaType, query: String, page: Int = 1) async throws -> SearchPage {
        try await send(
            .get, "/search/\(type.searchEndpoint)",
            query: [.init(name: "q", value: query), .init(name: "page", value: String(page))])
    }

    // MARK: - Users (users/router.py)

    /// GET /users/
    func listUsers() async throws -> [UserListItem] {
        try await send(.get, "/users/")
    }

    /// PATCH /users/me
    func updateProfile(_ update: UserUpdateRequest) async throws -> UserListItem {
        try await send(.patch, "/users/me", body: update)
    }

    /// GET /users/{id}/collection
    func userCollection(_ userId: UUID, page: Int = 1, pageSize: Int = 24) async throws -> CollectionPage {
        try await send(
            .get, "/users/\(userId.uuidString.lowercased())/collection",
            query: [.init(name: "page", value: String(page)), .init(name: "page_size", value: String(pageSize))])
    }

    // MARK: - Plumbing

    enum Method: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }

    private func send<T: Decodable>(
        _ method: Method, _ path: String,
        query: [URLQueryItem] = [], body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        let (data, _) = try await perform(method, path, query: query, body: body, authenticated: authenticated)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func sendVoid(
        _ method: Method, _ path: String,
        query: [URLQueryItem] = [], body: (any Encodable)? = nil
    ) async throws {
        _ = try await perform(method, path, query: query, body: body, authenticated: true)
    }

    private func perform(
        _ method: Method, _ path: String,
        query: [URLQueryItem], body: (any Encodable)?,
        authenticated: Bool, isRetry: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {
        let request = try buildRequest(method, path, query: query, body: body, authenticated: authenticated)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("No HTTP response")
        }

        if http.statusCode == 401, authenticated, !isRetry {
            if await refreshTokens() {
                return try await perform(method, path, query: query, body: body, authenticated: true, isRetry: true)
            }
            Keychain.clearTokens()
            onSessionExpired?()
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? decoder.decode(FastAPIErrorBody.self, from: data))?.message
            throw APIError.http(status: http.statusCode, detail: detail)
        }
        return (data, http)
    }

    private func buildRequest(
        _ method: Method, _ path: String,
        query: [URLQueryItem], body: (any Encodable)?, authenticated: Bool
    ) throws -> URLRequest {
        guard let base = ServerConfig.apiBaseURL else { throw APIError.noServer }
        guard var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false)
        else { throw APIError.invalidURL }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        if authenticated, let token = Keychain.get(.accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// POST /auth/refresh. Coalesces concurrent callers onto one refresh.
    private func refreshTokens() async -> Bool {
        if let refreshTask { return await refreshTask.value }
        let task = Task<Bool, Never> {
            guard let refresh = Keychain.get(.refreshToken) else { return false }
            do {
                let tokens: TokenResponse = try await send(
                    .post, "/auth/refresh", body: RefreshRequest(refreshToken: refresh),
                    authenticated: false)
                store(tokens)
                return true
            } catch {
                return false
            }
        }
        refreshTask = task
        let ok = await task.value
        refreshTask = nil
        return ok
    }

    private func store(_ tokens: TokenResponse) {
        Keychain.set(tokens.accessToken, for: .accessToken)
        Keychain.set(tokens.refreshToken, for: .refreshToken)
    }

    /// Pydantic emits naive datetimes like "2026-04-03T21:42:38.123456" with no
    /// zone, and sometimes with a zone. Accept both, and whole seconds.
    nonisolated private static func decodeDate(_ decoder: Decoder) throws -> Date {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }

        let naive = DateFormatter()
        naive.locale = Locale(identifier: "en_US_POSIX")
        naive.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            naive.dateFormat = format
            if let d = naive.date(from: raw) { return d }
        }
        throw DecodingError.dataCorruptedError(
            in: try decoder.singleValueContainer(), debugDescription: "Unrecognized date: \(raw)")
    }
}
