//
//  FocusForestUITests.swift
//  FocusForestAdventureUITests
//
//  UI + accessibility audit tests.
//

import XCTest

final class FocusForestUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipSplashDelay"]
        app.launch()
    }

    func testHappyPathHomeToAdventureSelect() throws {
        let letsGo = app.buttons["Let's Go!"]
        if letsGo.waitForExistence(timeout: 5) { letsGo.tap() }

        let adventureButton = app.buttons["Adventure!"]
        XCTAssertTrue(adventureButton.waitForExistence(timeout: 5))
        adventureButton.tap()

        XCTAssertTrue(app.staticTexts["Choose Your Adventure!"].waitForExistence(timeout: 5))
        // All seven adventures visible.
        for title in ["ABC", "Numbers", "Shapes", "Colors", "Memory", "Listening", "Animals"] {
            XCTAssertTrue(app.buttons["\(title) adventure"].exists, "\(title) card missing")
        }
    }

    func testParentGateBlocksChildren() throws {
        let letsGo = app.buttons["Let's Go!"]
        if letsGo.waitForExistence(timeout: 5) { letsGo.tap() }

        app.buttons["Grown-ups area"].tap()
        XCTAssertTrue(app.staticTexts["Set your parent PIN"].waitForExistence(timeout: 5)
                   || app.staticTexts["Enter your parent PIN"].exists,
                   "Parent area must always be PIN gated")
    }

    func testAccessibilityAuditOnHome() throws {
        let letsGo = app.buttons["Let's Go!"]
        if letsGo.waitForExistence(timeout: 5) { letsGo.tap() }
        _ = app.buttons["Adventure!"].waitForExistence(timeout: 5)

        // Xcode 15+ built-in accessibility audit (contrast, labels, touch targets…)
        try app.performAccessibilityAudit(for: [.dynamicType, .sufficientElementDescription])
    }

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
