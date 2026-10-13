// MockServer.swift
// An in-process fake of the MediaShelf backend, for tests and for running
// the app without rj-server. Debug builds only.
//
// It works at the URLProtocol level, so APIClient, AsyncImage, and every
// model run their real code paths; only the bytes on the wire are faked.
// Launch the app with `--mock-server` and it answers every /api/v1 route
// from an in-memory store seeded with MockFixtures. Add `--mock-signed-in`
// to skip the sign-in screen, or `--mock-empty` for a shelf with nothing on it.
//
// The mock has one account:
//     username  tester
//     password  shelf-tester-2026
// It exists only here. Nothing is ever created on a real server.

#if DEBUG
import Foundation
import UIKit

enum MockServer {
    static let host = "mock.mediashelf.test"
    static let baseURLString = "http://\(host)"
    static let username = "tester"
    static let password = "shelf-tester-2026"
    static let accessToken = "mock-access-token"
    static let refreshToken = "mock-refresh-token"

    static var isRequested: Bool { CommandLine.arguments.contains("--mock-server") }

    /// Call once at app start. No-op unless `--mock-server` is present.
    static func installIfRequested() {
        guard isRequested else { return }
        install()
        ServerConfig.urlString = baseURLString
        Keychain.clearTokens()
        if CommandLine.arguments.contains("--mock-signed-in") {
            Keychain.set(accessToken, for: .accessToken)
            Keychain.set(refreshToken, for: .refreshToken)
        }
        MockStore.shared.reset(items: CommandLine.arguments.contains("--mock-empty") ? [] : MockFixtures.items)
    }

    /// Route the shared session (and AsyncImage) through the mock.
    static func install() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    /// A private session that only talks to the mock. For unit tests.
    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - Store

/// The fake database. Thread-safe because URLProtocol calls arrive on
/// background threads.
final class MockStore: @unchecked Sendable {
    static let shared = MockStore()

    private let lock = NSLock()
    private var _items: [CollectionItem] = []
    private var _user = MockFixtures.user
    private var _searchResults = MockFixtures.searchResults
    private(set) var requestLog: [String] = []

    var items: [CollectionItem] { lock.withLock { _items } }
    var user: User { lock.withLock { _user } }
    var searchResults: [SearchResult] { lock.withLock { _searchResults } }

    func reset(items: [CollectionItem], searchResults: [SearchResult] = MockFixtures.searchResults) {
        lock.withLock {
            _items = items
            _searchResults = searchResults
            _user = MockFixtures.user
            requestLog = []
        }
    }

    func log(_ line: String) { lock.withLock { requestLog.append(line) } }

    func update(_ mutate: (inout [CollectionItem]) -> Void) {
        lock.withLock { mutate(&_items) }
    }

    func updateUser(displayName: String?, email: String?) -> User {
        lock.withLock {
            _user = User(id: _user.id, username: _user.username, email: email ?? _user.email,
                         displayName: displayName ?? _user.displayName, role: _user.role,
                         isActive: _user.isActive, createdAt: _user.createdAt)
            return _user
        }
    }
}

// MARK: - URLProtocol

final class MockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == MockServer.host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.readBody(of: request)
        let reply = MockRouter.handle(request, body: body)
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: "HTTP/1.1",
                                             headerFields: ["Content-Type": reply.contentType])
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// Inside a URLProtocol the body arrives as a stream, not `httpBody`.
    private static func readBody(of request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

// MARK: - Router

enum MockRouter {
    struct Reply {
        let status: Int
        let body: Data
        var contentType = "application/json"
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder = JSONDecoder()

    static func handle(_ request: URLRequest, body: Data) -> Reply {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return error(400, "Bad request") }

        let method = request.httpMethod ?? "GET"
        var path = components.path
        if path.hasPrefix("/api/v1") { path.removeFirst("/api/v1".count) }
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        let query = Dictionary((components.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        let json = (try? decoder.decode([String: JSONValue].self, from: body)) ?? [:]
        let store = MockStore.shared
        store.log("\(method) \(path)")

        // Covers are served too, so AsyncImage has something to load.
        if path.hasPrefix("/covers/") {
            return Reply(status: 200, body: MockCovers.png(named: path), contentType: "image/png")
        }

        // Auth routes that don't need a token.
        switch (method, path) {
        case ("POST", "/auth/login"):
            guard json["username"]?.displayString == MockServer.username,
                  json["password"]?.displayString == MockServer.password
            else { return error(401, "Incorrect username or password") }
            return ok(tokens())
        case ("POST", "/auth/register"):
            guard let username = json["username"]?.displayString, username.count >= 3 else {
                return error(422, "Username must be at least 3 characters")
            }
            _ = store.updateUser(displayName: json["display_name"]?.displayString, email: json["email"]?.displayString)
            return ok(tokens())
        case ("POST", "/auth/refresh"):
            guard json["refresh_token"]?.displayString == MockServer.refreshToken else {
                return error(401, "Invalid refresh token")
            }
            return ok(tokens())
        default:
            break
        }

        // Everything else needs the bearer token.
        let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
        guard auth == "Bearer \(MockServer.accessToken)" else {
            return error(401, "Not authenticated")
        }

        switch (method, path) {
        case ("GET", "/auth/me"):
            return ok(store.user)

        case ("GET", "/collection"):
            return ok(listCollection(query, from: store.items))

        case ("GET", "/collection/stats"):
            let items = store.items
            func count(_ t: MediaType) -> Int { items.filter { $0.mediaType == t }.count }
            return ok(CollectionStats(total: items.count, vinyl: count(.vinyl), book: count(.book), movie: count(.movie),
                                      show: count(.show), documentary: count(.documentary), audiobook: count(.audiobook)))

        case ("POST", "/collection"):
            guard let typeRaw = json["media_type"]?.displayString, let type = MediaType(rawValue: typeRaw),
                  let title = json["title"]?.displayString
            else { return error(422, "media_type and title are required") }
            let externalID = json["external_id"]?.displayString
            if let externalID, store.items.contains(where: { $0.externalId == externalID && $0.mediaType == type }) {
                return error(409, "Already in your collection")
            }
            var metadata: [String: JSONValue] = [:]
            if case .object(let o)? = json["metadata"] { metadata = o }
            let item = CollectionItem(
                id: UUID(), userId: store.user.id, mediaType: type, externalId: externalID, title: title,
                imageUrl: json["image_url"]?.displayString, metadata: metadata,
                rating: json["rating"]?.intValue, status: json["status"]?.displayString,
                notes: json["notes"]?.displayString, tags: stringArray(json["tags"]),
                isFavorite: { if case .bool(let b)? = json["is_favorite"] { return b } else { return false } }(),
                addedAt: .now, updatedAt: .now, addedByName: store.user.displayName)
            store.update { $0.insert(item, at: 0) }
            return ok(item, status: 201)

        default:
            break
        }

        // /collection/{id}
        if path.hasPrefix("/collection/"), let id = UUID(uuidString: String(path.dropFirst("/collection/".count))) {
            guard let index = store.items.firstIndex(where: { $0.id == id }) else { return error(404, "Item not found") }
            switch method {
            case "GET":
                return ok(store.items[index])
            case "PATCH":
                var updated: CollectionItem?
                store.update { items in
                    let old = items[index]
                    let new = CollectionItem(
                        id: old.id, userId: old.userId, mediaType: old.mediaType, externalId: old.externalId,
                        title: json["title"]?.displayString ?? old.title,
                        imageUrl: json.keys.contains("image_url") ? json["image_url"]?.displayString : old.imageUrl,
                        metadata: { if case .object(let o)? = json["metadata"] { return o } else { return old.metadata } }(),
                        rating: json.keys.contains("rating") ? json["rating"]?.intValue : old.rating,
                        status: json.keys.contains("status") ? json["status"]?.displayString : old.status,
                        notes: json.keys.contains("notes") ? json["notes"]?.displayString : old.notes,
                        tags: json.keys.contains("tags") ? stringArray(json["tags"]) : old.tags,
                        isFavorite: { if case .bool(let b)? = json["is_favorite"] { return b } else { return old.isFavorite } }(),
                        addedAt: old.addedAt, updatedAt: .now, addedByName: old.addedByName)
                    items[index] = new
                    updated = new
                }
                return ok(updated!)
            case "DELETE":
                store.update { $0.remove(at: index) }
                return Reply(status: 204, body: Data())
            default:
                return error(405, "Method not allowed")
            }
        }

        // /search/{endpoint}
        if method == "GET", path.hasPrefix("/search/") {
            let endpoint = String(path.dropFirst("/search/".count))
            let q = (query["q"] ?? "").lowercased()
            let results = store.searchResults.filter { r in
                MediaType(rawValue: r.mediaType)?.searchEndpoint == endpoint
                    && (q.isEmpty || r.title.lowercased().contains(q) || (r.subtitle?.lowercased().contains(q) ?? false))
            }
            return ok(SearchPage(results: results, total: results.count, page: 1, totalPages: 1))
        }

        switch (method, path) {
        case ("GET", "/users"):
            let u = store.user
            return ok([UserListItem(id: u.id, username: u.username, displayName: u.displayName, role: u.role),
                       UserListItem(id: UUID(), username: "sam", displayName: "Sam Reader", role: "member")])
        case ("PATCH", "/users/me"):
            let u = store.updateUser(displayName: json["display_name"]?.displayString, email: json["email"]?.displayString)
            return ok(UserListItem(id: u.id, username: u.username, displayName: u.displayName, role: u.role))
        default:
            return error(404, "Not found")
        }
    }

    // MARK: Helpers

    private static func tokens() -> TokenResponse {
        TokenResponse(accessToken: MockServer.accessToken, refreshToken: MockServer.refreshToken)
    }

    private static func listCollection(_ query: [String: String], from all: [CollectionItem]) -> CollectionPage {
        var items = all
        if let t = query["media_type"], let type = MediaType(rawValue: t) { items = items.filter { $0.mediaType == type } }
        if let s = query["status"] { items = items.filter { $0.status == s } }
        if query["is_favorite"] == "true" { items = items.filter(\.isFavorite) }
        if let q = query["q"]?.lowercased(), !q.isEmpty { items = items.filter { $0.title.lowercased().contains(q) } }

        let descending = (query["sort_order"] ?? "desc") == "desc"
        switch query["sort_by"] ?? "added_at" {
        case "title":
            items.sort { descending ? $0.title > $1.title : $0.title < $1.title }
        case "rating":
            items.sort { descending ? ($0.rating ?? 0) > ($1.rating ?? 0) : ($0.rating ?? 0) < ($1.rating ?? 0) }
        default:
            items.sort { descending ? $0.addedAt > $1.addedAt : $0.addedAt < $1.addedAt }
        }

        let page = max(1, Int(query["page"] ?? "") ?? 1)
        let size = max(1, Int(query["page_size"] ?? "") ?? 24)
        let total = items.count
        let start = min((page - 1) * size, total)
        let slice = Array(items[start..<min(start + size, total)])
        return CollectionPage(items: slice, total: total, page: page, pageSize: size,
                              totalPages: max(1, Int((Double(total) / Double(size)).rounded(.up))))
    }

    private static func stringArray(_ value: JSONValue?) -> [String] {
        if case .array(let values)? = value {
            return values.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
        }
        return []
    }

    private static func ok<T: Encodable>(_ value: T, status: Int = 200) -> Reply {
        Reply(status: status, body: (try? encoder.encode(value)) ?? Data("{}".utf8))
    }

    private static func error(_ status: Int, _ detail: String) -> Reply {
        Reply(status: status, body: (try? encoder.encode(["detail": detail])) ?? Data())
    }
}

// MARK: - Covers

/// Solid-color placeholder art so image loading is exercised too.
enum MockCovers {
    static func png(named path: String) -> Data {
        let name = (path as NSString).lastPathComponent
        let hue = CGFloat(abs(name.hashValue % 360)) / 360
        let color = UIColor(hue: hue, saturation: 0.45, brightness: 0.55, alpha: 1)
        let size = CGSize(width: 240, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.withAlphaComponent(0.85).setFill()
            let letter = String(name.prefix(1)).uppercased() as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 140, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
            ]
            let textSize = letter.size(withAttributes: attrs)
            letter.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                        withAttributes: attrs)
        }
        return image.pngData() ?? Data()
    }
}

// MARK: - Fixtures

enum MockFixtures {
    static let userID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!

    static let user = User(id: userID, username: MockServer.username, email: "tester@mediashelf.test",
                           displayName: "Tess Tester", role: "admin", isActive: true,
                           createdAt: Date(timeIntervalSince1970: 1_760_000_000))

    static func cover(_ name: String) -> String { "\(MockServer.baseURLString)/covers/\(name).png" }

    private static func item(_ title: String, _ type: MediaType, status: String?, rating: Int? = nil,
                             favorite: Bool = false, cover: String? = nil, daysAgo: Int,
                             externalID: String? = nil, metadata: [String: JSONValue] = [:],
                             notes: String? = nil, tags: [String] = []) -> CollectionItem {
        let added = Date(timeIntervalSince1970: 1_760_000_000 - Double(daysAgo) * 86_400)
        return CollectionItem(
            id: UUID(), userId: userID, mediaType: type, externalId: externalID ?? "ext-\(title.hashValue)",
            title: title, imageUrl: cover, metadata: metadata, rating: rating, status: status, notes: notes,
            tags: tags, isFavorite: favorite, addedAt: added, updatedAt: added, addedByName: "Tess Tester")
    }

    /// A believable small shelf: every type, every status, a long title, a
    /// missing cover, a favorite, and two well-rated seeds for recommendations.
    static let items: [CollectionItem] = [
        item("Andor", .show, status: "watching", rating: 5, favorite: true, cover: cover("andor"), daysAgo: 0,
             metadata: ["overview": .string("Prequel series to Rogue One."), "first_air_date": .string("2022-09-21"),
                        "current_season": .number(2), "total_seasons": .number(2)]),
        item("Fleetwood Mac - Rumours", .vinyl, status: "owned", rating: 5, cover: cover("rumours"), daysAgo: 1,
             externalID: "discogs-rumours",
             metadata: ["label": .string("Warner Bros."), "year": .string("1977"), "genres": .array([.string("Rock")])]),
        item("A Knight of the Seven Kingdoms", .book, status: "completed", rating: 4, cover: cover("knight"), daysAgo: 2,
             externalID: "gb-knight",
             metadata: ["authors": .array([.string("George R. R. Martin")]), "page_count": .number(368),
                        "description": .string("Three novellas about Dunk and Egg.")]),
        item("Superbad", .movie, status: "watched", rating: 3, cover: cover("superbad"), daysAgo: 3,
             metadata: ["release_date": .string("2007-08-17")]),
        item("Project Hail Mary", .audiobook, status: "reading", daysAgo: 4,
             metadata: ["authors": .array([.string("Andy Weir")])]),
        item("Castle Rock", .show, status: "dropped", cover: cover("castlerock"), daysAgo: 5),
        item("Memoirs of a Geisha", .book, status: "wishlist", favorite: true, daysAgo: 6,
             metadata: ["authors": .array([.string("Arthur Golden")])]),
        item("Documentary Now!", .documentary, status: "want_to_watch", cover: cover("docnow"), daysAgo: 7),
        item("The Rise and Fall of the Third Reich: A History of Nazi Germany, Unabridged Audiobook Edition",
             .audiobook, status: "completed", rating: 4, daysAgo: 8,
             metadata: ["authors": .array([.string("William L. Shirer")])]),
        item("Radiohead - OK Computer", .vinyl, status: "wishlist", cover: cover("okcomputer"), daysAgo: 9,
             externalID: "discogs-okc"),
        item("Severance", .show, status: "want_to_watch", cover: cover("severance"), daysAgo: 10),
        item("Dune", .book, status: "reading", rating: 5, cover: cover("dune"), daysAgo: 11,
             metadata: ["authors": .array([.string("Frank Herbert")])],
             notes: "Reading the Deluxe Edition.", tags: ["sci-fi", "classic"]),
    ]

    /// Lots of filler for paging tests.
    static func bulk(_ count: Int) -> [CollectionItem] {
        (0..<count).map { i in
            item("Bulk Item \(String(format: "%03d", i))", MediaType.allCases[i % MediaType.allCases.count],
                 status: "owned", rating: (i % 5) + 1, daysAgo: i)
        }
    }

    private static func result(_ title: String, _ type: MediaType, subtitle: String? = nil, year: String? = nil,
                               externalID: String? = nil, metadata: [String: JSONValue] = [:]) -> SearchResult {
        SearchResult(externalId: externalID ?? "search-\(title.hashValue)", title: title, subtitle: subtitle,
                     imageUrl: cover(title.filter(\.isLetter).lowercased()), mediaType: type.rawValue,
                     year: year, metadata: metadata)
    }

    /// What "Discogs", "Google Books", and "TMDB" return here.
    static let searchResults: [SearchResult] = [
        result("Fleetwood Mac - Tusk", .vinyl, subtitle: "2×LP, Album", year: "1979",
               metadata: ["label": .string("Warner Bros.")]),
        result("Fleetwood Mac - Tango in the Night", .vinyl, subtitle: "LP, Album", year: "1987"),
        result("Fleetwood Mac - Rumours", .vinyl, subtitle: "LP, Album", year: "1977", externalID: "discogs-rumours"),
        result("Radiohead - OK Computer", .vinyl, subtitle: "2×LP", year: "1997", externalID: "discogs-okc"),
        result("Radiohead - In Rainbows", .vinyl, subtitle: "LP", year: "2007"),
        result("Fire & Blood", .book, subtitle: "George R. R. Martin", year: "2018",
               metadata: ["authors": .array([.string("George R. R. Martin")]),
                          "description": .string("The history of House Targaryen.")]),
        result("A Game of Thrones", .book, subtitle: "George R. R. Martin", year: "1996",
               metadata: ["authors": .array([.string("George R. R. Martin")])]),
        result("A Knight of the Seven Kingdoms", .book, subtitle: "George R. R. Martin", year: "2015", externalID: "gb-knight"),
        result("Children of Dune", .book, subtitle: "Frank Herbert", year: "1976",
               metadata: ["authors": .array([.string("Frank Herbert")])]),
        result("Superbad", .movie, subtitle: "2007", year: "2007",
               metadata: ["overview": .string("Two co-dependent high school seniors.")]),
        result("Booksmart", .movie, subtitle: "2019", year: "2019"),
        result("Andor", .show, subtitle: "2022", year: "2022"),
        result("The Mandalorian", .show, subtitle: "2019", year: "2019"),
    ]
}
#endif
