import XCTest

final class CenteringEditorUITests: XCTestCase {
    @MainActor
    func testArtworkPlacementSurvivesReleaseModeSwitchAndZoom() throws {
        let app = openEditor()
        let handle = app.descendants(matching: .any)["leftBorderHandle"].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let initial = try fraction(handle)
        drag(handle, dx: -35, dy: 0)
        let placed = try fraction(handle)
        XCTAssertLessThan(placed, initial)
        XCTAssertLessThan(placed, 0.1, "The line should remain in the photo margin after release.")
        XCTAssertEqual(app.staticTexts["centeringRatioHorizontal"].label, "—")
        app.segmentedControls.buttons["Card edges"].tap()
        app.segmentedControls.buttons["Artwork border"].tap()
        XCTAssertEqual(try fraction(handle), placed, accuracy: 0.00001)
        app.buttons["centeringZoomIn"].tap()
        XCTAssertEqual(try fraction(handle), placed, accuracy: 0.00001)
        app.buttons["centeringResetZoom"].tap()
        XCTAssertEqual(try fraction(handle), placed, accuracy: 0.00001)
        app.buttons["Reset detected lines"].tap()
        XCTAssertEqual(try fraction(handle), initial, accuracy: 0.00001)
    }

    @MainActor
    func testZoomPanAndResetDoNotChangeMeasurements() throws {
        let app = openEditor()
        let horizontal = app.staticTexts["centeringRatioHorizontal"].label
        let vertical = app.staticTexts["centeringRatioVertical"].label
        let canvas = app.descendants(matching: .any)["cardEditorCanvas"].firstMatch
        canvas.pinch(withScale: 1.8, velocity: 1)
        XCTAssertNotEqual(app.staticTexts["centeringZoomLevel"].label, "1.0×")
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.65))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -30, dy: -20)))
        app.buttons["centeringResetZoom"].tap()
        XCTAssertEqual(app.staticTexts["centeringZoomLevel"].label, "1.0×")
        XCTAssertEqual(app.staticTexts["centeringRatioHorizontal"].label, horizontal)
        XCTAssertEqual(app.staticTexts["centeringRatioVertical"].label, vertical)
    }

    @MainActor
    func testZoomedDragMovesOneBorderAndKeepsItAfterZoomReset() throws {
        let app = openEditor()
        app.buttons["centeringZoomIn"].tap()
        let left = app.descendants(matching: .any)["leftBorderHandle"].firstMatch
        let right = app.descendants(matching: .any)["rightBorderHandle"].firstMatch
        let before = try fraction(left)
        let other = try fraction(right)
        drag(left, dx: 4, dy: 0)
        let after = try fraction(left)
        XCTAssertGreaterThan(after, before)
        XCTAssertEqual(try fraction(right), other, accuracy: 0.00001)
        app.buttons["centeringResetZoom"].tap()
        XCTAssertEqual(try fraction(left), after, accuracy: 0.00001)
    }

    @MainActor
    func testCardCornerSurvivesReleaseAndZoomReset() throws {
        let app = openEditor()
        app.segmentedControls.buttons["Card edges"].tap()
        app.buttons["centeringZoomIn"].tap()
        let handle = app.descendants(matching: .any)["cornerTopLeft"].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let before = try XCTUnwrap(handle.value as? String)
        drag(handle, dx: 6, dy: 6)
        let placed = try XCTUnwrap(handle.value as? String)
        XCTAssertNotEqual(placed, before)
        app.buttons["centeringResetZoom"].tap()
        XCTAssertEqual(handle.value as? String, placed)
        app.segmentedControls.buttons["Artwork border"].tap()
        app.segmentedControls.buttons["Card edges"].tap()
        XCTAssertEqual(handle.value as? String, placed)
    }

    @MainActor
    private func openEditor() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        let sample = app.buttons["practiceSampleButton"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        sample.tap()
        XCTAssertTrue(app.buttons["continueToCenteringButton"].waitForExistence(timeout: 20))
        app.buttons["continueToCenteringButton"].tap()
        XCTAssertTrue(app.staticTexts["centeringRatioHorizontal"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func fraction(_ handle: XCUIElement) throws -> Double {
        try XCTUnwrap(Double(try XCTUnwrap(handle.value as? String)))
    }

    @MainActor
    private func drag(_ handle: XCUIElement, dx: CGFloat, dy: CGFloat) {
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)))
    }
}
