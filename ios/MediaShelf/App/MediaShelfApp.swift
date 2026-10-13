// MediaShelfApp.swift
// Entry point. Creates the one AuthStore and hands it to the view tree.
// Replaces frontend/src/main.tsx.

import SwiftUI

@main
struct MediaShelfApp: App {
    @State private var auth = AuthStore()

    /// True when this process is the host for the unit test bundle. The
    /// tests drive APIClient and the Keychain themselves, so the app must
    /// not sign in or load anything behind their backs. UI tests launch a
    /// separate process without this variable, so they still get the real app.
    private static var isHostingUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        #if DEBUG
        // `--mock-server` swaps the backend for an in-process fake so the app
        // and its tests can run without rj-server. See MockServer.swift.
        MockServer.installIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if Self.isHostingUnitTests {
                Text("Running unit tests")
                    .foregroundStyle(.secondary)
            } else {
                RootView()
                    .environment(auth)
                    // Brass is the one brand color system controls pick up.
                    .tint(Theme.brass)
                    // The design system is a dark wood library, same as the web
                    // app, which is dark only. Light tokens exist in Theme if
                    // this is ever lifted; delete this line and they take over.
                    .preferredColorScheme(.dark)
                    .task { await auth.bootstrap() }
            }
        }
    }
}
