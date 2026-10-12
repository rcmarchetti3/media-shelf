// SettingsView.swift
// The Settings tab. Replaces frontend/src/pages/SettingsPage.tsx.
// Plain Form, no design needed. Theme toggle is dropped on purpose: iOS
// follows the system setting. Household admin lists users; editing roles is
// on the not-done list.

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

                Section {
                    TextField("Server URL", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            guard serverURL != ServerConfig.urlString else { return }
                            ServerConfig.urlString = serverURL
                            Task { await auth.signOut() }
                        }
                } header: {
                    Text("Server")
                } footer: {
                    Text("Changing the server signs you out.")
                }

                if auth.user?.isAdmin == true {
                    Section("Household") {
                        if users.isEmpty {
                            Text("Loading…").foregroundStyle(.secondary)
                        }
                        ForEach(users) { u in
                            LabeledContent(u.displayName) {
                                Text(u.role.capitalized).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let message {
                    Section { Text(message).foregroundStyle(.secondary) }
                }

                Section {
                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                } footer: {
                    if let user = auth.user {
                        Text("Signed in as \(user.username) on \(ServerConfig.urlString)")
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await load() }
        }
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
