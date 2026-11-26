import XCTest

/// Screen tests for Stats and Last week, found by identifiers only.
final class ScreensUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample"]
        app.launch()
        return app
    }

    func testStatsOpensFromToday() {
        let app = launch()
        let stats = app.descendants(matching: .any)["btn-stats"]
        XCTAssertTrue(stats.waitForExistence(timeout: 10))
        stats.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-stats"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["achievements"].exists || app.descendants(matching: .any)["stats-card-h_read"].exists)
    }

    func testLastWeekOpensFromToday() {
        let app = launch()
        let review = app.descendants(matching: .any)["review-week"]
        XCTAssertTrue(review.waitForExistence(timeout: 10))
        review.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-lastweek"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["lw-chart"].exists)
    }
}
