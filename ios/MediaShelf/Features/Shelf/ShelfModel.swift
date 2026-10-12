// ShelfModel.swift
// State for the Shelf tab: the filter set and the paged item list.
// Replaces the useSearchParams + apiFetch block in CollectionPage.tsx.
// Any filter change resets to page 1; scrolling near the end loads the next.

import Foundation
import Observation

@MainActor
@Observable
final class ShelfModel {
    enum SortField: String, CaseIterable, Identifiable {
        // Only columns that exist on CollectionItem. The backend falls back
        // to added_at for anything else, so "year" (a metadata key) can't be
        // sorted server-side until the API supports it.
        case addedAt = "added_at", title, rating
        var id: String { rawValue }
        var label: String {
            switch self {
            case .addedAt: "Date Added"
            case .title: "Title"
            case .rating: "Rating"
            }
        }
    }

    // Filters. Setting any of these reloads from page 1.
    var mediaType: MediaType? { didSet { if mediaType != oldValue { status = nil; reload() } } }
    var status: ItemStatus? { didSet { if status != oldValue { reload() } } }
    var favoritesOnly = false { didSet { if favoritesOnly != oldValue { reload() } } }
    var sortField: SortField = .addedAt { didSet { if sortField != oldValue { reload() } } }
    var sortDescending = true { didSet { if sortDescending != oldValue { reload() } } }
    var searchText = "" { didSet { if searchText != oldValue { debouncedReload() } } }

    private(set) var items: [CollectionItem] = []
    private(set) var total = 0
    private(set) var isLoading = false
    var error: String?

    private var page = 1
    private var hasMore = true
    private var loadTask: Task<Void, Never>?
    private let api: APIClient

    init(api: APIClient = .shared) { self.api = api }

    var availableStatuses: [ItemStatus] {
        mediaType?.statuses ?? [.owned, .wishlist, .reading, .inProgress, .completed, .dropped, .watched, .wantToWatch, .watching]
    }

    func loadIfEmpty() async {
        if items.isEmpty { await load(reset: true) }
    }

    func reload() {
        loadTask?.cancel()
        loadTask = Task { await load(reset: true) }
    }

    /// Awaitable version for pull-to-refresh, so the spinner stays until done.
    func refresh() async {
        loadTask?.cancel()
        await load(reset: true)
    }

    private func debouncedReload() {
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await load(reset: true)
        }
    }

    /// Call from the last visible row.
    func loadMoreIfNeeded(current item: CollectionItem) {
        guard hasMore, !isLoading, items.last?.id == item.id else { return }
        loadTask = Task { await load(reset: false) }
    }

    /// After an edit on the detail screen, patch the row in place so the grid
    /// doesn't flash.
    func replace(_ item: CollectionItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item }
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        total = max(0, total - 1)
    }

    private func load(reset: Bool) async {
        if reset { page = 1; hasMore = true }
        isLoading = true
        defer { isLoading = false }
        error = nil
        do {
            let result = try await api.listCollection(.init(
                mediaType: mediaType,
                status: status,
                isFavorite: favoritesOnly ? true : nil,
                q: searchText.isEmpty ? nil : searchText,
                sortBy: sortField.rawValue,
                sortOrder: sortDescending ? "desc" : "asc",
                page: page))
            guard !Task.isCancelled else { return }
            items = reset ? result.items : items + result.items
            total = result.total
            hasMore = result.hasMore
            page += 1
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
