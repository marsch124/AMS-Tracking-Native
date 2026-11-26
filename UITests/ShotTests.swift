import XCTest

/// Pictures of every screen with the made-up sample data, by day and by night — for looking, not for checking.
/// Runs only when asked: `TEST_RUNNER_SHOTS=1 xcodebuild test … -only-testing:AMSTrackingUITests/ShotTests`.
final class ShotTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SHOTS"] != nil, "pictures only on request")
        continueAfterFailure = true
    }

    func testDay() { walk("light") }
    func testNight() { walk("dark") }

    private func walk(_ mode: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample", "-\(mode)"]
        app.launch()
        let any = app.descendants(matching: .any)
        _ = any["card-h_fast"].waitForExistence(timeout: 10)
        shot(app, "\(mode)-01-today")
        let wide = any["sidebar-today"].exists

        func back() {
            if wide { return }
            let b = app.navigationBars.buttons.element(boundBy: 0)
            if b.exists { b.tap() }
        }
        func open(_ id: String) { if wide, let s = sidebar(id) { any[s].tap() } else { any[id].tap() } }

        any["card-h_fast"].tap()
        _ = any["screen-detail"].waitForExistence(timeout: 5)
        shot(app, "\(mode)-02-detail-fast")
        app.swipeUp(); shot(app, "\(mode)-03-detail-fast-2")
        app.swipeUp(); shot(app, "\(mode)-04-detail-fast-3")
        app.swipeUp(); shot(app, "\(mode)-05-detail-fast-4")
        back()
        any["card-h_parts"].tap()
        _ = any["screen-detail"].waitForExistence(timeout: 5)
        shot(app, "\(mode)-06-detail-parts")
        back()

        open("btn-stats"); _ = any["screen-stats"].waitForExistence(timeout: 5)
        shot(app, "\(mode)-07-stats"); app.swipeUp(); shot(app, "\(mode)-08-stats-2"); app.swipeUp(); shot(app, "\(mode)-09-stats-3")
        back()
        open("review-week"); _ = any["screen-lastweek"].waitForExistence(timeout: 5)
        shot(app, "\(mode)-10-lastweek"); app.swipeUp(); shot(app, "\(mode)-11-lastweek-2"); app.swipeUp(); shot(app, "\(mode)-12-lastweek-3")
        app.swipeUp(); shot(app, "\(mode)-13-lastweek-4")
        back()
        open("review-month"); _ = any["screen-lastmonth"].waitForExistence(timeout: 5)
        shot(app, "\(mode)-14-lastmonth"); back()
        if wide { any["sidebar-aspirations"].tap() } else {
            any["btn-stats"].tap(); _ = any["btn-asp"].waitForExistence(timeout: 5); any["btn-asp"].tap()
        }
        _ = any["screen-aspirations"].waitForExistence(timeout: 5)
        shot(app, "\(mode)-15-aspirations"); back(); back()

        open("settings"); _ = any["app-version"].waitForExistence(timeout: 5)
        shot(app, "\(mode)-16-settings"); app.swipeUp(); shot(app, "\(mode)-17-settings-2")
        if any["btn-guide"].exists { any["btn-guide"].tap(); _ = any["screen-guide"].waitForExistence(timeout: 5); shot(app, "\(mode)-18-guide")
            if any["signs"].exists { any["signs"].tap(); shot(app, "\(mode)-19-signs") }
            app.navigationBars.buttons.element(boundBy: 0).tap() }
        if any["btn-whatsnew"].exists { any["btn-whatsnew"].tap(); _ = any["screen-whatsnew"].waitForExistence(timeout: 5); shot(app, "\(mode)-20-whatsnew")
            app.navigationBars.buttons.element(boundBy: 0).tap() }
        if any["btn-settings-done"].firstMatch.exists { any["btn-settings-done"].firstMatch.tap() }
        if wide { any["sidebar-today"].tap() }
        _ = any["btn-add"].waitForExistence(timeout: 5)
        any["btn-add"].tap(); _ = any["f-name"].waitForExistence(timeout: 5)
        shot(app, "\(mode)-21-add"); app.swipeUp(); shot(app, "\(mode)-22-add-2")
    }

    private func sidebar(_ id: String) -> String? {
        ["btn-stats": "sidebar-stats", "review-week": "sidebar-lastWeek", "review-month": "sidebar-lastMonth",
         "settings": "sidebar-settings"][id]
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
