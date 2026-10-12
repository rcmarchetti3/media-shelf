// LoginView.swift
// Replaces frontend/src/pages/LoginPage.tsx, plus the server URL field the
// web app doesn't need. Same layout at every size: a short centered form.

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
                Section("Server") {
                    TextField("http://rj-server:8080", text: $serverURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Account") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                if let error = auth.lastError {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
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
                }
                Section {
                    Button("Create an account") { showRegister = true }
                }
            }
            .navigationTitle("MediaShelf")
            .sheet(isPresented: $showRegister) {
                RegisterView(serverURL: serverURL)
            }
        }
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
    LoginView().environment(AuthStore())
}
