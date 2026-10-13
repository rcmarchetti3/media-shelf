// ItemStatus.swift
// Status values stored on a collection item. The backend stores a free string,
// so unknown values decode as `.other`. Glow colors are the web's `.status-*`
// rules: done is green, in progress is blue, wishlist is magenta, dropped is
// red, owned is a faint brass.

import SwiftUI

enum ItemStatus: Hashable, Sendable {
    case owned, wishlist, reading, inProgress, completed, dropped
    case watched, wantToWatch, watching
    case other(String)

    init(rawValue: String) {
        switch rawValue {
        case "owned": self = .owned
        case "wishlist": self = .wishlist
        case "reading": self = .reading
        case "in_progress": self = .inProgress
        case "completed": self = .completed
        case "dropped": self = .dropped
        case "watched": self = .watched
        case "want_to_watch": self = .wantToWatch
        case "watching": self = .watching
        default: self = .other(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .owned: "owned"
        case .wishlist: "wishlist"
        case .reading: "reading"
        case .inProgress: "in_progress"
        case .completed: "completed"
        case .dropped: "dropped"
        case .watched: "watched"
        case .wantToWatch: "want_to_watch"
        case .watching: "watching"
        case .other(let s): s
        }
    }

    var label: String {
        switch self {
        case .owned: "Owned"
        case .wishlist: "Wishlist"
        case .reading: "Reading"
        case .inProgress: "In Progress"
        case .completed: "Completed"
        case .dropped: "Dropped"
        case .watched: "Watched"
        case .wantToWatch: "Want to Watch"
        case .watching: "Watching"
        case .other(let s): s.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var symbol: String {
        switch self {
        case .completed, .watched: "checkmark"
        case .reading, .watching, .inProgress: "play.fill"
        case .owned: "circle.fill"
        case .wishlist, .wantToWatch: "heart"
        case .dropped: "xmark"
        case .other: "circle"
        }
    }

    /// The ring and glow around the cover. Nil means no glow (unknown status).
    var glow: Color? {
        switch self {
        case .completed, .watched: Theme.glowCompleted
        case .reading, .watching, .inProgress: Theme.glowInProgress
        case .wishlist, .wantToWatch: Theme.glowWishlist
        case .dropped: Theme.glowDropped.opacity(0.8)
        case .owned: Theme.glowOwned.opacity(0.7)
        case .other: nil
        }
    }

    /// Color for labels and icons that talk about this status.
    var tint: Color {
        glow ?? Theme.mutedForeground
    }
}
