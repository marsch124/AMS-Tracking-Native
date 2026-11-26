import XCTest
@testable import AMSTracking

/// One small test per rule of a habit's page (Lane A).
final class DetailTests: XCTestCase {
    private let today = "2026-11-26"

    func testDayCycleDoneSkipEmpty() {
        var h = Habit(name: "Reading")
        h.cycleHistoryDay("2026-11-10"); XCTAssertNotNil(h.done["2026-11-10"]); XCTAssertFalse(h.skip.contains("2026-11-10"))
        h.cycleHistoryDay("2026-11-10"); XCTAssertNil(h.done["2026-11-10"]); XCTAssertTrue(h.skip.contains("2026-11-10"))
        h.cycleHistoryDay("2026-11-10"); XCTAssertNil(h.done["2026-11-10"]); XCTAssertFalse(h.skip.contains("2026-11-10"))
    }

    func testFastingCalendarCells() {
        func ms(_ s: String) -> Double {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm"
            return f.date(from: s)!.timeIntervalSince1970 * 1000
        }
        var h = Habit(name: "Fast", type: .timer, goalHours: 16)
        h.sessions = [Session(s: ms("2026-11-23 19:00"), e: ms("2026-11-24 12:00")),   // 17 h: met
                      Session(s: ms("2026-11-24 22:00"), e: ms("2026-11-25 10:00")),   // 12 h: short
                      Session(s: ms("2026-11-25 20:00"), e: nil)]                       // running
        h.skip = ["2026-11-20"]
        let now = DayKey.date("2026-11-26")!.addingTimeInterval(8 * 3600)
        XCTAssertEqual(h.fastCell("2026-11-24", today: today, now: now), .met(17))
        XCTAssertEqual(h.fastCell("2026-11-25", today: today, now: now), .under(12))
        XCTAssertEqual(h.fastCell("2026-11-26", today: today, now: now), .running(12))
        XCTAssertEqual(h.fastCell("2026-11-20", today: today, now: now), .skip)
        XCTAssertEqual(h.fastCell("2026-11-19", today: today, now: now), .empty)
        XCTAssertEqual(h.fastTap("2026-11-20"), .removeSkip)
        XCTAssertEqual(h.fastTap("2026-11-19"), .recordHours)
        XCTAssertEqual(h.fastTap("2026-11-25"), .editFast(start: h.sessions[1].s))
    }

    func testSkipRangeLimits() {
        XCTAssertNil(SkipRange.validate(from: "2026-11-01", to: "2026-11-01"))
        XCTAssertNotNil(SkipRange.validate(from: nil, to: "2026-11-01"))
        XCTAssertEqual(SkipRange.validate(from: "2026-11-05", to: "2026-11-01"), "The last day must not be before the first day.")
        XCTAssertNil(SkipRange.validate(from: "2026-01-01", to: "2026-04-02"))      // 92 days
        XCTAssertNotNil(SkipRange.validate(from: "2026-01-01", to: "2026-04-03"))   // 93 days
        var h = Habit(name: "x"); h.done["2026-11-02"] = .all; h.skip = ["2026-11-03"]
        XCTAssertEqual(SkipRange.newSkips(h, from: "2026-11-01", to: "2026-11-04"), ["2026-11-01", "2026-11-04"])
        XCTAssertEqual(SkipRange.message(days: 1, habits: 1), "1 day skipped")
        XCTAssertEqual(SkipRange.message(days: 3, habits: 2), "3 days skipped for 2 habits")
    }

    func testHoursValidationAndNoonRecord() {
        XCTAssertEqual(FastHours.parse("15,5"), 15.5)
        XCTAssertNil(FastHours.parse("0")); XCTAssertNil(FastHours.parse("48.5")); XCTAssertNil(FastHours.parse("abc"))
        XCTAssertEqual(FastHours.presets(goal: 16), [16, 13, 15, 18])
        XCTAssertEqual(FastHours.presets(goal: nil), [13, 15, 16, 18])
        let s = FastHours.session(hours: 16, day: "2026-11-10")!
        XCTAssertEqual(DayKey.key(s.end!), "2026-11-10")
        XCTAssertEqual(Fmt.clock(s.end!), "12:00")
        XCTAssertEqual((s.e! - s.s) / 3_600_000, 16)
    }

    func testFastEditMessages() {
        let now = DayKey.date(today)!.addingTimeInterval(12 * 3600)
        let h = 3600.0
        XCTAssertEqual(FastEdit.validate(start: nil, end: nil, running: true, now: now), "Please enter a valid start time.")
        XCTAssertEqual(FastEdit.validate(start: now.addingTimeInterval(2 * h), end: nil, running: true, now: now), "The start can't be in the future.")
        XCTAssertNil(FastEdit.validate(start: now.addingTimeInterval(-5 * h), end: nil, running: true, now: now))
        XCTAssertEqual(FastEdit.validate(start: now.addingTimeInterval(-5 * h), end: nil, running: false, now: now), "Please enter a valid end time.")
        XCTAssertEqual(FastEdit.validate(start: now.addingTimeInterval(-5 * h), end: now.addingTimeInterval(-6 * h), running: false, now: now), "The end must be after the start.")
        XCTAssertEqual(FastEdit.validate(start: now.addingTimeInterval(-60 * h), end: now.addingTimeInterval(-5 * h), running: false, now: now), "A fast can be at most 48 hours.")
        XCTAssertEqual(FastEdit.validate(start: now.addingTimeInterval(-5 * h), end: now.addingTimeInterval(2 * h), running: false, now: now), "The end can't be in the future.")
        XCTAssertNil(FastEdit.validate(start: now.addingTimeInterval(-17 * h), end: now.addingTimeInterval(-1 * h), running: false, now: now))
    }

    func testMonthGridMondayFirstAndTwelveMonthLimit() {
        let g = MonthGrid(containing: DayKey.date("2026-11-15")!)   // 1 Nov 2026 is a Sunday
        XCTAssertEqual(g.lead, 6); XCTAssertEqual(g.count, 30)
        XCTAssertTrue(MonthGrid.canGoNext(from: DayKey.date("2027-10-01")!, today: today))
        XCTAssertFalse(MonthGrid.canGoNext(from: DayKey.date("2027-11-01")!, today: today))
    }

    func testYearsAndPixelToast() {
        var h = Habit(name: "Reading", createdAt: "2024-01-01")
        h.done["2024-05-05"] = .all; h.done["2026-11-01"] = .all; h.skip = ["2026-11-02"]; h.notes["2026-11-01"] = "chapter 4"
        XCTAssertEqual(h.yearsShown(today: today), [2026, 2024])
        XCTAssertEqual(h.pixel("2026-11-01", today: today), .done)
        XCTAssertEqual(h.pixel("2026-11-02", today: today), .skip)
        XCTAssertEqual(h.pixel("2026-11-27", today: today), .future)
        XCTAssertTrue(h.pixelToast("2026-11-01", today: today).hasSuffix("— done · chapter 4"))
        XCTAssertTrue(h.pixelToast("2026-11-03", today: today).hasSuffix("— not done"))
    }

    func testFastStats() {
        var h = Habit(name: "Fast", type: .timer, goalHours: 16)
        let hr = 3_600_000.0
        h.sessions = [Session(s: 0, e: 10 * hr), Session(s: 100 * hr, e: 120 * hr)]
        let st = h.fastStats
        XCTAssertEqual(st.total, 2); XCTAssertEqual(st.longest, 20 * hr); XCTAssertEqual(st.average, 15 * hr)
    }
}
