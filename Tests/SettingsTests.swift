import XCTest
@testable import AMSTracking

final class SettingsTests: XCTestCase {
    private func local(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Double {
        DayKey.calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!.timeIntervalSince1970 * 1000
    }
    private let now = DayKey.calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 12))!

    func testCSVFieldQuoting() {
        XCTAssertEqual(CSVExport.field("plain"), "plain")
        XCTAssertEqual(CSVExport.field("a;b"), "\"a;b\"")
        XCTAssertEqual(CSVExport.field("say \"hi\""), "\"say \"\"hi\"\"\"")
    }

    func testCSVDaysAndFasts() {
        var h = Habit(id: "a", name: "Read; more", type: .daily)
        h.done["2026-11-01"] = .all
        h.skip = ["2026-11-02"]
        h.notes["2026-11-03"] = "travel"
        var f = Habit(id: "f", name: "Fast", type: .timer)
        f.sessions = [Session(s: local(2026, 11, 1, 20, 0), e: local(2026, 11, 2, 12, 15)), Session(s: local(2026, 11, 3, 20, 0), e: nil)]
        XCTAssertEqual(CSVExport.daysCSV([h, f]),
                       "date;habit;type;status;parts;note\n2026-11-01;\"Read; more\";daily;done;;\n2026-11-02;\"Read; more\";daily;skip;;\n2026-11-03;\"Read; more\";daily;;;travel\n2026-11-02;Fast;timer;done;;")
        XCTAssertEqual(CSVExport.fastsCSV([h, f]), "habit;start;end;hours\nFast;2026-11-01 20:00;2026-11-02 12:15;16,25")
    }

    func testHistoryParserShapes() {
        let t = "date;hours\n2026-08-15;14\n2026-08-16,14,5\n2026-08-17;14,5\n2026-08-18 19:00;2026-08-19 11:00\nFast;2026-08-20 20:00;2026-08-21 12:00;16,00\nnonsense"
        let p = HistoryImport.parse(t, now: now)
        XCTAssertEqual(p.fasts.count, 5)
        XCTAssertEqual(p.bad, 1)
        XCTAssertEqual(p.fasts[1].e - p.fasts[1].s, 14.5 * 3_600_000, accuracy: 1)
        XCTAssertEqual(p.fasts[3].e - p.fasts[3].s, 16 * 3_600_000, accuracy: 1)
    }

    func testHistoryLimits() {
        let p = HistoryImport.parse("2026-08-15;49\n2026-08-15;0\n2026-12-30;14\n2026-08-15 10:00;2026-08-18 10:00", now: now)
        XCTAssertEqual(p.fasts.count, 0)
        XCTAssertEqual(p.bad, 4)
        XCTAssertEqual(HistoryImport.parse("2026-08-15;48", now: now).fasts.count, 1)
    }

    func testHistoryPreviewDuplicates() {
        let pr = HistoryImport.preview("2026-08-15;14\n2026-08-16;13\n2026-08-16;15", existingEndDays: ["2026-08-15"], now: now)
        XCTAssertEqual(pr.fresh.count, 2); XCTAssertEqual(pr.dupes, 1)
        XCTAssertEqual(HistoryImport.toSave(pr.fresh).count, 1)
        XCTAssertEqual(HistoryImport.message(pr, empty: false), "Found 2 new fasts · 1 already recorded.")
    }

    func testGoalParsing() {
        XCTAssertEqual(GoalInput.parse("15,5"), 15.5)
        XCTAssertNil(GoalInput.parse("0")); XCTAssertNil(GoalInput.parse("49")); XCTAssertNil(GoalInput.parse(""))
        XCTAssertNil(GoalInput.byDay(Array(repeating: "", count: 7)))
        XCTAssertEqual(GoalInput.byDay(["16", "", "", "", "", "", "18,5"])?[6], 18.5)
    }

    func testWebBackupRoundTripKeepsUnknownFields() throws {
        let json = ##"{"version":1,"customRoot":"x","habits":[{"id":"h1","name":"Read","icon":"book","color":"#3b70f0","type":"daily","days":[true,true,true,true,true,true,true],"done":{"2026-11-01":1},"wow":{"a":1}}],"settings":{"layout":"grid","badge":true,"reminder":{"on":true,"time":"07:30"}}}"##
        let d = try JSONDecoder().decode(TrackingData.self, from: Data(json.utf8))
        XCTAssertEqual(BackupFiles.reminder(in: d)?.time, "07:30")
        let out = try JSONDecoder().decode(JSONValue.self, from: d.backupJSON())
        guard case .object(let o) = out, case .array(let hs)? = o["habits"], case .object(let h)? = hs.first, case .object(let s)? = o["settings"] else { return XCTFail() }
        XCTAssertEqual(o["customRoot"], .string("x"))
        XCTAssertNotNil(h["wow"]); XCTAssertNotNil(s["reminder"]); XCTAssertEqual(s["badge"], .bool(true))
    }
}
