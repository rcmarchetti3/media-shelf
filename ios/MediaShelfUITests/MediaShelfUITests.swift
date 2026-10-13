// MediaShelfUITests.swift
// End-to-end flows against the in-process mock backend. Every test launches
// the app with `--mock-server`, so nothing here touches rj-server and the
// shelf starts from the same fixtures every time.
//
// Element lookups use the accessibility identifiers set in the views
// (login.*, home.*, shelf.*, detail.*, search.*, preview.*). On iPhone Duo
// the tab bar can sit on the side and secondary toolbar items fold into a
// "More" menu, so the helpers below look in more than one place.

import XCTest

final class MediaShelfUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launch helpers

    @MainActor
    private func launch(signedIn: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-server"] + (signedIn ? ["--mock-signed-in"] : []) + extra
        app.launch()
        return app
    }

    /// Switch tabs and wait until something that only lives on that tab shows up.
    @MainActor
    private func openTab(_ name: String, in app: XCUIApplication, expecting marker: XCUIElement) {
        let byName = NSPredicate(format: "label == %@ OR identifier == %@", name, name)
        let candidates = [app.tabBars.buttons.matching(byName), app.buttons.matching(byName)]
        for _ in 0..<3 {
            for candidate in candidates where candidate.count > 0 {
                let hittable = candidate.allElementsBoundByIndex.first { $0.isHittable } ?? candidate.firstMatch
                hittable.tap()
                if marker.waitForExistence(timeout: 4) { return }
            }
        }
        XCTFail("Couldn't reach the \(name) tab.\n\(app.debugDescription)")
    }

    /// Scroll a horizontally arranged element into view before tapping it.
    /// `isHittable` throws for offscreen elements, so compare frames instead.
    @MainActor
    private func tapScrollingIntoView(_ element: XCUIElement, neighbor: XCUIElement, in app: XCUIApplication) {
        let screen = app.windows.firstMatch.frame
        var tries = 0
        while !(element.exists && screen.contains(element.frame)), tries < 4 {
            neighbor.swipeLeft()
            tries += 1
        }
        XCTAssertTrue(screen.contains(element.frame), "\(element) never scrolled on screen")
        element.tap()
    }

    /// A button, menu item, or static text with this label, wherever iOS put it.
    @MainActor
    private func anyControl(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR identifier == %@", label, label)).firstMatch
    }

    @MainActor
    private func assertExists(_ element: XCUIElement, timeout: TimeInterval = 8, _ message: String,
                              in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "\(message)\n--- hierarchy ---\n\(app.debugDescription)", file: file, line: line)
    }

    // MARK: Sign in

    @MainActor
    func testSignInWithTestAccount() {
        let app = launch(signedIn: false)
        let username = app.textFields["login.username"]
        assertExists(username, "No username field", in: app)
        username.tap()
        username.typeText("tester")
        let password = app.secureTextFields["login.password"]
        password.tap()
        password.typeText("shelf-tester-2026")
        app.buttons["login.submit"].tap()

        assertExists(app.staticTexts["Welcome back, Tess"], "Home should greet the signed-in tester", in: app)
    }

    @MainActor
    func testWrongPasswordShowsServerError() {
        let app = launch(signedIn: false)
        let username = app.textFields["login.username"]
        assertExists(username, "No username field", in: app)
        username.tap()
        username.typeText("tester")
        let password = app.secureTextFields["login.password"]
        password.tap()
        password.typeText("wrong")
        app.buttons["login.submit"].tap()

        let error = app.staticTexts["login.error"]
        assertExists(error, "No error shown", in: app)
        XCTAssertEqual(error.label, "Incorrect username or password")
    }

    // MARK: Home

    @MainActor
    func testHomeShowsStatsSpotlightAndRecommendations() {
        let app = launch()
        assertExists(app.buttons["home.plaque.vinyl"], "No vinyl plaque", in: app)
        assertExists(app.staticTexts["Welcome back, Tess"], "No greeting", in: app)
        XCTAssertTrue(app.buttons["home.spotlight"].exists, "Newest item should be spotlighted")
        XCTAssertTrue(app.staticTexts["Recently Added"].exists)

        // Recommendations are built from the rated vinyl and books in the fixtures.
        let suggestion = app.buttons["home.suggestion.Fleetwood Mac - Tusk"]
        assertExists(suggestion, timeout: 20, "Tusk should be suggested from Rumours", in: app)
    }

    @MainActor
    func testPlaqueOpensFilteredShelf() {
        let app = launch()
        let plaque = app.buttons["home.plaque.vinyl"]
        assertExists(plaque, "No vinyl plaque", in: app)
        plaque.tap()

        assertExists(app.navigationBars["Vinyl"], "Shelf should be filtered to vinyl", in: app)
        let count = app.staticTexts["shelf.count"]
        assertExists(count, "No count line", in: app)
        XCTAssertTrue(count.label.hasSuffix("records"), "Got: \(count.label)")
        XCTAssertTrue(app.buttons["shelf.item.Fleetwood Mac - Rumours"].exists)
        XCTAssertFalse(app.buttons["shelf.item.Andor"].exists, "TV shows must not appear under Vinyl")
    }

    // MARK: Shelf and detail

    @MainActor
    func testFilterChipsAndDetailEditing() {
        let app = launch()
        openTab("Shelf", in: app, expecting: app.buttons["shelf.chip.all"])
        assertExists(app.buttons["shelf.item.Andor"], "Andor should be on the unfiltered shelf", in: app)

        app.buttons["shelf.chip.show"].tap()
        assertExists(app.navigationBars["TV Shows"], "Chip should filter to shows", in: app)
        XCTAssertFalse(app.buttons["shelf.item.Superbad"].exists)

        app.buttons["shelf.item.Andor"].tap()
        assertExists(app.staticTexts["detail.title"], "Detail didn't open", in: app)

        // Rate it 3 and check the live value.
        let rating = app.otherElements["detail.rating"]
        assertExists(rating, timeout: 3, "No rating control", in: app)
        app.buttons["detail.star.3"].tap()
        XCTAssertTrue(waitForValue(rating, "3 of 5"), "Rating should update right away, got \(String(describing: rating.value))")

        // Tapping the same star again clears it.
        app.buttons["detail.star.3"].tap()
        XCTAssertTrue(waitForValue(rating, "Not rated"))

        // Change status from the chip menu.
        let status = app.buttons["detail.status"]
        XCTAssertTrue(status.exists)
        status.tap()
        let completed = anyControl("Completed", in: app)
        assertExists(completed, timeout: 3, "Status menu didn't open", in: app)
        completed.tap()
        XCTAssertTrue(waitForValue(status, "Completed"))
    }

    @MainActor
    func testLongTitleAndMissingCoverDontBreakTheShelf() {
        let app = launch()
        openTab("Shelf", in: app, expecting: app.buttons["shelf.chip.all"])
        tapScrollingIntoView(app.buttons["shelf.chip.audiobook"], neighbor: app.buttons["shelf.chip.movie"], in: app)
        let longOne = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shelf.item.The Rise and Fall'")).firstMatch
        assertExists(longOne, "Long-titled audiobook missing", in: app)
        XCTAssertTrue(longOne.isHittable)
        longOne.tap()
        assertExists(app.staticTexts["detail.title"], "Detail didn't open", in: app)
    }

    @MainActor
    func testDeleteRemovesFromShelf() {
        let app = launch()
        openTab("Shelf", in: app, expecting: app.buttons["shelf.chip.all"])
        let castleRock = app.buttons["shelf.item.Castle Rock"]
        assertExists(castleRock, "Castle Rock missing", in: app)
        castleRock.tap()
        assertExists(app.staticTexts["detail.title"], "Detail didn't open", in: app)

        // Secondary toolbar actions may be folded into a "More" menu.
        var delete = anyControl("Delete", in: app)
        if !delete.waitForExistence(timeout: 2) {
            let more = app.buttons["More"].firstMatch
            assertExists(more, timeout: 3, "Neither Delete nor More in the toolbar", in: app)
            more.tap()
            delete = anyControl("Delete", in: app)
        }
        assertExists(delete, timeout: 3, "No Delete action", in: app)
        delete.tap()
        let confirm = anyControl("Remove", in: app)
        assertExists(confirm, timeout: 3, "No confirmation", in: app)
        confirm.tap()

        assertExists(app.buttons["shelf.item.Andor"], "Should be back on the shelf", in: app)
        XCTAssertFalse(app.buttons["shelf.item.Castle Rock"].exists)
    }

    // MARK: Search

    /// The Search tab is a search field in the tab bar on iOS 26. Tapping the
    /// tab presents it; what kind of element it is varies, so look for any
    /// text entry whose placeholder is the "Search vinyl" prompt.
    @MainActor
    private func openSearch(in app: XCUIApplication) -> XCUIElement {
        let prompt = NSPredicate(format: "placeholderValue BEGINSWITH 'Search' OR label BEGINSWITH 'Search '")
        let field = app.descendants(matching: .any)
            .matching(NSPredicate(format: "elementType == %d OR elementType == %d",
                                  XCUIElement.ElementType.searchField.rawValue,
                                  XCUIElement.ElementType.textField.rawValue))
            .matching(prompt)
            .firstMatch

        let byName = NSPredicate(format: "label == 'Search' OR identifier == 'Search'")
        for _ in 0..<3 {
            let tab = app.buttons.matching(byName).allElementsBoundByIndex.first { $0.isHittable }
                ?? app.buttons.matching(byName).firstMatch
            tab.tap()
            if field.waitForExistence(timeout: 4) { return field }
            // Some builds need a second tap to focus the presented field.
            if app.searchFields.firstMatch.waitForExistence(timeout: 1) { return app.searchFields.firstMatch }
        }
        XCTFail("Couldn't find the search field after opening the Search tab.\n\(app.debugDescription)")
        return field
    }

    @MainActor
    func testSearchAndAddToShelf() {
        let app = launch()
        let field = openSearch(in: app)
        field.tap()
        field.typeText("Tusk")

        let result = app.buttons["search.result.Fleetwood Mac - Tusk"]
        assertExists(result, "No Tusk result", in: app)
        result.tap()

        let add = app.buttons["preview.add"]
        assertExists(add, "No Add button", in: app)
        XCTAssertEqual(add.label, "Add to shelf")
        add.tap()
        XCTAssertTrue(waitForLabel(add, "On your shelf"))
        XCTAssertFalse(add.isEnabled)
    }

    @MainActor
    func testOwnedResultIsMarked() {
        let app = launch()
        let field = openSearch(in: app)
        field.tap()
        field.typeText("Rumours")
        let owned = app.buttons["search.result.Fleetwood Mac - Rumours"]
        assertExists(owned, "No Rumours result", in: app)
        XCTAssertTrue(waitForValue(owned, "On your shelf"), "Got: \(String(describing: owned.value))")
        let notOwned = app.buttons["search.result.Fleetwood Mac - Tusk"]
        if notOwned.exists {
            XCTAssertEqual(notOwned.value as? String, "Not on your shelf")
        }
    }

    // MARK: Empty state and sign out

    @MainActor
    func testEmptyShelfStates() {
        let app = launch(extra: ["--mock-empty"])
        assertExists(app.staticTexts["Nothing on the shelf yet. Search to add something."], "No empty Home state", in: app)
        openTab("Shelf", in: app, expecting: app.buttons["shelf.chip.all"])
        assertExists(app.staticTexts["Empty shelf"], "No empty Shelf state", in: app)
    }

    @MainActor
    func testSignOutReturnsToLogin() {
        let app = launch()
        openTab("Settings", in: app, expecting: app.buttons["settings.signOut"])
        app.buttons["settings.signOut"].tap()
        assertExists(app.textFields["login.username"], "Should land on sign in", in: app)
    }

    // MARK: Helpers

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ expected: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expected)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, _ expected: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expected)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
    }
}
