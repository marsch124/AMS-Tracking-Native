import XCTest

/// Screen tests for How it works and What's new, found by identifiers only (iPhone: Settings opens from the floating bar).
final class DocsUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

    func testGuideShowsSigns() {
        let app = launch()
        XCTAssertTrue(element(app, "settings").waitForExistence(timeout: 10))
        element(app, "settings").tap()
        let link = element(app, "btn-guide")
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(element(app, "screen-guide").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "signs").exists)
    }

    func testWhatsNewShowsVersion20() {
        let app = launch()
        XCTAssertTrue(element(app, "settings").waitForExistence(timeout: 10))
        element(app, "settings").tap()
        let link = element(app, "btn-whatsnew")
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(element(app, "screen-whatsnew").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "version-2.0").exists)
    }
}
