// AppRouter.swift
// Cross-tab navigation. Lives in the environment from AppTabView down so a
// screen in one tab can send the user to another, like the web's sidebar
// links from the dashboard into /collection?media_type=vinyl.
//
// Requests carry a fresh id so tapping the same plaque twice still fires;
// the Shelf tab remembers which id it last handled.

import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable { case home, shelf, search, settings }

    struct ShelfRequest: Equatable {
        let id = UUID()
        /// Nil means the whole collection.
        let mediaType: MediaType?
    }

    var tab: Tab = .home
    private(set) var shelfRequest: ShelfRequest?

    /// Switch to the Shelf tab filtered to one media type (or everything).
    func showShelf(_ mediaType: MediaType?) {
        shelfRequest = ShelfRequest(mediaType: mediaType)
        tab = .shelf
    }
}
