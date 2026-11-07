import XCTest

final class PreSlabUITests: XCTestCase {
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
        XCTAssertTrue(app.buttons["deleteAssessmentButton"].waitForExistence(timeout: 5))
        app.buttons["deleteAssessmentButton"].tap()
    }
}
