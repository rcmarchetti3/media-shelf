// AppTabView.swift
// The four tabs from the brief. Replaces the Sidebar + AppLayout in
// frontend/src/components/layout/.
//
// iPhone Duo moves this tab bar to the side on the outer display. That's the
// system's job; nothing here knows about the hinge. Search uses the system
// search role so it becomes a search field in the bar.

import SwiftUI

struct AppTabView: View {
    enum Tabs: Hashable { case home, shelf, search, settings }

    @State private var selection: Tabs = .home

    var body: some View {
        TabView(selection: $selection) {
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
    }
}
