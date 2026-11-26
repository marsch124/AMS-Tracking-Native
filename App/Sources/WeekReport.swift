import Foundation

// The week that just ended, as figures: web `weekReport` (app.js 1242), `weekFastStats` (1229) and the
// aspiration coverage (1113-1208). Both the Last week screen and the picture it sends only DRAW what this
// returns — neither counts anything itself (the web app's own rule).

struct WeekRow: Identifiable {
    enum Mark { case done, skip, off, empty }
    enum Trend { case up, down, flat }

    var habit: Habit
    var days: [Mark]
    var mid = ""
    var delta = ""
    var trend: Trend = .flat
    /// nil = not judged (fasting has no weekly bar to clear).
    var met: Bool?
    var fasts = 0
    var avg: Double?
    var count = 0
    var target = 1
    var dn = 0
    var sched = 0
    var deltaValue: Int?
    /// "week" or "day" — the unit of a streak change.
    var unit: String?
    var id: String { habit.id }
}

struct WeekReport {
    var ws: String
    var we: String
    var rows: [WeekRow]
    var met: Int
    var judged: Int
    var ticks: Int

    /// Habits completed on each weekday (Monday first).
    var perDay: [Int] {
        (0..<7).map { i in rows.filter { $0.days[i] == .done }.count }
    }
    var ceiling: Int { max(rows.count, 1) }

    /// A short fingerprint, so a screen knows when the picture has to be drawn again.
    var signature: String {
        rows.map { r in r.habit.id + r.mid + r.delta + r.days.map { "\($0)" }.joined() }.joined(separator: "|") + "\(ws)"
    }

    var headFigure: String { judged > 0 ? "\(met)/\(judged)" : String(ticks) }
    var headLabel: String {
        judged > 0 ? (judged == 1 ? "habit on target" : "habits on target") : (ticks == 1 ? "day ticked" : "days ticked")
    }
    var allMet: Bool { judged > 0 && met == judged }

    /// "Nothing was ticked last week." or the one-sentence reading of the chart.
    var chartCaption: String {
        let total = perDay.reduce(0, +)
        guard total > 0 else { return "Nothing was ticked last week." }
        let pd = perDay
        let best = pd.firstIndex(of: pd.max() ?? 0) ?? 0
        return "\(total) in all, out of \(ceiling) habits a day. \(DayKey.longNames[best]) carried the most, with \(pd[best]) of \(ceiling)."
    }

    static func make(_ data: TrackingData, ws: String, today: String = DayKey.today()) -> WeekReport {
        let we = DayKey.add(ws, days: 6)
        let prevWs = DayKey.add(ws, days: -7)
        let endPrev = DayKey.add(ws, days: -1)
        // Only habits that existed for the whole week.
        let habits = data.activeHabits.filter { $0.createdAt == nil || $0.createdAt! <= ws }
        let rows: [WeekRow] = habits.map { h in
            let done = h.doneKeys
            var days: [WeekRow.Mark] = []
            for i in 0..<7 {
                let k = DayKey.add(ws, days: i)
                days.append(done.contains(k) ? .done : h.skip.contains(k) ? .skip : !h.isScheduled(k) ? .off : .empty)
            }
            var row = WeekRow(habit: h, days: days)
            switch h.type {
            case .timer:
                let cur = h.fastStats(weekStarting: ws)
                let prev = h.fastStats(weekStarting: prevWs)
                row.mid = cur.n > 0 ? "\(cur.n) fast\(cur.n == 1 ? "" : "s") · Ø \(Fmt.duration(cur.avg ?? 0)) h" : "no fasts"
                row.fasts = cur.n
                row.avg = cur.avg
                if let c = cur.avg, let p = prev.avg {
                    let d = c - p
                    row.delta = (d < 0 ? "–" : "+") + Fmt.duration(abs(d))
                    row.trend = d > 0 ? .up : d < 0 ? .down : .flat
                }
            case .weekly:
                let count = h.weekDoneCount(ws)
                let target = h.target ?? 1
                row.mid = "\(count)/\(target)×"
                row.count = count
                row.target = target
                row.met = count >= target
                row.deltaValue = h.weeklyStreak(today: we) - h.weeklyStreak(today: endPrev)
                row.unit = "week"
            case .daily:
                var sched = 0, dn = 0
                for i in 0..<7 {
                    let k = DayKey.add(ws, days: i)
                    if done.contains(k) { dn += 1 }
                    if h.isScheduled(k) && !h.skip.contains(k) { sched += 1 }
                }
                row.mid = "\(dn)/\(sched) days"
                row.dn = dn
                row.sched = sched
                row.met = sched > 0 && dn >= sched
                row.deltaValue = h.currentStreak(today: we) - h.currentStreak(today: endPrev)
                row.unit = "day"
            }
            if let v = row.deltaValue {
                row.delta = (v < 0 ? "–" : v > 0 ? "+" : "±") + String(abs(v))
                row.trend = v > 0 ? .up : v < 0 ? .down : .flat
            }
            return row
        }
        let judged = rows.filter { $0.met != nil }
        return WeekReport(ws: ws, we: we, rows: rows, met: judged.filter { $0.met == true }.count, judged: judged.count,
                          ticks: rows.reduce(0) { $0 + $1.days.filter { $0 == .done }.count })
    }
}

extension Habit {
    /// Finished fasts that ENDED within [from, to) in milliseconds.
    func fastStats(fromMs: Double, toMs: Double) -> (n: Int, avg: Double?) {
        let d = sessions.compactMap { s -> Double? in
            guard let e = s.e, e >= fromMs, e < toMs else { return nil }
            return e - s.s
        }
        return (d.count, d.isEmpty ? nil : d.reduce(0, +) / Double(d.count))
    }
    /// Fasts that ended in the week starting at that Monday.
    func fastStats(weekStarting ws: String) -> (n: Int, avg: Double?) {
        guard let a = DayKey.date(ws), let b = DayKey.date(DayKey.add(ws, days: 7)) else { return (0, nil) }
        return fastStats(fromMs: a.timeIntervalSince1970 * 1000, toMs: b.timeIntervalSince1970 * 1000)
    }
    /// Fasts that ended in a calendar month.
    func fastStats(year: Int, month: Int) -> (n: Int, avg: Double?) {
        let cal = DayKey.calendar
        guard let a = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let b = cal.date(byAdding: .month, value: 1, to: a) else { return (0, nil) }
        return fastStats(fromMs: a.timeIntervalSince1970 * 1000, toMs: b.timeIntervalSince1970 * 1000)
    }
}

// MARK: - Aspiration coverage (web 1113-1208)

struct AspirationCover: Identifiable {
    var asp: Aspiration
    var habits: [Habit]
    var total: Int
    var ran: Int
    var met: Int
    var judged: Int
    var quiet: Int
    var id: String { asp.id }
}

/// Everything the Last week screen reads out of the data: notes, suggestions, the summary in words.
/// `forcedNudges` = aspiration nudges this screen has already shown, so they keep showing while it is open.
struct Insights {
    static let noteWeeks = 8
    static let notesShown = 3
    static let nudgeCooldownWeeks = 4

    var data: TrackingData
    var today: String = DayKey.today()
    var forcedNudges: Set<String> = []

    /// The Monday of the week that just ended.
    var ws: String { DayKey.add(DayKey.weekStartKey(today), days: -7) }

    // MARK: Aspirations

    func aspiration(_ id: String) -> Aspiration? { data.aspirations.first { $0.id == id && $0.deletedAt == nil } }
    func habitsUnder(_ aspId: String) -> [Habit] { data.activeHabits.filter { $0.aspirationId == aspId } }
    /// Habits attached to nothing (no aspiration, a missing one, or an archived one).
    var unattachedHabits: [Habit] {
        data.activeHabits.filter { h in
            guard let id = h.aspirationId, let a = aspiration(id) else { return true }
            return a.archivedAt != nil
        }
    }

    func habitActive(_ h: Habit, in ws: String) -> Bool {
        let done = h.doneKeys
        return (0..<7).contains { done.contains(DayKey.add(ws, days: $0)) }
    }
    /// Did it do what it was asked for? nil = not judged (fasting).
    func habitMet(_ h: Habit, in ws: String) -> Bool? {
        if h.type == .timer { return nil }
        if h.type == .weekly { return h.weekDoneCount(ws) >= (h.target ?? 1) }
        let done = h.doneKeys
        var dn = 0, sched = 0
        for i in 0..<7 {
            let k = DayKey.add(ws, days: i)
            if h.skip.contains(k) || !h.isScheduled(k) { continue }
            sched += 1
            if done.contains(k) { dn += 1 }
        }
        return sched > 0 && dn >= sched
    }
    /// Completed weeks in a row with nothing running under it, counted back from `ws` (at most 53).
    func silentWeeks(_ aspId: String, _ ws: String) -> Int {
        let hs = habitsUnder(aspId)
        if hs.isEmpty { return 0 }
        var n = 0
        for i in 0..<53 {
            let w = DayKey.add(ws, days: -7 * i)
            if hs.contains(where: { habitActive($0, in: w) }) { break }
            n += 1
        }
        return n
    }
    func coverage(_ ws: String) -> [AspirationCover] {
        data.liveAspirations.map { a in
            let hs = habitsUnder(a.id)
            let judged = hs.filter { habitMet($0, in: ws) != nil }
            return AspirationCover(asp: a, habits: hs, total: hs.count,
                                   ran: hs.filter { habitActive($0, in: ws) }.count,
                                   met: judged.filter { habitMet($0, in: ws) == true }.count,
                                   judged: judged.count, quiet: silentWeeks(a.id, ws))
        }
    }

    /// Said once, then not again for four weeks.
    func nudgeAllowed(_ key: String) -> Bool {
        if forcedNudges.contains(key) { return true }
        guard let seen = data.settings.aspNudges[key], let seenDate = DayKey.date(seen),
              let thisMonday = DayKey.date(DayKey.weekStartKey(today)) else { return true }
        let weeks = (thisMonday.timeIntervalSince(seenDate) / (7 * 86400)).rounded()
        return Int(weeks) >= Insights.nudgeCooldownWeeks
    }

    // MARK: Pieces of the notes

    func recentWeeks(_ ws: String, _ n: Int) -> [String] { (0..<n).reversed().map { DayKey.add(ws, days: -7 * $0) } }

    struct Misses { var miss = [Int](repeating: 0, count: 7); var sched = [Int](repeating: 0, count: 7)
        var totalMiss: Int { miss.reduce(0, +) }; var totalSched: Int { sched.reduce(0, +) } }

    /// Days asked for and missed, per weekday, over the window. Skip days and days before the habit existed are left out.
    func weekdayMisses(_ h: Habit, _ ws: String, _ n: Int) -> Misses {
        let done = h.doneKeys
        var m = Misses()
        for w in recentWeeks(ws, n) {
            for i in 0..<7 {
                let k = DayKey.add(w, days: i)
                if k > today { continue }
                if let born = h.createdAt, k < born { continue }
                if h.skip.contains(k) || !h.isScheduled(k) { continue }
                m.sched[i] += 1
                if !done.contains(k) { m.miss[i] += 1 }
            }
        }
        return m
    }

    /// How often a miss becomes two — only on days that were asked for, consecutive asked-for days.
    func secondMissRate(_ h: Habit, _ ws: String, _ n: Int) -> (misses: Int, doubles: Int, rate: Double?) {
        let done = h.doneKeys
        var seq: [Bool] = []
        let first = DayKey.add(ws, days: -7 * (n - 1))
        for k in DayKey.keys(from: first, to: today) {
            if let born = h.createdAt, k < born { continue }
            if h.skip.contains(k) || !h.isScheduled(k) { continue }
            seq.append(done.contains(k))
        }
        var misses = 0, doubles = 0
        if seq.count > 1 {
            for i in 0..<(seq.count - 1) where !seq[i] {
                misses += 1
                if !seq[i + 1] { doubles += 1 }
            }
        }
        return (misses, doubles, misses > 0 ? Double(doubles) / Double(misses) : nil)
    }

    /// Circular mean of the start clock times, in minutes after midnight.
    static func meanStartMin(_ sessions: [Session]) -> Int? {
        guard !sessions.isEmpty else { return nil }
        var x = 0.0, y = 0.0
        for s in sessions {
            let c = DayKey.calendar.dateComponents([.hour, .minute], from: s.start)
            let a = Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) / 1440 * 2 * .pi
            x += cos(a); y += sin(a)
        }
        var frac = atan2(y, x) / (2 * .pi)
        if frac < 0 { frac += 1 }
        return Int((frac * 1440).rounded()) % 1440
    }

    // MARK: How it went (lastWeekNotes, app.js 2969)

    struct LastWeekNote: Identifiable { var habit: Habit; var score: Double; var text: String; var id: String { habit.id } }

    func lastWeekNotes() -> [LastWeekNote] {
        let ws = self.ws
        var out: [LastWeekNote] = []
        for h in data.activeHabits where h.type != .timer {
            var prior: [String] = []
            for i in 1...Insights.noteWeeks {
                let w = DayKey.add(ws, days: -7 * i)
                if let born = h.createdAt, DayKey.add(w, days: 6) < born { continue }
                prior.append(w)
            }
            if prior.count < 3 { continue }

            if h.type == .weekly {
                let target = h.target ?? 1
                let count = h.weekDoneCount(ws)
                if count >= target {
                    var since = 0
                    for w in prior { if h.weekDoneCount(w) >= target { break }; since += 1 }
                    if since >= prior.count {
                        out.append(.init(habit: h, score: 4, text: "\(h.name) made \(target) for the first time in \(prior.count) weeks — \(count) of \(target)."))
                    } else if since >= 2 {
                        out.append(.init(habit: h, score: 3.5, text: "\(h.name) hit \(target) again after \(since) weeks of not quite getting there."))
                    } else {
                        var run = 1
                        for w in prior { if h.weekDoneCount(w) >= target { run += 1 } else { break } }
                        if run >= 3 {
                            out.append(.init(habit: h, score: 2.8, text: "\(run) weeks in a row at \(target) or better for \(h.name). That is the run to protect."))
                        }
                    }
                } else {
                    var run = 0
                    for w in prior { if h.weekDoneCount(w) >= target { run += 1 } else { break } }
                    if run >= 2 {
                        out.append(.init(habit: h, score: 3.6, text: "\(h.name) ended on \(count) of \(target), after \(run) weeks that made it. One week is not a trend — the week after a broken run is the one that decides."))
                    }
                }
            } else {
                let done = h.doneKeys
                func week(_ w: String) -> (dn: Int, sched: Int) {
                    var dn = 0, sched = 0
                    for i in 0..<7 {
                        let k = DayKey.add(w, days: i)
                        if h.skip.contains(k) || !h.isScheduled(k) { continue }
                        sched += 1
                        if done.contains(k) { dn += 1 }
                    }
                    return (dn, sched)
                }
                let now = week(ws)
                if now.sched == 0 { continue }
                let rates = prior.map { week($0) }.filter { $0.sched > 0 }.map { Double($0.dn) / Double($0.sched) }
                if rates.count < 3 { continue }
                let rate = Double(now.dn) / Double(now.sched)
                let best = rates.max() ?? 0
                let avg = rates.reduce(0, +) / Double(rates.count)
                if rate > best {
                    out.append(.init(habit: h, score: 4, text: "\(now.dn) of \(now.sched) on \(h.name) — better than any of the last \(rates.count) weeks."))
                } else if rate <= avg - 0.25 {
                    out.append(.init(habit: h, score: 3.4, text: "\(h.name) ran \(now.dn) of \(now.sched), against \(Int((avg * 100).rounded()))% usually. Worth a thought about what was different, before it settles in."))
                } else if rate == 1 && now.sched >= 5 {
                    var run = 1
                    for w in prior { let x = week(w); if x.sched > 0 && x.dn == x.sched { run += 1 } else { break } }
                    if run >= 2 { out.append(.init(habit: h, score: 2.6, text: "\(run) clean weeks in a row on \(h.name).")) }
                }
            }
        }
        let sorted = out.enumerated().sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }.map(\.element)
        var seen = Set<String>()
        return Array(sorted.filter { seen.insert($0.habit.id).inserted }.prefix(2))
    }

    // MARK: What to try next week (weekNotes, app.js 3077)

    struct WeekNote: Identifiable {
        var id = UUID()
        var habit: Habit?
        var aspiration: Aspiration?
        var score: Double
        var topic: String
        var title: String
        var body: String
        var quietNote = false
    }

    func weekNotes() -> [WeekNote] {
        let ws = self.ws
        var notes: [WeekNote] = []
        let live = data.activeHabits
        let names = DayKey.longNames
        let weeks = Insights.noteWeeks

        for h in live where h.type != .timer {
            let w = weekdayMisses(h, ws, weeks)
            let name = h.name

            // The weekday that costs the most — daily habits only.
            if h.type == .daily && w.totalMiss >= 5 && w.totalSched >= 12 {
                var worst = 0
                for i in 1..<7 where w.miss[i] > w.miss[worst] { worst = i }
                let share = Double(w.miss[worst]) / Double(w.totalMiss)
                if w.miss[worst] >= 3 && share >= 0.3 && w.sched[worst] >= 3 {
                    notes.append(WeekNote(habit: h, score: 3 + share, topic: "weekday",
                        title: "\(names[worst]) is where \(name) slips",
                        body: "\(w.miss[worst]) of your last \(w.totalMiss) misses fell on a \(names[worst]). Decide this week what \(names[worst])'s version looks like — the shortest one that still counts — rather than deciding on the day."))
                }
            }

            if h.type == .weekly {
                let target = h.target ?? 1
                var nearly = 0, short = 0
                for x in recentWeeks(ws, weeks) {
                    let c = h.weekDoneCount(x)
                    if c == target - 1 { nearly += 1 }
                    if c < target { short += 1 }
                }
                if nearly >= 2 {
                    notes.append(WeekNote(habit: h, score: 3.5, topic: "weekly-target",
                        title: "\(nearly) weeks ended one short",
                        body: "\(name) finished on \(target - 1) of \(target) in \(nearly) of the last \(weeks) weeks. One more day in each and they would all have counted. Being at \(max(target - 2, 1)) by Thursday is what buys room for a bad day at the weekend."))
                }
                let met = weeks - short
                if short >= 3 && met >= 2 {
                    var blankShort = [Int](repeating: 0, count: 7), blankMet = [Int](repeating: 0, count: 7)
                    let done = h.doneKeys
                    for x in recentWeeks(ws, weeks) {
                        let failed = h.weekDoneCount(x) < target
                        for i in 0..<7 {
                            if done.contains(DayKey.add(x, days: i)) { continue }
                            if failed { blankShort[i] += 1 } else { blankMet[i] += 1 }
                        }
                    }
                    var worst = -1
                    var bestLift = 0.0
                    for i in 0..<7 {
                        let lift = Double(blankShort[i]) / Double(short) - Double(blankMet[i]) / Double(met)
                        if lift > bestLift { bestLift = lift; worst = i }
                    }
                    if worst >= 0 && bestLift >= 0.5 && blankShort[worst] >= 3 {
                        notes.append(WeekNote(habit: h, score: 3.8, topic: "weekly-target",
                            title: "The weeks that fail have a \(names[worst]) in common",
                            body: "\(name) came up short \(short) times, and \(names[worst]) was blank in \(blankShort[worst] == short ? "every one" : "\(blankShort[worst]) of them") \u{2014} against \(blankMet[worst]) of the \(met) weeks you made the target. That is the day that decides it, whatever the rest of the week looks like."))
                    }
                }
            }

            // Whether one miss turns into two — daily habits only.
            let sm = h.type == .daily ? secondMissRate(h, ws, weeks) : (misses: 0, doubles: 0, rate: Double?.none)
            if sm.misses >= 6, let rate = sm.rate {
                if rate >= 0.5 {
                    notes.append(WeekNote(habit: h, score: 4, topic: "recovery",
                        title: "With \(name), one miss usually becomes two",
                        body: "\(sm.doubles) of your \(sm.misses) missed days were followed by another. That makes the day after a miss the most valuable day you have — do a token version of it rather than nothing, and the run survives."))
                } else if rate <= 0.25 {
                    notes.append(WeekNote(habit: h, score: 2, topic: "recovery",
                        title: "You come back well on \(name)",
                        body: "Only \(sm.doubles) of \(sm.misses) misses turned into two days off. That recovery is doing more for the total than any perfect week would — keep missing singly."))
                }
            }
        }

        // Aspirations answer for themselves — said once, then held for a month.
        for c in coverage(ws) {
            if c.quiet >= 3 && nudgeAllowed("quiet:" + c.asp.id) {
                notes.append(WeekNote(habit: c.habits.first, aspiration: c.asp, score: 4.2, topic: "aspiration",
                    title: "“\(c.asp.title)” has gone quiet",
                    body: "Nothing has run under it for \(c.quiet) weeks. That is either a run of bad weeks or a sign it is no longer what you want. Both are worth knowing, and only you can say which.",
                    quietNote: true))
            } else if c.total == 0 && nudgeAllowed("empty:" + c.asp.id) {
                notes.append(WeekNote(habit: nil, aspiration: c.asp, score: 3.9, topic: "aspiration",
                    title: "“\(c.asp.title)” has no habits under it",
                    body: "Nothing is being tracked towards it, so nothing can be said about it week to week. Edit a habit and use Serves, or let this one go."))
            }
        }
        if !data.liveAspirations.isEmpty {
            let loose = unattachedHabits
            if !loose.isEmpty && nudgeAllowed("loose") {
                notes.append(WeekNote(habit: loose[0], score: 2.4, topic: "aspiration",
                    title: loose.count == 1 ? "\(loose[0].name) serves nothing" : "\(loose.count) habits serve nothing",
                    body: "\(loose.count == 1 ? "It is" : "They are") tracked but not attached to any aspiration. That is a perfectly good answer — not everything has to ladder up to something. It is only worth saying once."))
            }
        }

        // Fasting
        for h in live where h.type == .timer {
            let sess = h.sessions.filter { $0.e != nil }.sorted { $0.e! < $1.e! }
            guard let start = DayKey.date(DayKey.add(ws, days: -7 * (weeks - 1))) else { continue }
            let windowStart = start.timeIntervalSince1970 * 1000
            let recent = sess.filter { $0.e! >= windowStart }
            guard recent.count >= 6 else { continue }
            if let goalH = h.goalHours {
                let avg = recent.reduce(0.0) { $0 + ($1.e! - $1.s) } / Double(recent.count)
                let goal = goalH * 3_600_000
                let gap = goal - avg
                if gap >= 20 * 60_000 {
                    notes.append(WeekNote(habit: h, score: 3, topic: "fast-length",
                        title: "Your fasts average \(Fmt.duration(avg)) against a \(Fmt.hours(goalH))h goal",
                        body: "Over \(recent.count) fasts you are \(Fmt.duration(gap)) short on average. That is usually the stop time rather than the start — a fixed hour to eat is easier to hold than a fixed length."))
                } else if gap <= -20 * 60_000 {
                    notes.append(WeekNote(habit: h, score: 2, topic: "fast-length",
                        title: "You are running past your \(Fmt.hours(goalH))h goal",
                        body: "\(recent.count) fasts averaged \(Fmt.duration(avg)). Either the goal is set lower than what you actually do, or the extra is unplanned — worth deciding which."))
                }
            }
            let half = recent.count / 2
            if let early = Insights.meanStartMin(Array(recent[..<half])), let late = Insights.meanStartMin(Array(recent[half...])) {
                var diff = late - early
                if diff > 720 { diff -= 1440 }
                if diff < -720 { diff += 1440 }
                if abs(diff) >= 25 {
                    func hhmm(_ m: Int) -> String { String(format: "%02d:%02d", m / 60, m % 60) }
                    notes.append(WeekNote(habit: h, score: 2.6, topic: "fast-drift",
                        title: "You have been starting \(abs(diff)) minutes \(diff > 0 ? "later" : "earlier")",
                        body: "The first half of these \(recent.count) fasts began around \(hhmm(early)), the second half around \(hhmm(late)). "
                            + (diff > 0 ? "A later start pushes the whole rhythm, and the hour you eat is the easier end to fix."
                                        : "Whatever changed is working in your favour — it is worth knowing what it was.")))
                }
            }
        }

        // Selection: best first, one story per owner and topic, a wall of advice is read once.
        let sorted = notes.enumerated().sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }.map(\.element)
        func owner(_ n: WeekNote) -> String { n.aspiration.map { "asp:" + $0.id } ?? n.habit?.id ?? "" }
        var bestOf = Set<String>()
        let deduped = sorted.filter { bestOf.insert(owner($0) + "|" + $0.topic).inserted }
        var picked: [WeekNote] = []
        var seen = Set<String>()
        for n in deduped where picked.count < Insights.notesShown {
            if seen.insert(owner(n)).inserted { picked.append(n) }
        }
        for n in deduped where picked.count < Insights.notesShown {
            if !picked.contains(where: { $0.id == n.id }) { picked.append(n) }
        }
        return picked
    }

    /// The nudge keys of the aspiration notes being shown (marked as seen when the screen opens).
    static func nudgeKeys(of notes: [WeekNote]) -> [String] {
        notes.filter { $0.topic == "aspiration" }.map { n in
            if let a = n.aspiration { return (n.quietNote ? "quiet:" : "empty:") + a.id }
            return "loose"
        }
    }

    // MARK: Something new (app.js 3337)

    func suggestions(_ count: Int) -> [SuggestedHabit] {
        let mine = data.liveHabits.map { $0.name.lowercased() }
        let free = SuggestedHabit.all.filter { s in
            let words = (s.match + " " + s.name.lowercased()).split(whereSeparator: \.isWhitespace).map(String.init)
            return !mine.contains { n in words.contains { $0.count > 3 && n.contains($0) } }
        }
        if free.isEmpty { return [] }
        let ms = (DayKey.date(DayKey.weekStartKey(today))?.timeIntervalSince1970 ?? 0) * 1000
        let week = Int((ms / (7 * 86400e3)).rounded(.down))
        return (0..<min(count, free.count)).map { free[(week + $0) % free.count] }
    }

    // MARK: The week in words (app.js 3418)

    static func proseList(_ items: [String]) -> String {
        if items.isEmpty { return "" }
        if items.count == 1 { return items[0] }
        return items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    static func clause(_ r: WeekRow) -> String {
        let n = r.habit.name
        switch r.habit.type {
        case .timer:
            return r.fasts > 0 ? "\(n) recorded \(r.fasts) fast\(r.fasts == 1 ? "" : "s") averaging \(Fmt.duration(r.avg ?? 0))" : "\(n) recorded nothing"
        case .weekly:
            return r.met == true ? "\(n) reached \(r.count) of \(r.target)" : "\(n) came up short at \(r.count) of \(r.target)"
        case .daily:
            if r.sched == 0 { return "\(n) had nothing scheduled" }
            return r.dn >= r.sched ? "\(n) ran every one of its \(r.sched) days" : "\(n) ran \(r.dn) of \(r.sched) days"
        }
    }

    func summaryParagraphs(report: WeekReport? = nil) -> [String] {
        let report = report ?? WeekReport.make(data, ws: ws, today: today)
        if report.rows.isEmpty { return [] }
        func long(_ k: String) -> String { DayKey.date(k).map(Fmt.dayMonthLong) ?? k }
        var paras: [String] = []

        var opening = "Between \(long(report.ws)) and \(long(report.we)) you ticked \(report.ticks) day\(report.ticks == 1 ? "" : "s") across \(report.rows.count) habit\(report.rows.count == 1 ? "" : "s"). "
            + Insights.proseList(report.rows.map(Insights.clause)) + "."
        if report.judged > 0 {
            opening += report.met == report.judged ? " Everything with a target made it."
                : report.met == 0 ? " Nothing with a target made it, which is worth a moment rather than a shrug."
                : " That is \(report.met) of \(report.judged) targets met."
        }
        paras.append(opening)

        let cover = coverage(report.ws).filter { $0.total > 0 }
        if !cover.isEmpty {
            paras.append(cover.map { c in
                "Towards “\(c.asp.title)”, \(c.ran) of \(c.total) habit\(c.total == 1 ? "" : "s") ran"
                    + (c.quiet >= 3 ? " — nothing has under it for \(c.quiet) weeks now" : "") + "."
            }.joined(separator: " "))
        }

        let past = lastWeekNotes()
        if !past.isEmpty { paras.append(past.map(\.text).joined(separator: " ")) }

        let notes = Array(weekNotes().prefix(2))
        if !notes.isEmpty {
            paras.append("Looking further back than one week: " + notes.map { n in
                if let h = n.habit, n.body.contains(h.name) { return n.body }
                return "\(n.title). \(n.body)"
            }.joined(separator: " "))
        } else if past.isEmpty {
            paras.append("There is not enough history yet to say anything about patterns. A weekday that costs you, or a run you tend to break, needs several weeks before it is a pattern rather than a coincidence.")
        }

        if let pick = suggestions(1).first {
            paras.append("If you wanted something new, \u{201C}\(pick.name)\u{201D} (\(pick.type == .weekly ? "\(pick.target ?? 1) times a week" : "daily")) is one to consider. \(pick.why)")
        }
        return paras
    }

    /// "My week, 16 Nov – 22 Nov" + the paragraphs.
    func summaryText(report: WeekReport? = nil) -> String {
        let paras = summaryParagraphs(report: report)
        if paras.isEmpty { return "" }
        func short(_ k: String) -> String { DayKey.date(k).map(Fmt.dayMonth) ?? k }
        return "My week, \(short(ws)) – \(short(DayKey.add(ws, days: 6)))\n\n" + paras.joined(separator: "\n\n")
    }
}

// MARK: - Habit suggestions

struct SuggestedHabit: Identifiable, Hashable {
    var name: String
    var icon: String
    var type: HabitType
    var target: Int? = nil
    var match: String
    var why: String
    var id: String { name }
    var kind: String { type == .weekly ? "\(target ?? 1)× a week" : "daily" }
    var prefill: HabitPrefill { HabitPrefill(name: name, icon: icon, type: type, target: target) }

    static let all: [SuggestedHabit] = [
        .init(name: "Walk 30 minutes", icon: "shoe", type: .daily, match: "walk spazier gehen steps",
              why: "The cheapest thing you can add to an endurance base, and the one that survives a bad week — it still happens when a proper session does not."),
        .init(name: "Strength", icon: "dumbbell", type: .weekly, target: 2, match: "strength gym kraft weights hantel lift",
              why: "Twice a week is where most of the benefit sits. It is also what protects the joints that long endurance days load."),
        .init(name: "Mobility 10 min", icon: "leaf", type: .daily, match: "mobility stretch dehnen yoga beweglich",
              why: "Ten minutes is short enough to survive a busy evening, which is the only reason it gets done at all."),
        .init(name: "Lights out by 22:30", icon: "bed", type: .daily, match: "sleep bed schlaf bett lights",
              why: "Sleep is the one input that moves everything else — training, fasting, mood. Tracking the bedtime works better than tracking the sleep."),
        .init(name: "No phone after 21:00", icon: "phoneOff", type: .daily, match: "phone handy screen bildschirm",
              why: "Pairs with a bedtime habit rather than competing with it: the earlier one is what makes the later one possible."),
        .init(name: "Read 20 minutes", icon: "book", type: .daily, match: "read lesen buch book",
              why: "An evening habit that is genuinely easier than the thing it replaces, which is rare."),
        .init(name: "Water, 2 litres", icon: "glass", type: .daily, match: "water wasser trink hydrat",
              why: "Easy to assume you are doing and easy to be wrong about. Worth a fortnight of tracking even if you then stop."),
        .init(name: "Breathing, 5 minutes", icon: "waves", type: .daily, match: "breath atem breathing wim",
              why: "The shortest route to a calmer evening, and it costs nothing but the five minutes."),
        .init(name: "Three lines in a journal", icon: "pen", type: .daily, match: "journal tagebuch write schreib note",
              why: "Three lines, not a page. The low bar is the point — it is what makes the entry on a tired day possible."),
        .init(name: "Weigh in", icon: "pulse", type: .weekly, target: 1, match: "weigh wiegen weight gewicht scale",
              why: "Once a week, same day, same time. More often than that measures water, not progress."),
        .init(name: "Time outdoors", icon: "mountain", type: .daily, match: "outdoor draussen nature natur sun",
              why: "Daylight early in the day does more for sleep than most things done in the evening."),
        .init(name: "Call someone", icon: "chat", type: .weekly, target: 1, match: "call anruf friend freund family familie",
              why: "The one habit on this list that is not about you, and the easiest to let slide once a week goes badly."),
    ]
}

let aspirationStarters = [
    "Strong and durable into my seventies",
    "Healthy enough to keep doing what I love",
    "Calm, rested and clear-headed",
    "Someone who finishes what he starts",
]
