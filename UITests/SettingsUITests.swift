import XCTest

final class SettingsUITests: XCTestCase {
    func testSettingsShowsVersion() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample"]
        app.launch()
        app.descendants(matching: .any)["settings"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["app-version"].waitForExistence(timeout: 10))
    }

    func testAddOpensTheHabitForm() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample"]
        app.launch()
        app.descendants(matching: .any)["btn-add"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["f-name"].waitForExistence(timeout: 10))
    }
}
