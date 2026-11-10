//
//  PreSlabUITestsLaunchTests.swift
//  PreSlabUITests
//
//  Created by Cole Zill on 11/1/26.
//

import XCTest

final class PreSlabUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        XCTAssertTrue(app.buttons["practiceSampleButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["startupLoading"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["startupError"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Library after startup"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
