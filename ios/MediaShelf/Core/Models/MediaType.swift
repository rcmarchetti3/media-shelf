// MediaType.swift
// The six media types the backend accepts. Mirrors frontend/src/lib/statuses.ts
// and the regex on CollectionItemCreate in backend/app/schemas/collection.py.

import SwiftUI

enum MediaType: String, Codable, CaseIterable, Identifiable, Sendable {
    case vinyl, movie, show, book, audiobook, documentary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vinyl: "Vinyl"
        case .movie: "Movies"
        case .show: "TV Shows"
        case .book: "Books"
        case .audiobook: "Audiobooks"
        case .documentary: "Documentaries"
        }
    }

    var singular: String {
        switch self {
        case .vinyl: "Record"
        case .movie: "Movie"
        case .show: "TV Show"
        case .book: "Book"
        case .audiobook: "Audiobook"
        case .documentary: "Documentary"
        }
    }

    /// SF Symbol. The brief says to use these, not the web icon set.
    var symbol: String {
        switch self {
        case .vinyl: "opticaldisc"
        case .movie: "film"
        case .show: "tv"
        case .book: "book"
        case .audiobook: "headphones"
        case .documentary: "video"
        }
    }

    /// Which /api/v1/search/{endpoint} serves this type. Several types share
    /// one upstream source, same as the web app's SearchPage.
    var searchEndpoint: String {
        switch self {
        case .vinyl: "vinyl"
        case .book, .audiobook: "books"
        case .movie, .documentary: "movies"
        case .show: "shows"
        }
    }

    var statuses: [ItemStatus] {
        switch self {
        case .vinyl: [.owned, .wishlist]
        case .book, .audiobook: [.reading, .completed, .wishlist, .dropped]
        case .movie, .documentary: [.watched, .wantToWatch]
        case .show: [.watching, .completed, .wantToWatch, .dropped]
        }
    }

    var defaultStatus: ItemStatus {
        switch self {
        case .vinyl: .owned
        case .book, .audiobook: .wishlist
        case .movie, .documentary, .show: .wantToWatch
        }
    }

    /// Cover art aspect ratio. Records are square, everything else is a poster.
    var coverAspect: CGFloat {
        self == .vinyl ? 1 : 2 / 3
    }
}
