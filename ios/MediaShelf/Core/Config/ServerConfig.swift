// ServerConfig.swift
// Where the backend lives. The web app bakes this in at build time; the phone
// has to ask, because every household runs the stack somewhere different.
// Stored in UserDefaults; the Settings screen and sign-in screen both edit it.
//
// People usually have two addresses for the same server: one on the home
// network and one through a tunnel. Saved servers remember both so switching
// is a tap, not retyping.

import Foundation

struct SavedServer: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var url: String
}

enum ServerConfig {
    static let defaultsKey = "serverURL"
    static let savedKey = "savedServers"

    /// Raw string as the person typed it, e.g. "http://rj-server:8080".
    static var urlString: String {
        get { UserDefaults.standard.string(forKey: defaultsKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    /// Normalized base URL for /api/v1. Nil until the person sets one.
    static var apiBaseURL: URL? { apiBaseURL(from: urlString) }

    static var isConfigured: Bool { apiBaseURL != nil }

    /// Turns whatever someone typed into the /api/v1 base URL.
    ///
    /// With no scheme, local addresses get http (home servers rarely have
    /// certificates) and everything else gets https. That matters for tunnels:
    /// Cloudflare answers plain http with a redirect, and a redirected POST
    /// to /auth/login can lose its body.
    static func apiBaseURL(from input: String) -> URL? {
        var raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        if !raw.contains("://") { raw = (isLocalAddress(raw) ? "http://" : "https://") + raw }
        while raw.hasSuffix("/") { raw.removeLast() }
        if raw.hasSuffix("/api/v1") { raw.removeLast("/api/v1".count) }
        return URL(string: raw + "/api/v1")
    }

    /// Hosts that are only reachable from the same network: bare names like
    /// `rj-server`, `.local`, loopback, link-local, private IPv4 ranges, and
    /// Tailscale's 100.64/10.
    static func isLocalAddress(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = (URLComponents(string: "http://" + trimmed)?.host ?? trimmed).lowercased()
        if host == "localhost" || host.hasSuffix(".local") || !host.contains(".") { return true }
        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4 else { return false }
        switch (octets[0], octets[1]) {
        case (10, _), (127, _), (192, 168), (169, 254), (172, 16...31), (100, 64...127): return true
        default: return false
        }
    }

    // MARK: Saved servers

    static var savedServers: [SavedServer] {
        get {
            guard let data = UserDefaults.standard.data(forKey: savedKey),
                  let list = try? JSONDecoder().decode([SavedServer].self, from: data)
            else { return [] }
            return list
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: savedKey)
        }
    }

    /// Saves a server, replacing any entry that points at the same address.
    @discardableResult
    static func save(name: String, url: String) -> SavedServer? {
        guard let target = apiBaseURL(from: url) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = SavedServer(name: trimmed.isEmpty ? defaultName(for: url) : trimmed,
                                url: url.trimmingCharacters(in: .whitespacesAndNewlines))
        var list = savedServers.filter { apiBaseURL(from: $0.url) != target }
        list.append(entry)
        savedServers = list
        return entry
    }

    static func remove(_ server: SavedServer) {
        savedServers = savedServers.filter { $0.id != server.id }
    }

    /// The saved entry that points at `url`, if any.
    static func savedServer(for url: String) -> SavedServer? {
        guard let target = apiBaseURL(from: url) else { return nil }
        return savedServers.first { apiBaseURL(from: $0.url) == target }
    }

    /// "Home network" or "Remote", the two names most people want.
    static func defaultName(for url: String) -> String {
        isLocalAddress(url) ? "Home network" : "Remote"
    }
}
