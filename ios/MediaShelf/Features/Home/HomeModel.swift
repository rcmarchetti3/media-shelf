// HomeModel.swift
// State for the Home tab: stats plus the most recent items.
// Replaces the two apiFetch calls at the top of DashboardPage.tsx.

import Foundation
import Observation

@MainActor
@Observable
final class HomeModel {
    private(set) var stats: CollectionStats?
    private(set) var recent: [CollectionItem] = []
    private(set) var isLoading = false
    var error: String?

    private let api: APIClient

    init(api: APIClient = .shared) { self.api = api }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        do {
            async let stats = api.collectionStats()
            async let recent = api.listCollection(.init(sortBy: "added_at", sortOrder: "desc", pageSize: 12))
            self.stats = try await stats
            self.recent = try await recent.items
        } catch {
            self.error = error.localizedDescription
        }
    }
}
