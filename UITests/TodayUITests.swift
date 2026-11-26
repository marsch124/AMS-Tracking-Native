import XCTest

/// Screen test for Today, found by identifiers only.
final class TodayUITests: XCTestCase {
    func testTodayShowsTheCards() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["card-h_fast"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["review-week"].exists)
    }
}
