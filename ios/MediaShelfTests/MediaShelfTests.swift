// MediaShelfTests.swift
// Pure model tests: no network, no Keychain, no shared state. These run in
// parallel with everything else.

import Foundation
import Testing
@testable import MediaShelf

struct ItemStatusTests {
    @Test("Every known raw value round-trips")
    func rawValuesRoundTrip() {
        for raw in ["owned", "wishlist", "reading", "in_progress", "completed", "dropped", "watched", "want_to_watch", "watching"] {
            let status = ItemStatus(rawValue: raw)
            #expect(status.rawValue == raw)
            if case .other = status { Issue.record("\(raw) decoded as .other") }
        }
    }

    @Test("Unknown statuses survive as .other with a readable label")
    func unknownStatus() {
        let status = ItemStatus(rawValue: "on_loan_to_sam")
        #expect(status.rawValue == "on_loan_to_sam")
        #expect(status.label == "On Loan To Sam")
        #expect(status.glow == nil)
    }

    @Test("Glow semantics match the web: done green, in progress blue, wishlist magenta, dropped red")
    func glowGroups() {
        #expect(ItemStatus.completed.glow == ItemStatus.watched.glow)
        #expect(ItemStatus.reading.glow == ItemStatus.watching.glow)
        #expect(ItemStatus.wishlist.glow == ItemStatus.wantToWatch.glow)
        #expect(ItemStatus.completed.glow != ItemStatus.dropped.glow)
    }
}

struct MediaTypeTests {
    @Test("Statuses per type match statuses.ts")
    func statusesPerType() {
        #expect(MediaType.vinyl.statuses == [.owned, .wishlist])
        #expect(MediaType.book.statuses == [.reading, .completed, .wishlist, .dropped])
        #expect(MediaType.audiobook.statuses == MediaType.book.statuses)
        #expect(MediaType.movie.statuses == [.watched, .wantToWatch])
        #expect(MediaType.documentary.statuses == MediaType.movie.statuses)
        #expect(MediaType.show.statuses == [.watching, .completed, .wantToWatch, .dropped])
    }

    @Test("Default status is in the type's own list")
    func defaultStatusIsValid() {
        for type in MediaType.allCases {
            #expect(type.statuses.contains(type.defaultStatus), "\(type) defaults to a status it doesn't offer")
        }
    }

    @Test("Search endpoints collapse onto the four backend routes")
    func searchEndpoints() {
        #expect(Set(MediaType.allCases.map(\.searchEndpoint)) == ["vinyl", "books", "movies", "shows"])
    }

    @Test("Square covers for discs, portrait for everything else")
    func coverAspects() {
        #expect(MediaType.vinyl.coverAspect == 1)
        #expect(MediaType.audiobook.coverAspect == 1)
        for type in [MediaType.book, .movie, .show, .documentary] {
            #expect(type.coverAspect < 1)
        }
    }
}

struct JSONValueTests {
    private let decoder = JSONDecoder()

    @Test("Decodes the shapes the backend actually sends")
    func decodesMixedMetadata() throws {
        let json = #"{"year": "1977", "page_count": 368, "vote_average": 7.5, "genres": ["Rock", "Pop"], "ok": true, "gone": null}"#
        let value = try decoder.decode([String: JSONValue].self, from: Data(json.utf8))
        #expect(value["year"] == .string("1977"))
        #expect(value["page_count"] == .number(368))
        #expect(value["vote_average"]?.displayString == "7.5")
        #expect(value["page_count"]?.displayString == "368")
        #expect(value["genres"]?.displayString == "Rock, Pop")
        #expect(value["ok"]?.displayString == "Yes")
        #expect(value["gone"] == .null)
        #expect(value["gone"]?.displayString == nil)
    }

    @Test("intValue reads numbers and numeric strings, nothing else")
    func intValue() {
        #expect(JSONValue.number(3).intValue == 3)
        #expect(JSONValue.string("12").intValue == 12)
        #expect(JSONValue.string("twelve").intValue == nil)
        #expect(JSONValue.bool(true).intValue == nil)
    }

    @Test("Empty strings and objects don't render as rows")
    func emptyValuesHide() {
        #expect(JSONValue.string("").displayString == nil)
        #expect(JSONValue.object(["a": .string("b")]).displayString == nil)
        #expect(JSONValue.array([]).displayString == nil)
    }
}

struct APIErrorTests {
    @Test("FastAPI validation errors join their messages")
    func validationBody() throws {
        let json = #"{"detail": [{"loc": ["body", "username"], "msg": "field required"}, {"msg": "too short"}]}"#
        let body = try JSONDecoder().decode(FastAPIErrorBody.self, from: Data(json.utf8))
        #expect(body.message == "field required\ntoo short")
    }

    @Test("Plain detail strings pass through")
    func stringBody() throws {
        let body = try JSONDecoder().decode(FastAPIErrorBody.self, from: Data(#"{"detail": "Nope"}"#.utf8))
        #expect(body.message == "Nope")
        #expect(APIError.http(status: 400, detail: body.message).errorDescription == "Nope")
    }

    @Test("Status-only errors still say something")
    func statusOnly() {
        #expect(APIError.http(status: 503, detail: nil).errorDescription == "Server returned 503.")
    }
}

struct CollectionItemTests {
    @Test("Shows fall back to TMDB's seasons_count for the total")
    func seasonsFallback() {
        let item = PreviewData.item("Test", .show, status: "watching",
                                    metadata: ["seasons_count": .number(4), "current_season": .string("2")])
        #expect(item.currentSeason == 2)
        #expect(item.totalSeasons == 4)
    }

    @Test("Bad image URLs don't crash, they go nil")
    func imageURL() {
        let bad = PreviewData.item("Test", .book, status: nil, image: "not a url at all ://")
        #expect(bad.imageURL == nil)
        let good = PreviewData.item("Test", .book, status: nil, image: "https://example.com/a.jpg")
        #expect(good.imageURL?.host() == "example.com")
    }
}

@MainActor
struct AppRouterTests {
    @Test("Showing the shelf switches tabs and issues a fresh request every time")
    func showShelf() {
        let router = AppRouter()
        #expect(router.tab == .home)
        router.showShelf(.vinyl)
        let first = router.shelfRequest
        #expect(router.tab == .shelf)
        #expect(first?.mediaType == .vinyl)

        router.showShelf(.vinyl)
        #expect(router.shelfRequest?.id != first?.id, "Repeat taps must still fire")

        router.showShelf(nil)
        #expect(router.shelfRequest?.mediaType == nil)
    }
}
