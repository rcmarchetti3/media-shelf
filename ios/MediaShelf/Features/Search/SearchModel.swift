// SearchModel.swift
// State for the Search tab. Replaces the debounced fetch in SearchPage.tsx.
// Type first, then pick a scope (media type); the brief flips the web's order.

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

    private var task: Task<Void, Never>?
    private let api: APIClient

    init(api: APIClient = .shared) { self.api = api }

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
            let page = try await api.search(mediaType, query: q)
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
        } catch {
            addError = error.localizedDescription
        }
    }
}
