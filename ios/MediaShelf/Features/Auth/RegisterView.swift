// RegisterView.swift
// Replaces frontend/src/pages/RegisterPage.tsx. Presented as a sheet from
// sign in. The first account on a server becomes admin, same as the web.

import SwiftUI

struct RegisterView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let serverURL: String

    @State private var username = ""
    @State private var email = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Display name", text: $displayName)
                        .textContentType(.name)
                    SecureField("Password (6+ characters)", text: $password)
                        .textContentType(.newPassword)
                } footer: {
                    Text("Registering on \(serverURL.isEmpty ? "your server" : serverURL).")
                }
                if let error = auth.lastError {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", systemImage: "checkmark") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit || isWorking)
                }
            }
        }
    }

    private var canSubmit: Bool {
        username.count >= 3 && email.contains("@") && !displayName.isEmpty && password.count >= 6
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        ServerConfig.urlString = serverURL
        await auth.register(RegisterRequest(
            username: username, email: email, password: password, displayName: displayName))
        if auth.user != nil { dismiss() }
    }
}
