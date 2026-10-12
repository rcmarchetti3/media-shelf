// MediaShelfApp.swift
// Entry point. Creates the one AuthStore and hands it to the view tree.
// Replaces frontend/src/main.tsx.

import SwiftUI

@main
struct MediaShelfApp: App {
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .task { await auth.bootstrap() }
        }
    }
}
