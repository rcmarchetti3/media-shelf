// AppTabView.swift
// The four tabs from the brief. Replaces the Sidebar + AppLayout in
// frontend/src/components/layout/.
//
// iPhone Duo moves this tab bar to the side on the outer display. That's the
// system's job; nothing here knows about the hinge. Search uses the system
// search role so it becomes a search field in the bar. Tab selection is
// owned by AppRouter so other screens (Home's plaques) can switch tabs.

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
            Tab(value: .search, role: .search) {
                SearchView()
            }
            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView()
            }
        }
        .environment(router)
    }
}
