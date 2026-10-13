// AppTabView.swift
// The four tabs from the brief. Replaces the Sidebar + AppLayout in
// frontend/src/components/layout/.
//
// iPhone Duo moves this tab bar to the side on the outer display. That's the
// system's job; nothing here knows about the hinge. Tab selection is owned
// by AppRouter so other screens (Home's plaques) can switch tabs.
//
// Search is a standard tab, not the `.search` role. The role's tab-bar
// search field never rendered on the Duo's side-mounted bar, so the Search
// screen shows its own field at the top instead (the HIG's "standard tab"
// style). Works the same on every iPhone.

import SwiftUI

struct AppTabView: View {
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView()
            }
            Tab("Shelf", systemImage: "books.vertical", value: .shelf) {
                ShelfView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: .search) {
                SearchView()
            }
            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView()
            }
        }
        .environment(router)
    }
}
