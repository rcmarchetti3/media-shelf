// RootView.swift
// The auth gate. Replaces the ProtectedRoute logic in frontend/src/App.tsx.

import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        switch auth.state {
        case .checking:
            ProgressView()
        case .signedOut:
            LoginView()
        case .signedIn:
            AppTabView()
        }
    }
}
