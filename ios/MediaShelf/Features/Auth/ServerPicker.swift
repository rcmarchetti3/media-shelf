// ServerPicker.swift
// A menu of saved servers plus "save this one". Used on the sign-in screen
// and in Settings, so the home address and the tunnel address are both one
// tap away.

import SwiftUI

struct ServerPicker: View {
    @Binding var url: String
    /// Called after a saved server is chosen, so Settings can sign out and switch.
    var onSelect: (String) -> Void = { _ in }

    @State private var servers = ServerConfig.savedServers
    @State private var showSave = false
    @State private var newName = ""

    private var current: SavedServer? { ServerConfig.savedServer(for: url) }
    private var canSave: Bool { current == nil && ServerConfig.apiBaseURL(from: url) != nil }

    var body: some View {
        Menu {
            if servers.isEmpty {
                Text("No saved servers yet")
            }
            ForEach(servers) { server in
                Button {
                    url = server.url
                    onSelect(server.url)
                } label: {
                    Label(server.name, systemImage: server.id == current?.id ? "checkmark" : "server.rack")
                }
            }
            Divider()
            if canSave {
                Button("Save this server…", systemImage: "plus") {
                    newName = ServerConfig.defaultName(for: url)
                    showSave = true
                }
            }
            if let current {
                Button("Forget \(current.name)", systemImage: "trash", role: .destructive) {
                    ServerConfig.remove(current)
                    servers = ServerConfig.savedServers
                }
            }
        } label: {
            Label(current?.name ?? "Saved servers", systemImage: "externaldrive.connected.to.line.below")
        }
        .accessibilityIdentifier("server.picker")
        .alert("Save server", isPresented: $showSave) {
            TextField("Name", text: $newName)
            Button("Save") {
                ServerConfig.save(name: newName, url: url)
                servers = ServerConfig.savedServers
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(url)
        }
    }
}
