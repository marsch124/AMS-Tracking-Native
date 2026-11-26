import XCTest
@testable import AMSTracking

/// One small data test per rule of the review screens (pure functions, fixed days, never Store.shared).
final class ScreensTests: XCTestCase {
    // Thursday 26 Nov 2026: the week that just ended is Mon 16 Nov – Sun 22 Nov.
    let today = "2026-11-26"

    private func days(_ keys: [String]) -> [String: DayMark] { Dictionary(uniqueKeysWithValues: keys.map { ($0, DayMark.all) }) }
    private func ms(_ day: String, _ h: Int, _ m: Int = 0) -> Double {
        let d = DayKey.calendar.date(bySettingHour: h, minute: m, second: 0, of: DayKey.date(day)!)!
        return d.timeIntervalSince1970 * 1000
    }

    func testMonthStatsTile() {
        // Done on 1-10 of November, tracked since 1 Nov, today 20 Nov: 10 of 20 days = 50 %.
        let h = Habit(name: "Read", createdAt: "2026-11-01", done: days((1...10).map { String(format: "2026-11-%02d", $0) }))
        let m = h.monthStats(year: 2026, month: 11, today: "2026-11-20")
        XCTAssertEqual(m, Habit.MonthStats(done: 10, scheduled: 20))
        XCTAssertEqual(h.statTiles(today: "2026-11-20")[2].value, "50%")
        let w = Habit(name: "Gym", type: .weekly, target: 2, createdAt: "2026-11-01", done: days(["2026-11-03", "2026-11-05"]))
        XCTAssertEqual(w.statTiles(today: "2026-11-20")[2].value, "2×")
    }

    func testRhythmCircularMean() {
        // Starts at 23:30 and 00:30 average to midnight (a plain mean would say noon).
        var sessions: [Session] = []
        for i in 0..<6 {
            let day = DayKey.add("2026-11-01", days: i)
            let start = i % 2 == 0 ? ms(day, 23, 30) : ms(DayKey.add(day, days: 1), 0, 30)
            sessions.append(Session(s: start, e: start + 16 * 3_600_000))
        }
        let h = Habit(name: "Fast", type: .timer, sessions: sessions)
        let r = h.fastRhythm()
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.usualStart, "00:00")
        XCTAssertNil(Habit(name: "Fast", type: .timer, sessions: Array(sessions.prefix(4))).fastRhythm())
    }

    func testWeekdaySlipsNeedsFiveMisses() {
        // Done every day except every Wednesday of the 8 weeks (16 Nov back to 28 Sep) — 8 Wednesdays missed.
        let ins = Insights(data: TrackingData(), today: today)
        var done: [String] = []
        for k in DayKey.keys(from: "2026-09-28", to: today) where DayKey.weekday(k) != 2 { done.append(k) }
        let h = Habit(name: "Stretch", createdAt: "2026-09-01", done: days(done))
        var d = TrackingData(); d.habits = [h]
        let notes = Insights(data: d, today: today).weekNotes()
        XCTAssertTrue(notes.contains { $0.title == "Wednesday is where Stretch slips" })
        // Two Wednesdays only: below the threshold, no note.
        var few: [String] = []
        for k in DayKey.keys(from: "2026-09-28", to: today) where !(DayKey.weekday(k) == 2 && k < "2026-10-12") { few.append(k) }
        var d2 = TrackingData(); d2.habits = [Habit(name: "Stretch", createdAt: "2026-09-01", done: days(few))]
        XCTAssertFalse(Insights(data: d2, today: today).weekNotes().contains { $0.topic == "weekday" })
        _ = ins
    }

    func testWeekSummaryFirstSentence() {
        let h = Habit(name: "Read", createdAt: "2026-11-01", done: days(["2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19", "2026-11-20", "2026-11-21", "2026-11-22"]))
        var d = TrackingData(); d.habits = [h]
        let first = Insights(data: d, today: today).summaryParagraphs().first
        // The dates follow the device's language ("16 November" in Sweden, "November 16" on GitHub's US machines).
        let a = Fmt.dayMonthLong(DayKey.date("2026-11-16")!), b = Fmt.dayMonthLong(DayKey.date("2026-11-22")!)
        XCTAssertEqual(first, "Between \(a) and \(b) you ticked 7 days across 1 habit. Read ran every one of its 7 days. Everything with a target made it.")
    }

    func testSuggestionsExcludeExisting() {
        var d = TrackingData()
        d.habits = [Habit(name: "Read a book"), Habit(name: "Daily walk")]
        let picks = Insights(data: d, today: today).suggestions(12)
        XCTAssertFalse(picks.contains { $0.name == "Read 20 minutes" })
        XCTAssertFalse(picks.contains { $0.name == "Walk 30 minutes" })
        XCTAssertEqual(picks.count, 10)
        XCTAssertEqual(Insights(data: TrackingData(), today: today).suggestions(3).count, 3)
    }

    func testMonthReportBestRunAndPeriod() {
        XCTAssertEqual(MonthReport.lastPeriod(today: "2027-01-05").year, 2026)
        XCTAssertEqual(MonthReport.lastPeriod(today: "2027-01-05").month, 12)
        let h = Habit(name: "Read", createdAt: "2026-09-15", done: days(["2026-10-03", "2026-10-04", "2026-10-05", "2026-10-09"]))
        var d = TrackingData(); d.habits = [h]
        let r = MonthReport.make(d, year: 2026, month: 10, today: today)
        XCTAssertEqual(r.rows.first?.best, 3)
        XCTAssertEqual(r.rows.first?.mid, "4/31 days")
        XCTAssertEqual(r.total, 4)
    }
}
