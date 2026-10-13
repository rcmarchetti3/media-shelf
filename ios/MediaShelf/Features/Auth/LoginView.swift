// LoginView.swift
// Replaces frontend/src/pages/LoginPage.tsx, plus the server URL field the
// web app doesn't need. Same layout at every size: the logo standing on a
// shelf, then a short form.

import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth

    @State private var serverURL = ServerConfig.urlString
    @State private var username = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section("Server") {
                    TextField("http://rj-server:8080", text: $serverURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("login.server")
                    ServerPicker(url: $serverURL)
                }
                .shelfRow()
                Section("Account") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("login.username")
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .accessibilityIdentifier("login.password")
                }
                .shelfRow()
                if let error = auth.lastError {
                    Section {
                        Text(error)
                            .foregroundStyle(Theme.glowDropped)
                            .accessibilityIdentifier("login.error")
                    }
                    .shelfRow()
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isWorking {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSubmit || isWorking)
                    .accessibilityIdentifier("login.submit")
                }
                .shelfRow()
                Section {
                    Button("Create an account") { showRegister = true }
                        .accessibilityIdentifier("login.register")
                }
                .shelfRow()
            }
            .shelfBackground()
            .sheet(isPresented: $showRegister) {
                RegisterView(serverURL: serverURL)
            }
        }
    }

    /// The logo on its own plank, with the wordmark in brass underneath.
    private var header: some View {
        VStack(spacing: 14) {
            AppLogo()
                .frame(width: 64, height: 64)
                .padding(.horizontal, 48)
                .padding(.bottom, ShelfPlank.totalHeight - 2)
                .background(alignment: .bottom) { ShelfPlank() }
            VStack(spacing: 4) {
                Text("MediaShelf")
                    .font(Theme.heading(.largeTitle))
                    .foregroundStyle(Theme.brass)
                Text("Sign in to your household's shelf")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mutedForeground)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var canSubmit: Bool {
        !serverURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.isEmpty && !password.isEmpty
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        ServerConfig.urlString = serverURL
        await auth.signIn(username: username, password: password)
    }
}

#Preview {
    LoginView().environment(AuthStore()).tint(Theme.brass)
}
