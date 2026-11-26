import Foundation

// Every rule of the web app (js/app.js v1.51), ported 1:1. Line numbers in docs/spec/02-rules.md.
// All functions take "today"/"now" as a parameter so tests can pin the day.

enum Milestones {
    static let days = [7, 14, 30, 50, 100, 200, 365, 500, 730, 1000]
    static let weeks = [4, 10, 26, 52, 104]
}

extension Habit {
    // MARK: Days

    /// A weekly or fasting habit is "scheduled" every day; a daily habit on its ticked weekdays.
    func isScheduled(_ key: String) -> Bool {
        guard type == .daily else { return true }
        let wd = DayKey.weekday(key)
        return wd < days.count ? days[wd] : true
    }

    /// The days that count as done. A fasting habit: the days a fast ENDED on.
    var doneKeys: Set<String> {
        if type == .timer {
            return Set(sessions.compactMap { $0.end.map(DayKey.key) })
        }
        return Set(done.keys)
    }
    func isDone(_ key: String) -> Bool {
        type == .timer ? sessions.contains { $0.end.map(DayKey.key) == key } : done[key] != nil
    }
    func isSkip(_ key: String) -> Bool { skip.contains(key) }

    /// The first day the habit counts from: its creation day, or an earlier done day (imported history).
    func trackedFrom(today: String) -> String {
        let first = doneKeys.min()
        let made = createdAt ?? today
        if let first, first < made { return first }
        return made
    }

    // MARK: Streaks (daily and fasting)

    /// Today never breaks the streak while it is still open; unscheduled days are passed over;
    /// skip days neither count nor break.
    func currentStreak(today: String = DayKey.today()) -> Int {
        let done = doneKeys
        guard var d = DayKey.date(today) else { return 0 }
        if isScheduled(DayKey.key(d)) && !done.contains(DayKey.key(d)) { d = DayKey.add(d, days: -1) }
        var streak = 0
        for _ in 0..<3700 {
            let k = DayKey.key(d)
            if isScheduled(k) {
                if done.contains(k) { streak += 1 }
                else if !skip.contains(k) { break }
            }
            d = DayKey.add(d, days: -1)
        }
        return streak
    }

    func longestStreak(today: String = DayKey.today()) -> Int {
        let done = doneKeys
        guard let first = done.min(), var d = DayKey.date(first), let end = DayKey.date(today) else { return 0 }
        var best = 0, run = 0, n = 0
        while d <= end && n < 3700 {
            let k = DayKey.key(d)
            if isScheduled(k) {
                if done.contains(k) { run += 1; best = max(best, run) }
                else if !skip.contains(k) { run = 0 }
            }
            d = DayKey.add(d, days: 1); n += 1
        }
        return best
    }

    // MARK: Weekly target

    var weeklyTarget: Int { max(1, target ?? 1) }

    func weekDoneCount(_ weekStart: String) -> Int {
        (0..<7).filter { done[DayKey.add(weekStart, days: $0)] != nil }.count
    }
    func weekHasSkip(_ weekStart: String) -> Bool {
        (0..<7).contains { skip.contains(DayKey.add(weekStart, days: $0)) }
    }

    /// Weeks in a row with the target met. This week counts once met but never breaks the run;
    /// an unmet week with a skip day in it is excused.
    func weeklyStreak(today: String = DayKey.today()) -> Int {
        var w = DayKey.weekStartKey(today)
        var streak = weekDoneCount(w) >= weeklyTarget ? 1 : 0
        for _ in 0..<530 {
            w = DayKey.add(w, days: -7)
            if weekDoneCount(w) >= weeklyTarget { streak += 1 }
            else if !weekHasSkip(w) { break }
        }
        return streak
    }

    struct WeeklyStats: Equatable { var weeksMet = 0, weeksTotal = 0, best = 0 }

    func weeklyStats(today: String = DayKey.today()) -> WeeklyStats {
        let thisWeek = DayKey.weekStartKey(today)
        var w = DayKey.weekStartKey(trackedFrom(today: today))
        var s = WeeklyStats(); var run = 0; var n = 0
        while w <= thisWeek && n < 530 {
            let met = weekDoneCount(w) >= weeklyTarget
            let inProgress = w == thisWeek
            let excused = !met && weekHasSkip(w)
            if (!inProgress || met) && !excused { s.weeksTotal += 1 }
            if met { s.weeksMet += 1; run += 1; s.best = max(s.best, run) }
            else if !inProgress && !excused { run = 0 }
            w = DayKey.add(w, days: 7); n += 1
        }
        return s
    }

    /// The streak the app shows: weeks for a weekly habit, days otherwise.
    func shownStreak(today: String = DayKey.today()) -> Int {
        type == .weekly ? weeklyStreak(today: today) : currentStreak(today: today)
    }
    func bestStreak(today: String = DayKey.today()) -> Int {
        type == .weekly ? weeklyStats(today: today).best : longestStreak(today: today)
    }

    // MARK: Completion

    struct Completion: Equatable { var pct = 0, done = 0, total = 0 }

    /// "{pct}% ({done} of {total} days)": scheduled, non-skip days since tracking began; every done day counts.
    func completion(today: String = DayKey.today()) -> Completion {
        let keys = DayKey.keys(from: trackedFrom(today: today), to: today, limit: 3700)
        let scheduled = keys.filter { isScheduled($0) && !skip.contains($0) }.count
        let doneCount = doneKeys.count
        let total = max(scheduled, doneCount)
        return Completion(pct: scheduled > 0 ? Int((100 * Double(doneCount) / Double(total)).rounded()) : 0,
                          done: doneCount, total: total)
    }

    /// "2 days to your record": the current run is within 3 days (1 week) of the best, and below it.
    func recordGap(today: String = DayKey.today()) -> Int? {
        let cur = shownStreak(today: today), best = bestStreak(today: today)
        let gap = best - cur
        return cur > 0 && gap > 0 && gap <= (type == .weekly ? 1 : 3) ? gap : nil
    }

    // MARK: A month

    struct MonthStats: Equatable { var done = 0, scheduled = 0; var pct: Int { scheduled > 0 ? Int((100 * Double(done) / Double(scheduled)).rounded()) : 0 } }

    /// Days done and days scheduled (not skipped) in a month, from the day tracking began through today.
    func monthStats(year: Int, month: Int, today: String = DayKey.today()) -> MonthStats {
        let cal = DayKey.calendar
        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = cal.range(of: .day, in: .month, for: first) else { return MonthStats() }
        let last = DayKey.key(DayKey.add(first, days: range.count - 1))
        let start = max(DayKey.key(first), trackedFrom(today: today))
        let end = min(last, today)
        guard start <= end else { return MonthStats() }
        let done = doneKeys
        var s = MonthStats()
        for k in DayKey.keys(from: start, to: end) {
            if done.contains(k) { s.done += 1 }
            if isScheduled(k) && !skip.contains(k) { s.scheduled += 1 }
        }
        return s
    }

    // MARK: Parts ("Medit | Brea | Cold")

    /// 2 to 4 parts when the name has "|" (never for fasting); nil otherwise.
    var parts: [String]? {
        guard type != .timer, name.contains("|") else { return nil }
        let p = name.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return (2...4).contains(p.count) ? p : nil
    }
    /// Parts done that day; a plain "done" means all of them.
    func doneParts(_ key: String) -> [Int] {
        guard let v = done[key] else { return [] }
        switch v {
        case .parts(let p): return p
        case .all: return parts.map { Array(0..<$0.count) } ?? [0]
        }
    }
    var displayName: String { parts?.joined(separator: " | ") ?? name }

    // MARK: Fasting

    var activeSession: Session? { sessions.first { $0.e == nil } }
    var activeIndex: Int? { sessions.firstIndex { $0.e == nil } }
    var lastFinished: Session? { sessions.last { $0.e != nil } }
    var finishedSessions: [Session] { sessions.filter { $0.e != nil } }

    /// The goal of a fast ending on that day: the weekday's own goal, else the habit's goal.
    func goalHours(on day: Date) -> Double? {
        let wd = DayKey.weekday(day)
        if let byDay = goalByDay, wd < byDay.count, let g = byDay[wd], g > 0, g.isFinite { return g }
        return goalHours
    }
    /// The day a fast counts for: when it ended; a running one started at noon or later ends tomorrow.
    static func goalDay(for s: Session) -> Date {
        if let end = s.end { return end }
        let start = s.start
        return DayKey.calendar.component(.hour, from: start) >= 12 ? DayKey.add(start, days: 1) : start
    }
    /// Goal of one fast in ms: its own old goal, else the day's goal, else the habit's.
    func goalMs(for s: Session?) -> Double? {
        guard let s else { return goalHours.map { $0 * 3_600_000 } }
        let h = s.g ?? goalHours(on: Habit.goalDay(for: s))
        return h.map { $0 * 3_600_000 }
    }

    struct FastDays { var ms: [String: Double] = [:]; var met: Set<String> = [] }

    /// Hours fasted per day (summed by the day each fast ended) and the days a fast met its goal
    /// (no goal at all counts as met).
    var fastDays: FastDays {
        var out = FastDays()
        for s in sessions {
            guard let e = s.e, let end = s.end else { continue }
            let k = DayKey.key(end)
            let len = e - s.s
            out.ms[k, default: 0] += len
            let g = s.g ?? goalHours(on: end)
            if g == nil || len >= g! * 3_600_000 { out.met.insert(k) }
        }
        return out
    }

    /// What the fasting card's number and label say right now.
    enum TimerState: Equatable {
        case overlong(elapsed: Double)                       // "still fasting? / tap timer to fix"
        case goalReached(elapsed: Double)
        case running(elapsed: Double, left: Double, goalClock: String)
        case fasting(elapsed: Double)                        // no goal
        case eating(since: Double, until: String?)           // until nil = "time to fast"
        case lastFast(length: Double)
        case none                                            // "tap to start"
    }

    func timerState(now: Date = DayKey.now) -> TimerState {
        let nowMs = now.timeIntervalSince1970 * 1000
        if let a = activeSession {
            let elapsed = nowMs - a.s
            let goal = goalMs(for: a)
            if elapsed > 24 * 3_600_000 { return .overlong(elapsed: elapsed) }
            if let goal, elapsed >= goal { return .goalReached(elapsed: elapsed) }
            if let goal { return .running(elapsed: elapsed, left: goal - elapsed, goalClock: Fmt.clock(ms: a.s + goal)) }
            return .fasting(elapsed: elapsed)
        }
        guard let last = lastFinished, let e = last.e, let end = last.end else { return .none }
        let sinceEnd = nowMs - e
        if let next = goalHours(on: DayKey.add(end, days: 1)), sinceEnd < 24 * 3_600_000 {
            let nextStart = e + max(0, 24 - next) * 3_600_000
            return .eating(since: sinceEnd, until: nextStart > nowMs ? Fmt.clock(ms: nextStart) : nil)
        }
        return .lastFast(length: e - last.s)
    }

    /// Ring progress 0…1 while a fast runs with a goal; nil otherwise.
    func ringProgress(now: Date = DayKey.now) -> Double? {
        guard let a = activeSession, let goal = goalMs(for: a), goal > 0 else { return nil }
        return min(1, (now.timeIntervalSince1970 * 1000 - a.s) / goal)
    }
}

/// Red in the first third of the goal, yellow in the middle third, green after.
enum RingPhase {
    static func hex(_ progress: Double) -> String {
        progress < 1.0 / 3 ? "#d9463e" : progress < 2.0 / 3 ? "#e0a80f" : "#2fa96d"
    }
}

/// The four commonly cited stages of a fast (not medical advice).
struct FastStage: Identifiable {
    let name: String, from: Double, hint: String, hex: String
    var id: String { name }
    static let all = [
        FastStage(name: "Digestion", from: 0, hint: "the body is still processing the last meal", hex: "#d9463e"),
        FastStage(name: "Settling in", from: 4, hint: "blood sugar and insulin drift down", hex: "#e0a80f"),
        FastStage(name: "Fat burning", from: 12, hint: "the body leans on its fat stores", hex: "#7bc496"),
        FastStage(name: "Deep fast", from: 16, hint: "ketosis territory for many people", hex: "#2fa96d"),
    ]
    static func current(hours: Double) -> FastStage { all.last { $0.from <= hours } ?? all[0] }
}
