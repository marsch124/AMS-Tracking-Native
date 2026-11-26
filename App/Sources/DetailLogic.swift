import Foundation

// The rules of a habit's page, as plain functions so a small test can pin each one (Lane A).
// Web spec: screens 6.x / 8.x, rules 2.6, 5.1, 5.4, 5.5, 7.1.

// MARK: - Calendar day taps

extension Habit {
    /// A tap on a calendar day of a check-off habit (web `toggleHistoryDay`): done → skip, skip → empty, empty → done.
    /// No toast, no milestone.
    mutating func cycleHistoryDay(_ k: String) {
        if done[k] != nil { done[k] = nil; skip.insert(k) }
        else if skip.contains(k) { skip.remove(k) }
        else { done[k] = .all }
    }

    /// What the fasting calendar circle of a past day or today shows (rules 5.4).
    enum FastCell: Equatable {
        case met(Int), under(Int), running(Int), skip, empty
    }

    func fastCell(_ k: String, today: String, now: Date = DayKey.now) -> FastCell {
        let days = fastDays
        if isDone(k) {
            let h = Int(((days.ms[k] ?? 0) / 3_600_000).rounded())
            return days.met.contains(k) ? .met(h) : .under(h)
        }
        if k == today, let a = activeSession {
            return .running(Int(((now.timeIntervalSince1970 * 1000 - a.s) / 3_600_000).rounded()))
        }
        if skip.contains(k) { return .skip }
        return .empty
    }

    /// What a tap on a fasting-calendar day does (rules 5.1).
    enum FastTap: Equatable {
        case removeSkip
        case editFast(start: Double)
        case recordHours
    }

    func fastTap(_ k: String) -> FastTap {
        // The LAST fast (array order) that ends that day.
        if let last = sessions.last(where: { $0.end.map(DayKey.key) == k }) { return .editFast(start: last.s) }
        if skip.contains(k) { return .removeSkip }
        return .recordHours
    }

    // MARK: Year

    /// The years a habit shows a card for: the current one first, then earlier years with a done day (newest first).
    func yearsShown(today: String) -> [Int] {
        let cur = Int(today.prefix(4)) ?? 2026
        let earlier = Set(doneKeys.compactMap { Int($0.prefix(4)) }).filter { $0 < cur }
        return [cur] + earlier.sorted(by: >)
    }

    enum Pixel: Equatable { case done, skip, empty, future }

    func pixel(_ k: String, today: String) -> Pixel {
        if k > today { return .future }
        if isDone(k) { return .done }
        if skip.contains(k) { return .skip }
        return .empty
    }

    /// "Mon, 5 Oct — done" / "— skip day" / "— not done", then " · note".
    func pixelToast(_ k: String, today: String) -> String {
        let when = DayKey.date(k).map { Fmt.weekdayDayMonth($0) } ?? k
        let state: String
        switch pixel(k, today: today) {
        case .done: state = "done"
        case .skip: state = "skip day"
        default: state = "not done"
        }
        var s = "\(when) — \(state)"
        if let n = notes[k], !n.isEmpty { s += " · \(n)" }
        return s
    }

    /// "Days completed" of an earlier year: days done, and scheduled non-skip days of that year (from when tracking began).
    func yearSummary(_ year: Int, today: String) -> (done: Int, scheduled: Int) {
        let first = "\(String(format: "%04d", year))-01-01", last = "\(String(format: "%04d", year))-12-31"
        let start = max(first, trackedFrom(today: today)), end = min(last, today)
        let done = doneKeys.filter { $0 >= first && $0 <= last }.count
        guard start <= end else { return (done, 0) }
        let sched = DayKey.keys(from: start, to: end).filter { isScheduled($0) && !skip.contains($0) }.count
        return (done, sched)
    }

    // MARK: Fasts card (rules 5.5)

    struct FastStats: Equatable { var average = 0.0, longest = 0.0, goalMetDays = 0, total = 0 }

    var fastStats: FastStats {
        let fin = finishedSessions
        guard !fin.isEmpty else { return FastStats() }
        let lens = fin.map { ($0.e ?? $0.s) - $0.s }
        return FastStats(average: lens.reduce(0, +) / Double(lens.count), longest: lens.max() ?? 0,
                         goalMetDays: fastDays.met.count, total: fin.count)
    }
}

// MARK: - Month grid

struct MonthGrid: Equatable {
    var first: Date
    /// Empty cells before day 1 (Monday first).
    var lead: Int
    var count: Int
    var keys: [String]

    init(containing d: Date) {
        let cal = DayKey.calendar
        let f = cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
        let n = cal.range(of: .day, in: .month, for: f)?.count ?? 30
        first = f
        lead = DayKey.weekday(f)
        count = n
        keys = (0..<n).map { DayKey.key(DayKey.add(f, days: $0)) }
    }

    /// The month may be browsed up to 12 months ahead of the current one.
    static func canGoNext(from shown: Date, today: String) -> Bool {
        guard let t = DayKey.date(today) else { return false }
        let cal = DayKey.calendar
        guard let a = cal.date(from: cal.dateComponents([.year, .month], from: t)),
              let b = cal.date(from: cal.dateComponents([.year, .month], from: shown)) else { return false }
        return (cal.dateComponents([.month], from: a, to: b).month ?? 0) < 12
    }
    func shifted(_ n: Int) -> Date { DayKey.calendar.date(byAdding: .month, value: n, to: first) ?? first }
}

// MARK: - Record hours (rules 2.6)

enum FastHours {
    static let message = "Please enter a fast length between 0 and 48 hours."
    /// "16", "15,5", "15.5" → hours; nil when not 0 < h ≤ 48.
    static func parse(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let h = Double(t), h.isFinite, h > 0, h <= 48 else { return nil }
        return h
    }
    /// The chips: the day's goal, then 13, 15, 16, 18 (no duplicates).
    static func presets(goal: Double?) -> [Double] {
        var out: [Double] = []
        for h in [goal, 13, 15, 16, 18].compactMap({ $0 }) where h > 0 && !out.contains(h) { out.append(h) }
        return out
    }
    /// A finished fast ending at 12:00 on that day.
    static func session(hours: Double, day: String) -> Session? {
        guard let d = DayKey.date(day), let noon = DayKey.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: d) else { return nil }
        let e = noon.timeIntervalSince1970 * 1000
        return Session(s: e - hours * 3_600_000, e: e)
    }
}

// MARK: - Edit a fast (rules 5.1)

enum FastEdit {
    /// The first problem with the times, in the web app's order; nil = fine.
    static func validate(start: Date?, end: Date?, running: Bool, now: Date = DayKey.now) -> String? {
        guard let start else { return "Please enter a valid start time." }
        if start.timeIntervalSince(now) > 60 { return "The start can't be in the future." }
        if running { return nil }
        guard let end else { return "Please enter a valid end time." }
        if end <= start { return "The end must be after the start." }
        if end.timeIntervalSince(start) > 48 * 3600 { return "A fast can be at most 48 hours." }
        if end.timeIntervalSince(now) > 60 { return "The end can't be in the future." }
        return nil
    }
}

// MARK: - Skip several days (rules 7.1)

enum SkipRange {
    static let maxDays = 92
    static func days(from: String, to: String) -> Int {
        guard let a = DayKey.date(from), let b = DayKey.date(to) else { return 0 }
        return (DayKey.calendar.dateComponents([.day], from: a, to: b).day ?? 0) + 1
    }
    static func validate(from: String?, to: String?) -> String? {
        guard let from, let to else { return "Please pick a first and a last day." }
        if to < from { return "The last day must not be before the first day." }
        if days(from: from, to: to) > maxDays { return "A range can cover at most 92 days (about 3 months)." }
        return nil
    }
    /// Days in the range that become skip days: not already done, not already skipped.
    static func newSkips(_ h: Habit, from: String, to: String) -> [String] {
        let done = h.doneKeys
        return DayKey.keys(from: from, to: to, limit: maxDays + 1).filter { !done.contains($0) && !h.skip.contains($0) }
    }
    static func message(days: Int, habits: Int) -> String {
        let w = days == 1 ? "day" : "days"
        return habits > 1 ? "\(days) \(w) skipped for \(habits) habits" : "\(days) \(w) skipped"
    }
}
