// MockBackendTests.swift
// Tests that go through the real APIClient and models against MockServer.
// They share the Keychain, ServerConfig, and MockStore, so the suite runs
// serialized and every test starts from a known state.

import Foundation
import os
import Testing
import UIKit
@testable import MediaShelf

/// Fresh client, fresh store, signed-in tokens. Call at the top of each test.
@MainActor
private func freshClient(items: [CollectionItem] = MockFixtures.items, signedIn: Bool = true) -> APIClient {
    MockServer.install()
    ServerConfig.urlString = MockServer.baseURLString
    MockStore.shared.reset(items: items)
    Keychain.clearTokens()
    if signedIn {
        Keychain.set(MockServer.accessToken, for: .accessToken)
        Keychain.set(MockServer.refreshToken, for: .refreshToken)
    }
    return APIClient(session: MockServer.session())
}

/// Wait for an @Observable model to settle, polling until `condition` holds.
@MainActor
private func eventually(timeout: Duration = .seconds(5), _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(25))
    }
    return condition()
}

/// One serialized parent so the three suites below never run at the same
/// time. `.serialized` on a suite is inherited by its nested suites; on
/// sibling suites it is not, and they would trample the shared store.
@Suite(.serialized)
struct MockBackend {

@Suite(.serialized)
@MainActor
struct APIClientAgainstMock {

    @Test("Sign in with the test account stores tokens and /auth/me works")
    func loginSucceeds() async throws {
        let api = freshClient(signedIn: false)
        #expect(await api.hasSession == false)
        let tokens = try await api.login(username: MockServer.username, password: MockServer.password)
        #expect(tokens.accessToken == MockServer.accessToken)
        #expect(await api.hasSession)
        let me = try await api.me()
        #expect(me.username == "tester")
        #expect(me.isAdmin)
    }

    @Test("Wrong password surfaces the server's message")
    func loginFails() async {
        let api = freshClient(signedIn: false)
        do {
            _ = try await api.login(username: MockServer.username, password: "nope")
            Issue.record("Expected a 401")
        } catch let error as APIError {
            guard case .http(let status, let detail) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect(status == 401)
            #expect(detail == "Incorrect username or password")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("A stale access token is refreshed once and the call retried")
    func refreshFlow() async throws {
        let api = freshClient()
        Keychain.set("stale", for: .accessToken)
        let stats = try await api.collectionStats()
        #expect(stats.total == MockFixtures.items.count)
        #expect(Keychain.get(.accessToken) == MockServer.accessToken, "Refresh should have replaced the token")
        let log = MockStore.shared.requestLog
        #expect(log.contains("POST /auth/refresh"))
        #expect(log.filter { $0 == "GET /collection/stats" }.count == 2, "Original call plus one retry")
    }

    @Test("Both tokens bad means signed out, not an endless loop")
    func refreshFailureSignsOut() async {
        let api = freshClient()
        Keychain.set("stale", for: .accessToken)
        Keychain.set("also-stale", for: .refreshToken)
        let expired = OSAllocatedUnfairLock(initialState: false)
        await api.setSessionExpiredHandler { expired.withLock { $0 = true } }
        do {
            _ = try await api.collectionStats()
            Issue.record("Expected unauthorized")
        } catch let error as APIError {
            guard case .unauthorized = error else { Issue.record("Wrong error: \(error)"); return }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
        #expect(expired.withLock { $0 })
        #expect(await api.hasSession == false)
    }

    @Test("Collection filters and paging are honored")
    func listCollection() async throws {
        let api = freshClient(items: MockFixtures.bulk(60))
        let first = try await api.listCollection(.init(page: 1))
        #expect(first.items.count == 24)
        #expect(first.total == 60)
        #expect(first.totalPages == 3)
        #expect(first.hasMore)

        let last = try await api.listCollection(.init(page: 3))
        #expect(last.items.count == 12)
        #expect(last.hasMore == false)

        let vinyl = try await api.listCollection(.init(mediaType: .vinyl, pageSize: 100))
        #expect(vinyl.items.allSatisfy { $0.mediaType == .vinyl })
        #expect(vinyl.total == 10)

        let byTitle = try await api.listCollection(.init(sortBy: "title", sortOrder: "asc", pageSize: 3))
        #expect(byTitle.items.map(\.title) == ["Bulk Item 000", "Bulk Item 001", "Bulk Item 002"])
    }

    @Test("Add, patch with explicit nulls, and delete round-trip")
    func mutateItem() async throws {
        let api = freshClient(items: [])
        let created = try await api.addToCollection(CollectionItemCreate(
            mediaType: .vinyl, externalId: "x1", title: "Test Record", imageUrl: nil,
            metadata: ["label": .string("Mock")], rating: 4, status: "owned"))
        #expect(created.rating == 4)
        #expect(created.addedByName == "Tess Tester")

        let cleared = try await api.updateCollectionItem(created.id, fields: ["rating": .null, "notes": .string("hi")])
        #expect(cleared.rating == nil, "Explicit null must clear the rating")
        #expect(cleared.notes == "hi")
        #expect(cleared.status == "owned", "Untouched fields stay put")

        try await api.deleteCollectionItem(created.id)
        let page = try await api.listCollection()
        #expect(page.total == 0)

        do {
            _ = try await api.collectionItem(created.id)
            Issue.record("Deleted item should 404")
        } catch {}
    }

    @Test("Adding the same external id twice is rejected")
    func duplicateAdd() async throws {
        let api = freshClient()
        do {
            _ = try await api.addToCollection(CollectionItemCreate(
                mediaType: .vinyl, externalId: "discogs-rumours", title: "Dup", imageUrl: nil, metadata: [:]))
            Issue.record("Expected a 409")
        } catch let error as APIError {
            guard case .http(let status, _) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect(status == 409)
        }
    }

    @Test("Search routes by type and matches title or subtitle")
    func search() async throws {
        let api = freshClient()
        let vinyl = try await api.search(.vinyl, query: "fleetwood")
        #expect(vinyl.results.count == 3)
        #expect(vinyl.results.allSatisfy { $0.mediaType == "vinyl" })

        let books = try await api.search(.audiobook, query: "martin")
        #expect(books.results.count == 3, "Audiobooks share the books endpoint")

        let none = try await api.search(.show, query: "zzzz")
        #expect(none.results.isEmpty)
    }

    @Test("Covers are served through the shared session, which AsyncImage uses")
    func coversViaSharedSession() async throws {
        _ = freshClient()
        let url = try #require(URL(string: MockFixtures.cover("andor")))
        let (data, response) = try await URLSession.shared.data(from: url)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(UIImage(data: data) != nil, "Cover bytes should decode as an image")
        #expect(MockStore.shared.requestLog.contains("GET /covers/andor.png"))
    }

    @Test("Server URL normalization")
    func serverConfig() {
        ServerConfig.urlString = "rj-server:8080/"
        #expect(ServerConfig.apiBaseURL?.absoluteString == "http://rj-server:8080/api/v1")
        ServerConfig.urlString = "https://shelf.example.com/api/v1/"
        #expect(ServerConfig.apiBaseURL?.absoluteString == "https://shelf.example.com/api/v1")
        ServerConfig.urlString = "   "
        #expect(ServerConfig.isConfigured == false)
    }
}

@Suite(.serialized)
@MainActor
struct ShelfModelAgainstMock {

    @Test("Loads a page, then loads more from the last row")
    func paging() async {
        let api = freshClient(items: MockFixtures.bulk(60))
        let model = ShelfModel(api: api)
        await model.loadIfEmpty()
        #expect(model.items.count == 24)
        #expect(model.total == 60)

        model.loadMoreIfNeeded(current: model.items[0])
        #expect(model.items.count == 24, "Only the last row should trigger more")

        model.loadMoreIfNeeded(current: model.items[23])
        #expect(await eventually { model.items.count == 48 })

        model.loadMoreIfNeeded(current: model.items[47])
        #expect(await eventually { model.items.count == 60 })

        model.loadMoreIfNeeded(current: model.items[59])
        try? await Task.sleep(for: .milliseconds(200))
        #expect(model.items.count == 60, "No more pages, no more requests")
    }

    @Test("Changing media type clears the status filter and reloads")
    func typeChangeResetsStatus() async {
        let api = freshClient()
        let model = ShelfModel(api: api)
        await model.loadIfEmpty()
        model.status = .wishlist
        #expect(await eventually { model.items.allSatisfy { $0.status == "wishlist" } && !model.items.isEmpty })

        model.mediaType = .vinyl
        #expect(model.status == nil)
        #expect(await eventually { !model.items.isEmpty && model.items.allSatisfy { $0.mediaType == .vinyl } })
        #expect(model.availableStatuses == MediaType.vinyl.statuses)
    }

    @Test("Search text is debounced and filters by title")
    func searchDebounce() async {
        let api = freshClient()
        let model = ShelfModel(api: api)
        await model.loadIfEmpty()
        let before = MockStore.shared.requestLog.count
        model.searchText = "an"
        model.searchText = "ando"
        model.searchText = "andor"
        #expect(await eventually { model.items.count == 1 && model.items.first?.title == "Andor" })
        let searches = MockStore.shared.requestLog.dropFirst(before).filter { $0 == "GET /collection" }.count
        #expect(searches == 1, "Three keystrokes should produce one request")
    }

    @Test("Edits patch in place and deletes drop the row")
    func replaceAndRemove() async {
        let api = freshClient()
        let model = ShelfModel(api: api)
        await model.loadIfEmpty()
        let original = model.items[0]
        let edited = PreviewData.item("Renamed", original.mediaType, status: original.status)
        model.replace(edited)
        #expect(model.items[0].title == original.title, "Different id must not replace")

        model.remove(id: original.id)
        #expect(!model.items.contains { $0.id == original.id })
        #expect(model.total == MockFixtures.items.count - 1)
    }
}

@Suite(.serialized)
@MainActor
struct RecommendationModelAgainstMock {

    @Test("Seeds from 4+ star vinyl and books, never suggests what's owned")
    func buildsSuggestions() async {
        let api = freshClient()
        let model = RecommendationModel(api: api)
        await model.loadIfNeeded()
        #expect(model.phase == .ready)
        #expect(!model.suggestions.isEmpty)

        let owned = Set(MockFixtures.items.map { $0.title.lowercased() })
        for s in model.suggestions {
            #expect(!owned.contains(s.result.title.lowercased()), "\(s.result.title) is already on the shelf")
            #expect(!s.reason.isEmpty)
        }
        let titles = model.suggestions.map(\.result.title)
        #expect(titles.contains("Fleetwood Mac - Tusk"))
        #expect(titles.contains("Fire & Blood"))
        #expect(!titles.contains("Fleetwood Mac - Rumours"))
    }

    @Test("Interleaves seeds so one artist doesn't fill the row")
    func interleaves() async {
        let api = freshClient()
        let model = RecommendationModel(api: api)
        await model.loadIfNeeded()
        let seeds = model.suggestions.prefix(3).map(\.seedTitle)
        #expect(Set(seeds).count >= 2, "First three should come from at least two seeds: \(seeds)")
    }

    @Test("No ratings and nothing recent to seed from asks for ratings")
    func needsRatings() async {
        let api = freshClient(items: [PreviewData.item("Unrated Movie", .movie, status: "watched")])
        let model = RecommendationModel(api: api)
        await model.loadIfNeeded()
        #expect(model.phase == .needsRatings)
        #expect(model.suggestions.isEmpty)
    }

    @Test("Adding a suggestion posts it with the type's default status")
    func addSuggestion() async {
        let api = freshClient()
        let model = RecommendationModel(api: api)
        await model.loadIfNeeded()
        guard let pick = model.suggestions.first(where: { $0.mediaType == .vinyl }) else {
            Issue.record("No vinyl suggestion to add")
            return
        }
        await model.add(pick)
        #expect(model.addedIDs.contains(pick.id))
        #expect(model.addError == nil)
        let added = MockStore.shared.items.first { $0.title == pick.result.title }
        #expect(added?.status == "owned")
    }
}

}
