// RecommendationEngine.swift
// On-device ranking with Apple's Foundation Models framework. STUB.
//
// The shape, from the design discussion:
//   1. The backend assembles candidates (TMDB similar, Discogs related,
//      Google Books by author) plus the person's ratings and statuses.
//      That endpoint (/collection/recommendations/candidates) doesn't exist
//      yet; it's the one backend change the iOS app needs.
//   2. The on-device model gets the candidates through a Tool, so it can
//      only rank titles that really exist. It never invents one.
//   3. Output is a @Generable struct, so the score and the reason come back
//      typed, not as free text to parse.
//
// Availability has three states and the UI has to handle all of them; the
// fallback is the server's own ordering, which the web app uses anyway.
//
// Later: adopt the LanguageModel protocol with an Executor that talks to
// Ollama on rj-server, and a DynamicProfile that picks on-device vs server
// based on whether the phone is on Tailscale.

import Foundation

#if canImport(FoundationModels)
import FoundationModels

@Generable(description: "A ranked suggestion for the person's media shelf")
struct Recommendation: Sendable {
    @Guide(description: "The candidate's id exactly as the tool returned it")
    var candidateID: String

    @Guide(description: "How well this fits the person's taste", .range(1...10))
    var score: Int

    @Guide(description: "One short sentence on why, mentioning something they own")
    var reason: String
}

@Generable(description: "The recommendations, best first")
struct RecommendationList: Sendable {
    var items: [Recommendation]
}

/// Placeholder candidate until the backend endpoint exists.
struct Candidate: Codable, Sendable {
    let id: String
    let title: String
    let mediaType: String
    let subtitle: String?
    let relatedTo: String?   // title on the shelf that produced this candidate
}

/// Hands the model the candidate list. The model calls this; it never sees
/// titles any other way.
struct CandidatesTool: Tool {
    let name = "getCandidates"
    let description = "Fetch the list of titles the person might like, with what on their shelf each one relates to"

    @Generable
    struct Arguments {
        @Guide(description: "Media type to fetch candidates for, or 'all'")
        var mediaType: String
    }

    let candidates: [Candidate]

    /// Returns plain text, one candidate per line. A String is the safest
    /// tool output type; richer @Generable outputs can come later.
    func call(arguments: Arguments) async throws -> String {
        candidates
            .filter { arguments.mediaType == "all" || $0.mediaType == arguments.mediaType }
            .map { c in
                var line = "id=\(c.id) | \(c.mediaType) | \(c.title)"
                if let s = c.subtitle { line += " | \(s)" }
                if let r = c.relatedTo { line += " | related to: \(r)" }
                return line
            }
            .joined(separator: "\n")
    }
}

@MainActor
enum RecommendationEngine {
    enum Availability {
        case available
        case appleIntelligenceOff
        case modelNotReady
        case unsupported
    }

    static var availability: Availability {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(.appleIntelligenceNotEnabled): .appleIntelligenceOff
        case .unavailable(.modelNotReady): .modelNotReady
        case .unavailable: .unsupported
        }
    }

    /// Rank candidates on device. Returns nil when the model isn't available
    /// so the caller can fall back to the server's order.
    static func rank(_ candidates: [Candidate], taste: String) async throws -> [Recommendation]? {
        guard availability == .available else { return nil }
        let session = LanguageModelSession(
            tools: [CandidatesTool(candidates: candidates)],
            instructions: """
                You rank media for someone's personal collection. Call getCandidates, \
                then score each candidate against their taste. Only use ids the tool \
                returned. Keep reasons to one sentence.
                """)
        let response = try await session.respond(
            to: "Their taste, in their own words: \(taste). Rank the candidates.",
            generating: RecommendationList.self)
        return response.content.items.sorted { $0.score > $1.score }
    }
}
#endif
