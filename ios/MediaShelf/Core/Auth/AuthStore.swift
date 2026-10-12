// AuthStore.swift
// Replaces frontend/src/lib/auth.tsx. Owns "who's signed in" for the whole app.
// Injected once at the root with .environment(authStore) and read anywhere
// with @Environment(AuthStore.self).

import Foundation
import Observation

@MainActor
@Observable
final class AuthStore {
    enum State: Equatable {
        case checking          // app just launched, asking /auth/me
        case signedOut
        case signedIn(User)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.checking, .checking), (.signedOut, .signedOut): true
            case (.signedIn(let a), .signedIn(let b)): a.id == b.id
            default: false
            }
        }
    }

    private(set) var state: State = .checking
    var lastError: String?

    var user: User? {
        if case .signedIn(let u) = state { return u }
        return nil
    }

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    /// Called once on launch. If there's a refresh token and a server, try to
    /// resume the session; otherwise land on sign in.
    func bootstrap() async {
        await api.setSessionExpiredHandler { [weak self] in
            Task { @MainActor in self?.state = .signedOut }
        }
        guard ServerConfig.isConfigured, await api.hasSession else {
            state = .signedOut
            return
        }
        do {
            state = .signedIn(try await api.me())
        } catch {
            await api.signOut()
            state = .signedOut
        }
    }

    func signIn(username: String, password: String) async {
        lastError = nil
        do {
            _ = try await api.login(username: username, password: password)
            state = .signedIn(try await api.me())
        } catch {
            lastError = error.localizedDescription
        }
    }

    func register(_ request: RegisterRequest) async {
        lastError = nil
        do {
            _ = try await api.register(request)
            state = .signedIn(try await api.me())
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() async {
        await api.signOut()
        state = .signedOut
    }

    /// Re-fetch /auth/me after a profile edit.
    func refreshUser() async {
        if let u = try? await api.me() { state = .signedIn(u) }
    }
}
