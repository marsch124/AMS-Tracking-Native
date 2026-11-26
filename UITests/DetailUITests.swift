import XCTest

/// Screen test for a habit's page, found by identifiers only.
final class DetailUITests: XCTestCase {
    func testFastingHabitPageOpensFromToday() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample"]
        app.launch()
        let card = app.descendants(matching: .any)["card-h_fast"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-detail"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["calendar-card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["cal-prev"].exists)
    }
}
