import XCTest

final class PreSlabUITests: XCTestCase {
    @MainActor
    func testSavedAssessmentCanStoreGradingEconomics() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        saveSample(app)
        app.buttons["assessmentRow"].firstMatch.tap()
        XCTAssertTrue(app.buttons["assessmentCostsButton"].waitForExistence(timeout: 5))
        app.buttons["assessmentCostsButton"].tap()
        XCTAssertTrue(app.buttons["saveGradingCostsButton"].waitForExistence(timeout: 5))
        app.buttons["saveGradingCostsButton"].tap()
        XCTAssertTrue(app.buttons["deleteAssessmentButton"].waitForExistence(timeout: 5))
        deleteFromDetail(app)
    }

    @MainActor
    func testSavedAssessmentCanBeNamedAndOrganized() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        saveSample(app)
        app.buttons["assessmentRow"].firstMatch.tap()
        XCTAssertTrue(app.buttons["organizeAssessmentButton"].waitForExistence(timeout: 5))
        app.buttons["organizeAssessmentButton"].tap()
        let name = app.textFields["cardNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Test Charizard")
        app.buttons["saveOrganizerButton"].tap()
        XCTAssertTrue(app.navigationBars["Test Charizard"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Test Charizard"].waitForExistence(timeout: 5))
        deleteFirstRow(app)
    }

    @MainActor
    func testSampleCardCanBeMeasuredSavedComparedAndDeleted() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        saveSample(app)
        saveSample(app)

        app.buttons["compareToggle"].tap()
        let rows = app.buttons.matching(identifier: "assessmentRow")
        XCTAssertEqual(rows.count, 2)
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()
        app.buttons["compareSelectedButton"].tap()
        XCTAssertTrue(app.staticTexts["notAGradeLabel"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        deleteFirstRow(app)
        deleteFirstRow(app)
        XCTAssertTrue(app.buttons["practiceSampleButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCenteringBaselinesAcrossGradersAndCompare() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // Drive to Summary with real sample front/back findings.
        reachSummary(app)
        assertBaselinesInSummary(app)
        app.buttons["saveAssessmentButton"].tap()
        XCTAssertTrue(app.buttons["assessmentRow"].waitForExistence(timeout: 5))

        // Second sample for Compare.
        saveSample(app)
        app.buttons["compareToggle"].tap()
        let rows = app.buttons.matching(identifier: "assessmentRow")
        XCTAssertEqual(rows.count, 2)
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()
        app.buttons["compareSelectedButton"].tap()
        XCTAssertTrue(app.staticTexts["notAGradeLabel"].waitForExistence(timeout: 5))
        // Switch grader in Compare and observe compact baseline lines.
        for name in ["BGS", "CGC", "TAG", "PSA"] {
            let btn = app.segmentedControls.buttons[name]
            if btn.waitForExistence(timeout: 3) { btn.tap() }
            XCTAssertTrue(app.descendants(matching: .any)["baselineCompact"].firstMatch.waitForExistence(timeout: 5))
            app.swipeUp()
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        deleteFirstRow(app)
        deleteFirstRow(app)
    }

    @MainActor
    private func reachSummary(_ app: XCUIApplication) {
        let practice = app.buttons["practiceSampleButton"]
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        practice.tap()
        XCTAssertTrue(app.descendants(matching: .any)["photoUsable"].waitForExistence(timeout: 20))
        app.buttons["continueToCenteringButton"].tap()
        XCTAssertTrue(app.staticTexts["centeringRatioHorizontal"].waitForExistence(timeout: 5))
        app.buttons["centeringContinueButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["photoUsable"].waitForExistence(timeout: 10))
        app.buttons["continueToCenteringButton"].tap()
        XCTAssertTrue(app.staticTexts["centeringRatioHorizontal"].waitForExistence(timeout: 5))
        app.buttons["centeringContinueButton"].tap()
        XCTAssertTrue(app.staticTexts["notAGradeLabel"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func assertBaselinesInSummary(_ app: XCUIApplication) {
        // Scroll (multi-frame) until baselines card is visible.
        var found = false
        for _ in 0..<8 {
            if app.descendants(matching: .any)["centeringBaselines"].exists { found = true; break }
            app.swipeUp()
        }
        XCTAssertTrue(found, "Centering baselines card not found after scrolling")
        XCTAssertTrue(app.descendants(matching: .any)["baselineSummary"].waitForExistence(timeout: 5))

        // PSA (default), then each grader; CGC/TAG also switch category.
        let profiles: [(String, Bool)] = [("PSA", false), ("BGS", false), ("CGC", true), ("TAG", true)]
        for (name, hasCategory) in profiles {
            let btn = app.segmentedControls.buttons[name]
            XCTAssertTrue(btn.waitForExistence(timeout: 5), "Grader button \(name) missing")
            btn.tap()
            XCTAssertTrue(app.descendants(matching: .any)["baselineSummary"].waitForExistence(timeout: 5))
            if hasCategory {
                for cat in ["Sports", "TCG"] {
                    let catBtn = app.segmentedControls.buttons[cat]
                    if catBtn.waitForExistence(timeout: 3) { catBtn.tap() }
                    XCTAssertTrue(app.descendants(matching: .any)["baselineSummary"].waitForExistence(timeout: 5))
                }
            }
            // Expandable grades list for this grader.
            let disclosure = app.buttons["All \(name) grades"]
            if disclosure.waitForExistence(timeout: 3) {
                disclosure.tap()
                app.swipeUp()
                app.swipeDown()
            }
            // Source link present (observed, not tapped — leaves app).
            let link = app.links.containing(NSPredicate(format: "label CONTAINS %@", "Official \(name) standards")).firstMatch
            XCTAssertTrue(link.waitForExistence(timeout: 5) || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Official \(name) standards")).firstMatch.waitForExistence(timeout: 2))
            // Scroll responsiveness: several swipes, UI still responds.
            app.swipeUp(); app.swipeUp(); app.swipeDown()
            XCTAssertTrue(app.descendants(matching: .any)["baselineSummary"].exists)
        }
    }

    @MainActor
    private func saveSample(_ app: XCUIApplication) {
        let practice = app.buttons["practiceSampleButton"]
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        practice.tap()

        let usable = app.descendants(matching: .any)["photoUsable"]
        XCTAssertTrue(usable.waitForExistence(timeout: 20))
        app.buttons["continueToCenteringButton"].tap()

        let horizontal = app.staticTexts["centeringRatioHorizontal"]
        XCTAssertTrue(horizontal.waitForExistence(timeout: 5))
        XCTAssertTrue(horizontal.label.contains("/"), "Expected a left/right ratio, got \(horizontal.label)")

        let handle = app.otherElements["leftBorderHandle"]
        if handle.waitForExistence(timeout: 2) {
            let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = start.withOffset(CGVector(dx: 30, dy: 0))
            start.press(forDuration: 0.1, thenDragTo: end)
        }

        app.buttons["centeringContinueButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["photoUsable"].waitForExistence(timeout: 10))
        app.buttons["continueToCenteringButton"].tap()
        XCTAssertTrue(app.staticTexts["centeringRatioHorizontal"].waitForExistence(timeout: 5))
        app.buttons["centeringContinueButton"].tap()

        XCTAssertTrue(app.staticTexts["notAGradeLabel"].waitForExistence(timeout: 5))
        app.buttons["saveAssessmentButton"].tap()
        XCTAssertTrue(app.buttons["assessmentRow"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func deleteFirstRow(_ app: XCUIApplication) {
        app.buttons["assessmentRow"].firstMatch.tap()
        deleteFromDetail(app)
    }

    @MainActor
    private func deleteFromDetail(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["deleteAssessmentButton"].waitForExistence(timeout: 5))
        app.buttons["deleteAssessmentButton"].tap()
    }
}
