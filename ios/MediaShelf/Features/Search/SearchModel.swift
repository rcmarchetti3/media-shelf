// SearchModel.swift
// State for the Search tab. Replaces the debounced fetch in SearchPage.tsx.
// Type first, then pick a scope (media type); the brief flips the web's order.
//
// Results that are already on the shelf are marked as owned instead of
// offering "Add" again. That needs the shelf's external ids, which are
// loaded once per session (and refreshed after an add).

import Foundation
import Observation

@MainActor
@Observable
final class SearchModel {
    var query = "" { didSet { if query != oldValue { debouncedSearch() } } }
    var mediaType: MediaType = .vinyl { didSet { if mediaType != oldValue { debouncedSearch() } } }

    private(set) var results: [SearchResult] = []
    private(set) var isSearching = false
    private(set) var addedIDs: Set<String> = []
    var error: String?       // search failed
    var addError: String?    // adding one result failed; results stay visible

    /// "source:externalId" for everything on the shelf. Nil until loaded.
    private var ownedKeys: Set<String>?
    private var ownedTask: Task<Void, Never>?

    private var task: Task<Void, Never>?
    private let api: APIClient

    init(api: APIClient = .shared) { self.api = api }

    /// True if the result is on the shelf, whether it was there before this
    /// session or was just added.
    func isOwned(_ result: SearchResult) -> Bool {
        addedIDs.contains(result.id) || (ownedKeys?.contains(Self.key(for: result)) ?? false)
    }

    private func debouncedSearch() {
        task?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; return }
        task = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await search(q)
        }
    }

    private func search(_ q: String) async {
        isSearching = true
        defer { isSearching = false }
        error = nil
        do {
            async let owned: () = loadOwnedIfNeeded()
            let page = try await api.search(mediaType, query: q)
            await owned
            guard !Task.isCancelled else { return }
            results = page.results
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// POST the result to the collection with the default status for its type.
    func add(_ result: SearchResult) async {
        do {
            _ = try await api.addToCollection(CollectionItemCreate(
                mediaType: mediaType,
                externalId: result.externalId,
                title: result.title,
                imageUrl: result.imageUrl,
                metadata: result.metadata,
                status: mediaType.defaultStatus.rawValue))
            addedIDs.insert(result.id)
            ownedKeys?.insert(Self.key(for: result))
        } catch {
            addError = error.localizedDescription
        }
    }

    // MARK: Owned ids

    /// Pages through the shelf once and remembers every external id. Shared
    /// across concurrent searches so it only runs one time.
    private func loadOwnedIfNeeded() async {
        if ownedKeys != nil { return }
        if let ownedTask { return await ownedTask.value }
        let t = Task { [api] in
            var keys = Set<String>()
            var page = 1
            repeat {
                guard let result = try? await api.listCollection(.init(page: page, pageSize: 100)) else { break }
                for item in result.items {
                    if let externalID = item.externalId {
                        keys.insert(Self.key(endpoint: item.mediaType.searchEndpoint, externalID: externalID))
                    }
                }
                if !result.hasMore || page >= 50 { break }
                page += 1
            } while true
            self.ownedKeys = keys
        }
        ownedTask = t
        await t.value
        ownedTask = nil
    }

    /// Audiobooks and books share one source, as do movies and documentaries,
    /// so the key uses the search endpoint rather than the media type.
    private static func key(for result: SearchResult) -> String {
        let endpoint = MediaType(rawValue: result.mediaType)?.searchEndpoint ?? result.mediaType
        return key(endpoint: endpoint, externalID: result.externalId)
    }

    private static func key(endpoint: String, externalID: String) -> String {
        "\(endpoint):\(externalID)"
    }
}
