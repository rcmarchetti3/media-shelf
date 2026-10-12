// ServerConfig.swift
// Where the backend lives. The web app bakes this in at build time; the phone
// has to ask, because every household runs the stack somewhere different.
// Stored in UserDefaults; the Settings screen and sign-in screen both edit it.

import Foundation

enum ServerConfig {
    static let defaultsKey = "serverURL"

    /// Raw string as the person typed it, e.g. "http://rj-server:8080".
    static var urlString: String {
        get { UserDefaults.standard.string(forKey: defaultsKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    /// Normalized base URL for /api/v1. Nil until the person sets one.
    static var apiBaseURL: URL? {
        var raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        if !raw.contains("://") { raw = "http://" + raw }
        while raw.hasSuffix("/") { raw.removeLast() }
        if raw.hasSuffix("/api/v1") { raw.removeLast("/api/v1".count) }
        return URL(string: raw + "/api/v1")
    }

    static var isConfigured: Bool { apiBaseURL != nil }
}
