// RecommendationModel.swift
// "You might like" on Home. Builds candidates on the phone, then ranks them.
//
// The design calls for a backend endpoint that assembles candidates
// (/collection/recommendations/candidates). It doesn't exist yet, so this
// does the next best thing with what the API already has:
//
//   1. Seeds: things you rated 4 or 5 stars (falling back to recent adds).
//   2. Candidates: for each seed, search the same source by the creator.
//      Discogs by artist (from "Artist - Title"), Google Books by author.
//      TMDB can't search by director, so movies and shows don't seed yet.
//   3. Filter out anything already on the shelf.
//   4. Rank: Apple Intelligence on device via RecommendationEngine when it's
//      available, with a one-line reason per pick. Otherwise, seed order.
//
// Results are cached for the session; pull to refresh on Home rebuilds them.

import Foundation
import Observation

struct Suggestion: Identifiable, Hashable, Sendable {
    let result: SearchResult
    let mediaType: MediaType
    let seedTitle: String
    var reason: String

    var id: String { result.id }
}

@MainActor
@Observable
final class RecommendationModel {
    enum Phase: Equatable {
        case idle
        case loading
        case needsRatings
        case ready
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var suggestions: [Suggestion] = []
    /// True once the on-device model has ordered the list and written reasons.
    private(set) var rankedOnDevice = false
    private(set) var addedIDs: Set<String> = []
    var addError: String?

    private let api: APIClient
    private var loadTask: Task<Void, Never>?

    init(api: APIClient = .shared) { self.api = api }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await load()
    }

    func refresh() async {
        loadTask?.cancel()
        await load()
    }

    /// Put a suggestion on the shelf with the default status for its type.
    func add(_ suggestion: Suggestion) async {
        do {
            _ = try await api.addToCollection(CollectionItemCreate(
                mediaType: suggestion.mediaType,
                externalId: suggestion.result.externalId,
                title: suggestion.result.title,
                imageUrl: suggestion.result.imageUrl,
                metadata: suggestion.result.metadata,
                status: suggestion.mediaType.defaultStatus.rawValue))
            addedIDs.insert(suggestion.id)
        } catch {
            addError = error.localizedDescription
        }
    }

    // MARK: Pipeline

    private func load() async {
        phase = .loading
        rankedOnDevice = false
        do {
            async let ratedPage = api.listCollection(.init(sortBy: "rating", sortOrder: "desc", pageSize: 24))
            async let recentPage = api.listCollection(.init(sortBy: "added_at", sortOrder: "desc", pageSize: 24))
            let (rated, recent) = try await (ratedPage.items, recentPage.items)

            var seen = Set<UUID>()
            let owned = (rated + recent).filter { seen.insert($0.id).inserted }

            var seeds = owned.filter { ($0.rating ?? 0) >= 4 && $0.lookup != nil }
            if seeds.isEmpty { seeds = recent.filter { $0.lookup != nil } }
            seeds = Array(seeds.prefix(6))
            guard !seeds.isEmpty else {
                suggestions = []
                phase = .needsRatings
                return
            }

            let ownedTitles = Set(owned.map { Self.normalize($0.title) })
            let ownedExternalIDs = Set(owned.compactMap(\.externalId))

            var picked: [Suggestion] = []
            var pickedIDs = Set<String>()
            for seed in seeds {
                guard let lookup = seed.lookup else { continue }
                guard let page = try? await api.search(lookup.type, query: lookup.query) else { continue }
                try Task.checkCancellation()
                let fresh = page.results.filter { result in
                    !ownedExternalIDs.contains(result.externalId)
                        && !ownedTitles.contains(Self.normalize(result.title))
                        && Self.normalize(result.title) != Self.normalize(seed.title)
                        && !pickedIDs.contains(result.id)
                }
                for result in fresh.prefix(3) {
                    pickedIDs.insert(result.id)
                    picked.append(Suggestion(
                        result: result, mediaType: seed.mediaType, seedTitle: seed.title,
                        reason: Self.heuristicReason(for: seed, lookup: lookup)))
                }
            }

            // Interleave seeds so one prolific artist doesn't fill the row.
            suggestions = Self.interleaved(picked, by: \.seedTitle)
            phase = .ready

            await rankOnDevice(seeds: seeds)
        } catch is CancellationError {
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Let Apple Intelligence reorder and explain, if it's on and ready.
    private func rankOnDevice(seeds: [CollectionItem]) async {
        #if canImport(FoundationModels)
        guard !suggestions.isEmpty, RecommendationEngine.availability == .available else { return }
        let candidates = suggestions.map {
            Candidate(id: $0.id, title: $0.result.title, mediaType: $0.mediaType.rawValue,
                      subtitle: $0.result.subtitle, relatedTo: $0.seedTitle)
        }
        let taste = seeds.map { seed in
            "\(seed.title) (\(seed.mediaType.singular.lowercased())\(seed.rating.map { ", \($0) stars" } ?? ""))"
        }.joined(separator: "; ")

        guard let ranked = try? await RecommendationEngine.rank(candidates, taste: taste) else { return }
        var byID = Dictionary(uniqueKeysWithValues: suggestions.map { ($0.id, $0) })
        var ordered: [Suggestion] = []
        for pick in ranked {
            guard var s = byID.removeValue(forKey: pick.candidateID) else { continue }
            if !pick.reason.isEmpty { s.reason = pick.reason }
            ordered.append(s)
        }
        ordered.append(contentsOf: byID.values)   // anything the model skipped
        suggestions = ordered
        rankedOnDevice = true
        #endif
    }

    // MARK: Helpers

    private static func normalize(_ title: String) -> String {
        title.lowercased()
            .replacingOccurrences(of: "(deluxe edition)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func heuristicReason(for seed: CollectionItem, lookup: CollectionItem.Lookup) -> String {
        if let rating = seed.rating, rating >= 4 {
            return "More from \(lookup.query), since you gave \(seed.title) \(rating) stars"
        }
        return "More from \(lookup.query), like \(seed.title)"
    }

    /// Round-robin across groups so the row alternates between seeds.
    private static func interleaved<Key: Hashable>(_ items: [Suggestion], by key: KeyPath<Suggestion, Key>) -> [Suggestion] {
        var groups: [[Suggestion]] = []
        var index: [Key: Int] = [:]
        for item in items {
            let k = item[keyPath: key]
            if let i = index[k] { groups[i].append(item) } else { index[k] = groups.count; groups.append([item]) }
        }
        var out: [Suggestion] = []
        var round = 0
        while out.count < items.count {
            for group in groups where round < group.count { out.append(group[round]) }
            round += 1
        }
        return out
    }
}

private extension CollectionItem {
    struct Lookup {
        let type: MediaType
        let query: String
    }

    /// What to search to find siblings of this item, if its source supports it.
    var lookup: Lookup? {
        switch mediaType {
        case .vinyl:
            if let artist = metadata["artists"]?.displayString ?? metadata["artist"]?.displayString,
               !artist.isEmpty {
                return Lookup(type: .vinyl, query: artist)
            }
            // Discogs titles come as "Artist - Title".
            let parts = title.components(separatedBy: " - ")
            guard parts.count >= 2, let artist = parts.first, artist.count >= 2 else { return nil }
            return Lookup(type: .vinyl, query: artist)
        case .book, .audiobook:
            guard let author = firstString(for: "authors") ?? metadata["author"]?.displayString,
                  !author.isEmpty else { return nil }
            return Lookup(type: mediaType, query: author)
        case .movie, .documentary, .show:
            return nil
        }
    }

    private func firstString(for key: String) -> String? {
        if case .array(let values)? = metadata[key], case .string(let s)? = values.first { return s }
        return metadata[key]?.displayString
    }
}
