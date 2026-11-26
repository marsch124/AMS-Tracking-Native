import XCTest
@testable import AMSTracking

/// One small test per rule of the core (lean, Martin's rule 9 Nov 2026). Days are fixed keys; 2026-11-26 is a Thursday.
final class CoreTests: XCTestCase {
    let today = "2026-11-26"
    func d(_ n: Int) -> String { DayKey.add(today, days: -n) }
    func ms(_ key: String, _ hour: Int, _ minute: Int = 0) -> Double {
        DayKey.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: DayKey.date(key)!)!.timeIntervalSince1970 * 1000
    }

    // MARK: Dates

    func testWeeksStartOnMonday() {
        XCTAssertEqual(DayKey.weekday(today), 3)                       // Thursday
        XCTAssertEqual(DayKey.weekStartKey(today), "2026-11-23")
    }

    func testDurationIsHoursAndMinutes() {
        XCTAssertEqual(Fmt.duration(16 * 3_600_000 + 5 * 60_000), "16:05")
        XCTAssertEqual(Fmt.duration(26 * 3_600_000), "26:00")
    }

    // MARK: Streaks

    func testAnOpenTodayDoesNotBreakTheStreakAndSkipDaysAreExcused() {
        var h = Habit(name: "Read", createdAt: d(30))
        for n in [1, 2, 4] { h.done[d(n)] = .all }
        h.skip = [d(3)]
        XCTAssertEqual(h.currentStreak(today: today), 3)
        h.done[today] = .all
        XCTAssertEqual(h.currentStreak(today: today), 4)
    }

    func testUnscheduledDaysNeitherCountNorBreak() {
        // Weekdays only; the weekend before Monday 23 Nov is passed over.
        var h = Habit(name: "Work", days: [true, true, true, true, true, false, false], createdAt: d(30))
        for k in ["2026-11-20", "2026-11-23", "2026-11-24", "2026-11-25"] { h.done[k] = .all }
        XCTAssertEqual(h.currentStreak(today: today), 4)
    }

    func testLongestStreak() {
        var h = Habit(name: "Read", createdAt: d(30))
        for n in [10, 9, 8, 7, 5, 4] { h.done[d(n)] = .all }
        XCTAssertEqual(h.longestStreak(today: today), 4)
    }

    func testWeeklyStreakCountsWeeksAndExcusesAWeekWithASkip() {
        var h = Habit(name: "Gym", type: .weekly, target: 2, createdAt: d(60))
        // This week (from 23 Nov): 2 done → counts. Last week: 1 done + a skip → excused. The week before: 2 → counts.
        for k in ["2026-11-23", "2026-11-24", "2026-11-17", "2026-11-09", "2026-11-11"] { h.done[k] = .all }
        h.skip = ["2026-11-18"]
        XCTAssertEqual(h.weeklyStreak(today: today), 2)
        XCTAssertEqual(h.weekDoneCount("2026-11-23"), 2)
    }

    func testCompletionCountsScheduledNonSkipDays() {
        var h = Habit(name: "Read", createdAt: d(9))   // 10 days incl. today
        for n in 1...5 { h.done[d(n)] = .all }
        h.skip = [d(9)]
        let c = h.completion(today: today)
        XCTAssertEqual(c.total, 9)
        XCTAssertEqual(c.done, 5)
        XCTAssertEqual(c.pct, 56)
    }

    func testRecordGapShowsWithinThreeDays() {
        var h = Habit(name: "Read", createdAt: d(40))
        for n in 20...24 { h.done[d(n)] = .all }      // best 5
        for n in 1...3 { h.done[d(n)] = .all }        // current 3
        XCTAssertEqual(h.recordGap(today: today), 2)
    }

    // MARK: Parts

    func testPartsNeedTwoToFourAndAPlainDoneMeansAll() {
        var h = Habit(name: "Medit | Brea | Cold")
        XCTAssertEqual(h.parts, ["Medit", "Brea", "Cold"])
        h.done[today] = .all
        XCTAssertEqual(h.doneParts(today), [0, 1, 2])
        XCTAssertNil(Habit(name: "A | B | C | D | E").parts)
        XCTAssertNil(Habit(name: "Fast | Eat", type: .timer).parts)
    }

    // MARK: Fasting

    func testAFastCountsForTheDayItEnds() {
        var h = Habit(name: "IF", type: .timer, goalHours: 16)
        h.sessions = [Session(s: ms(d(1), 20), e: ms(today, 12, 30))]
        XCTAssertTrue(h.isDone(today))
        XCTAssertFalse(h.isDone(d(1)))
        XCTAssertTrue(h.fastDays.met.contains(today))     // 16:30 ≥ 16 h
    }

    func testGoalPrecedenceOwnGoalThenWeekdayThenHabit() {
        var h = Habit(name: "IF", type: .timer, goalHours: 16, goalByDay: [nil, nil, nil, nil, 14, nil, nil])
        let friday = DayKey.date("2026-11-27")!
        XCTAssertEqual(h.goalHours(on: friday), 14)
        XCTAssertEqual(h.goalHours(on: DayKey.date(today)!), 16)
        // A fast started Thursday 20:00 is expected to end Friday → the Friday goal.
        let running = Session(s: ms(today, 20), e: nil)
        XCTAssertEqual(h.goalMs(for: running), 14 * 3_600_000)
        h.sessions = [Session(s: ms(today, 20), e: nil, g: 18)]
        XCTAssertEqual(h.goalMs(for: h.sessions[0]), 18 * 3_600_000)
    }

    func testTimerStatesOverlongWinsOverGoalReached() {
        var h = Habit(name: "IF", type: .timer, goalHours: 16)
        let now = Date(timeIntervalSince1970: ms(today, 9) / 1000)
        h.sessions = [Session(s: ms(d(1), 20), e: nil)]
        if case .running(_, let left, let clock) = h.timerState(now: now) {
            XCTAssertEqual(Fmt.duration(left), "3:00"); XCTAssertEqual(clock, "12:00")
        } else { XCTFail("expected running") }
        h.sessions = [Session(s: ms(d(2), 6), e: nil)]
        if case .overlong = h.timerState(now: now) {} else { XCTFail("expected overlong") }
    }

    func testEatingWindowUntilTheNextFastsStart() {
        var h = Habit(name: "IF", type: .timer, goalHours: 16)
        h.sessions = [Session(s: ms(d(1), 20), e: ms(today, 12))]
        let now = Date(timeIntervalSince1970: ms(today, 14) / 1000)
        XCTAssertEqual(h.timerState(now: now), .eating(since: 2 * 3_600_000, until: "20:00"))
    }

    func testRingIsRedYellowGreenByThirds() {
        XCTAssertEqual(RingPhase.hex(0.2), "#d9463e")
        XCTAssertEqual(RingPhase.hex(0.5), "#e0a80f")
        XCTAssertEqual(RingPhase.hex(0.7), "#2fa96d")
        XCTAssertEqual(FastStage.current(hours: 13).name, "Fat burning")
    }

    // MARK: Reading a web backup

    func testAWebBackupImportsWithEveryOddValue() throws {
        let json = """
        {"version":1,"habits":[
          {"id":"a","name":"Old","icon":"🌙","color":"#7a5af8","type":"daily","days":[true,true,true,true,true,true,true],
           "done":{"2026-11-20":1,"2026-11-21":true,"2026-11-22":[0,2],"2026-11-23":[],"2026-11-24":0},
           "skip":{"2026-11-19":1},"notes":{"2026-11-20":"hi"},"futureField":{"x":1}},
          {"id":"b","name":"IF","icon":"moon","color":"#7a5af8","type":"timer","goalHours":16,"goalByDay":[16,null,"x",0,14,null,null],
           "sessions":[{"s":1795000000000,"e":1795057600000},{"e":5},{"s":1795100000000,"e":null}]}],
         "settings":{"theme":"dark"}}
        """
        let data = try JSONDecoder().decode(TrackingData.self, from: Data(json.utf8))
        let a = data.habits[0]
        XCTAssertEqual(a.icon, "moon")                                    // emoji → drawing
        XCTAssertEqual(Set(a.done.keys), ["2026-11-20", "2026-11-21", "2026-11-22"])
        XCTAssertEqual(a.done["2026-11-22"], .parts([0, 2]))
        XCTAssertEqual(a.extra["futureField"], .object(["x": .number(1)]))  // unknown fields kept
        let b = data.habits[1]
        XCTAssertEqual(b.sessions.count, 2)                               // the broken fast is skipped
        XCTAssertNotNil(b.activeSession)
        XCTAssertEqual(b.goalByDay, [16, nil, nil, nil, 14, nil, nil])
        XCTAssertEqual(data.settings.theme, "dark")
        XCTAssertTrue(data.aspirations.isEmpty)
    }

    func testABackupIsTheWebShapeWithoutICloudBookkeeping() throws {
        var data = TrackingData()
        data.habits = [Habit(id: "x", name: "Read"), Habit(id: "gone", name: "Old", deletedAt: 5)]
        let raw = try data.backupJSON()
        let text = String(decoding: raw, as: UTF8.self)
        XCTAssertFalse(text.contains("\"mt\""))
        XCTAssertFalse(text.contains("gone"))
        XCTAssertEqual(try JSONDecoder().decode(TrackingData.self, from: raw).habits.map(\.id), ["x"])
    }

    func testNotABackupIsRefused() {
        XCTAssertThrowsError(try JSONDecoder().decode(TrackingData.self, from: Data("{\"a\":1}".utf8)))
    }

    // MARK: iCloud merge

    func testMergeKeepsTheNewestChangeOfEachHabitAndRemovals() {
        var a = TrackingData(), b = TrackingData()
        a.habits = [Habit(id: "1", name: "Phone", mt: 200), Habit(id: "2", name: "Keep", mt: 100)]
        b.habits = [Habit(id: "1", name: "Mac", mt: 100), Habit(id: "2", name: "Keep", mt: 300, deletedAt: 300),
                    Habit(id: "3", name: "New on Mac", mt: 50)]
        let m = TrackingData.merged(a, b)
        XCTAssertEqual(m.habit("1")?.name, "Phone")
        XCTAssertNil(m.habit("2"))                 // the removal on the Mac reaches the phone
        XCTAssertEqual(m.habit("3")?.name, "New on Mac")
    }

    func testMergeTakesTheOrderChangedLast() {
        var a = TrackingData(), b = TrackingData()
        a.habits = [Habit(id: "1", name: "A"), Habit(id: "2", name: "B")]
        b.habits = [Habit(id: "2", name: "B"), Habit(id: "1", name: "A")]
        b.orderMt = 10
        XCTAssertEqual(TrackingData.merged(a, b).habits.map(\.id), ["2", "1"])
    }
}

/// The store's actions, on a store in a temporary folder.
@MainActor
final class ActionTests: XCTestCase {
    func makeStore() -> Store {
        let s = Store(root: FileManager.default.temporaryDirectory.appendingPathComponent("tracking-test-\(UUID().uuidString)"))
        s.resetForTests()
        return s
    }

    func testStartWhileFastingIsIgnoredAndAStopBeforeTheStartToo() {
        let store = makeStore()
        store.add(Habit(id: "f", name: "IF", type: .timer, goalHours: 16))
        let t0 = nowMs() - 3_600_000
        XCTAssertTrue(store.applyFastAction("start", at: t0, source: "siri"))
        XCTAssertFalse(store.applyFastAction("start", at: nil, source: "menu"))
        XCTAssertFalse(store.applyFastAction("stop", at: t0 - 1000, source: "siri"))
        XCTAssertTrue(store.applyFastAction("stop", at: nil, source: "menu"))
        XCTAssertEqual(store.data.habit("f")?.finishedSessions.count, 1)
    }

    func testFirstNonArchivedFastingHabitIsTheTarget() {
        let store = makeStore()
        store.add(Habit(id: "old", name: "Old IF", type: .timer, archived: true))
        store.add(Habit(id: "f", name: "IF", type: .timer))
        XCTAssertEqual(store.data.fastingHabit?.id, "f")
    }

    func testAMilestoneFiresOnceAtSevenDays() {
        let store = makeStore()
        var h = Habit(id: "r", name: "Read", createdAt: DayKey.add(DayKey.today(), days: -20))
        for n in 1...6 { h.done[DayKey.add(DayKey.today(), days: -n)] = .all }
        store.add(h)
        store.toggleToday("r")
        XCTAssertEqual(store.celebration?.title, "7-day streak!")
        XCTAssertEqual(store.data.habit("r")?.lastCelebrated, "day7")
        store.celebration = nil
        store.toggleToday("r"); store.toggleToday("r")
        XCTAssertNil(store.celebration)
    }

    func testImportReplacesEverythingAndRemovalsReachOtherDevices() {
        let store = makeStore()
        store.add(Habit(id: "mine", name: "Here"))
        var backup = TrackingData()
        backup.habits = [Habit(id: "web", name: "From the web")]
        store.replaceAll(with: backup)
        XCTAssertEqual(store.data.liveHabits.map(\.id), ["web"])
        XCTAssertNotNil(store.data.habits.first { $0.id == "mine" }?.deletedAt)
    }
}
