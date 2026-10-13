// PreviewData.swift
// Sample items for SwiftUI previews. Debug builds only; never shipped.

#if DEBUG
import Foundation

enum PreviewData {
    static func item(_ title: String, _ type: MediaType, status: String?, rating: Int? = nil,
                     favorite: Bool = false, image: String? = nil,
                     metadata: [String: JSONValue] = [:]) -> CollectionItem {
        CollectionItem(
            id: UUID(), userId: UUID(), mediaType: type, externalId: nil, title: title,
            imageUrl: image, metadata: metadata, rating: rating, status: status, notes: nil,
            tags: [], isFavorite: favorite, addedAt: .now, updatedAt: .now, addedByName: "Rich")
    }

    static let items: [CollectionItem] = [
        item("Andor", .show, status: "watching", rating: 5, favorite: true,
             image: "https://image.tmdb.org/t/p/w342/59SVNwLfoMnZPPB6ukW6dlPxAdI.jpg",
             metadata: ["overview": .string("Prequel series to Rogue One."), "first_air_date": .string("2022-09-21"),
                        "current_season": .number(2), "total_seasons": .number(2)]),
        item("Fleetwood Mac - Rumours", .vinyl, status: "owned", rating: 5,
             image: "https://i.discogs.com/placeholder-not-real/rumours.jpg",
             metadata: ["label": .string("Warner Bros."), "year": .string("1977"), "genres": .array([.string("Rock")])]),
        item("A Knight of the Seven Kingdoms", .book, status: "completed", rating: 4,
             metadata: ["authors": .array([.string("George R. R. Martin")]), "page_count": .number(368)]),
        item("Superbad", .movie, status: "watched", rating: 3,
             image: "https://image.tmdb.org/t/p/w342/ek8e8txUyUwd2BNqj6lFEerJfbq.jpg"),
        item("Project Hail Mary", .audiobook, status: "reading"),
        item("Castle Rock", .show, status: "dropped"),
        item("Memoirs of a Geisha", .book, status: "wishlist", favorite: true),
        item("Documentary Now!", .documentary, status: "want_to_watch"),
    ]

    static func result(_ title: String, _ type: MediaType, subtitle: String? = nil, year: String? = nil) -> SearchResult {
        SearchResult(externalId: UUID().uuidString, title: title, subtitle: subtitle, imageUrl: nil,
                     mediaType: type.rawValue, year: year, metadata: [:])
    }

    static let suggestions: [Suggestion] = [
        Suggestion(result: result("Fleetwood Mac - Tusk", .vinyl, subtitle: "2×LP", year: "1979"), mediaType: .vinyl,
                   seedTitle: "Fleetwood Mac - Rumours", reason: "More from Fleetwood Mac, since you gave Rumours 5 stars"),
        Suggestion(result: result("Fire & Blood", .book, subtitle: "George R. R. Martin", year: "2018"), mediaType: .book,
                   seedTitle: "A Knight of the Seven Kingdoms", reason: "Another George R. R. Martin book"),
        Suggestion(result: result("Fleetwood Mac - Tango in the Night", .vinyl, year: "1987"), mediaType: .vinyl,
                   seedTitle: "Fleetwood Mac - Rumours", reason: "More from Fleetwood Mac"),
    ]
}
#endif
