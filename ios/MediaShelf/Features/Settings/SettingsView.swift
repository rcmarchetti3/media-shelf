// SettingsView.swift
// The Settings tab. Replaces frontend/src/pages/SettingsPage.tsx.
// Plain Form on the shelf background. Theme toggle is dropped on purpose:
// iOS follows the system setting. Household admin lists users; editing roles
// is on the not-done list.

import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth

    @State private var displayName = ""
    @State private var email = ""
    @State private var serverURL = ServerConfig.urlString
    @State private var users: [UserListItem] = []
    @State private var message: String?
    @State private var isSaving = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display name", text: $displayName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save profile", systemImage: "checkmark") {
                        Task { await saveProfile() }
                    }
                    .disabled(isSaving || !profileChanged)
                }
                .shelfRow()

                Section {
                    TextField("Server URL", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { switchServer(to: serverURL) }
                    ServerPicker(url: $serverURL) { switchServer(to: $0) }
                } header: {
                    Text("Server")
                } footer: {
                    Text("Changing the server signs you out.")
                }
                .shelfRow()

                if auth.user?.isAdmin == true {
                    Section("Household") {
                        if users.isEmpty {
                            Text("Loading…").foregroundStyle(Theme.mutedForeground)
                        }
                        ForEach(users) { u in
                            LabeledContent(u.displayName) {
                                Text(u.role.capitalized).foregroundStyle(Theme.mutedForeground)
                            }
                        }
                    }
                    .shelfRow()
                }

                if let message {
                    Section { Text(message).foregroundStyle(Theme.mutedForeground) }
                        .shelfRow()
                }

                Section {
                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                    .accessibilityIdentifier("settings.signOut")
                } footer: {
                    if let user = auth.user {
                        Text("Signed in as \(user.username) on \(ServerConfig.urlString)")
                    }
                }
                .shelfRow()
            }
            .shelfBackground()
            .navigationTitle("Settings")
            .task { await load() }
        }
    }

    /// A different server means a different account and different tokens,
    /// so switching signs out.
    private func switchServer(to url: String) {
        guard url != ServerConfig.urlString else { return }
        ServerConfig.urlString = url
        Task { await auth.signOut() }
    }

    private var profileChanged: Bool {
        guard let user = auth.user else { return false }
        return displayName != user.displayName || email != user.email
    }

    private func load() async {
        if let user = auth.user {
            displayName = user.displayName
            email = user.email
            if user.isAdmin {
                users = (try? await api.listUsers()) ?? []
            }
        }
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await api.updateProfile(UserUpdateRequest(displayName: displayName, email: email))
            await auth.refreshUser()
            message = "Profile saved."
        } catch {
            message = error.localizedDescription
        }
    }
}
