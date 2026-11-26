import SwiftUI

// Last month (web `renderMonthScreen` 3597): the month that ended — a chart of ticks per calendar week and
// one row per habit with the change against the month before.

struct MonthRow: Identifiable {
    var habit: Habit
    var mid = ""
    var delta = ""
    var trend: WeekRow.Trend = .flat
    /// Longest run inside the month (daily habits only).
    var best: Int?
    var id: String { habit.id }
}

struct MonthReport {
    var year: Int
    var month: Int
    var rows: [MonthRow]
    /// (the Monday each week began, ticks inside the month that week), at most six weeks.
    var weeks: [(start: String, n: Int)]

    var monthName: String {
        guard let d = DayKey.calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return "" }
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMMM"); return f.string(from: d)
    }
    var total: Int { weeks.reduce(0) { $0 + $1.n } }
    var ceiling: Int { max(1, weeks.map(\.n).max() ?? 0) }
    var labels: [String] { weeks.map { String(DayKey.calendar.component(.day, from: DayKey.date($0.start) ?? DayKey.now)) } }

    var caption: String {
        guard total > 0 else { return "Nothing was ticked in \(monthName)." }
        var best = weeks[0]
        for w in weeks where w.n > best.n { best = w }
        let d = DayKey.date(best.start).map(Fmt.dayMonthLong) ?? best.start
        return "\(total) in all. The week of \(d) was the strongest, with \(best.n). Numbers under the bars are the day each week began."
    }
    var emptyText: String {
        "Nothing to review yet. Everything you track began during or after \(monthName), so there is no complete month to report on."
    }

    /// The month that has ended: the one before today's (January gives last December).
    static func lastPeriod(today: String = DayKey.today()) -> (year: Int, month: Int) {
        let c = DayKey.calendar.dateComponents([.year, .month], from: DayKey.date(today) ?? DayKey.now)
        let y = c.year ?? 1970, m = c.month ?? 1
        return m == 1 ? (y - 1, 12) : (y, m - 1)
    }

    static func make(_ data: TrackingData, year py: Int, month pm: Int, today: String = DayKey.today()) -> MonthReport {
        let cal = DayKey.calendar
        let first = cal.date(from: DateComponents(year: py, month: pm, day: 1)) ?? DayKey.now
        let firstKey = DayKey.key(first)
        let lastKey = DayKey.key(DayKey.add(cal.date(byAdding: .month, value: 1, to: first) ?? first, days: -1))
        let ppy = pm == 1 ? py - 1 : py, ppm = pm == 1 ? 12 : pm - 1
        let habits = data.activeHabits.filter { $0.createdAt == nil || $0.createdAt! < firstKey }

        let rows: [MonthRow] = habits.map { h in
            var row = MonthRow(habit: h)
            switch h.type {
            case .timer:
                let cur = h.fastStats(year: py, month: pm), prev = h.fastStats(year: ppy, month: ppm)
                row.mid = cur.n > 0 ? "\(cur.n) fast\(cur.n == 1 ? "" : "s") · Ø \(Fmt.duration(cur.avg ?? 0)) h" : "no fasts"
                if let c = cur.avg, let p = prev.avg {
                    let d = c - p
                    row.delta = (d < 0 ? "–" : "+") + Fmt.duration(abs(d))
                    row.trend = d > 0 ? .up : d < 0 ? .down : .flat
                }
            case .weekly:
                let cur = h.monthStats(year: py, month: pm, today: today), prev = h.monthStats(year: ppy, month: ppm, today: today)
                row.mid = "\(cur.done)× checked off"
                let d = cur.done - prev.done
                row.delta = (d < 0 ? "–" : d > 0 ? "+" : "±") + String(abs(d)) + "×"
                row.trend = d > 0 ? .up : d < 0 ? .down : .flat
            case .daily:
                let m = h.monthStats(year: py, month: pm, today: today)
                row.mid = "\(m.done)/\(m.scheduled) days"
                let best = h.bestRun(from: firstKey, through: min(lastKey, today))
                row.best = best
                row.delta = String(best)
                row.trend = best > 0 ? .up : .flat
            }
            return row
        }

        // Ticks per Monday-first calendar week, only days inside the month.
        var weeks: [(start: String, n: Int)] = []
        var w = DayKey.weekStartKey(firstKey)
        var i = 0
        while i < 6 && w <= lastKey {
            var n = 0
            for h in habits {
                let done = h.doneKeys
                for d in 0..<7 {
                    let k = DayKey.add(w, days: d)
                    if k >= firstKey && k <= lastKey && done.contains(k) { n += 1 }
                }
            }
            weeks.append((w, n))
            w = DayKey.add(w, days: 7); i += 1
        }
        return MonthReport(year: py, month: pm, rows: rows, weeks: weeks)
    }
}

extension Habit {
    /// Longest run of done scheduled days between two days (skip days excused, unscheduled days passed over).
    func bestRun(from start: String, through end: String) -> Int {
        let done = doneKeys
        var best = 0, run = 0
        for k in DayKey.keys(from: start, to: end) {
            if !isScheduled(k) { continue }
            if done.contains(k) { run += 1; best = max(best, run) }
            else if !skip.contains(k) { run = 0 }
        }
        return best
    }
}

struct LastMonthScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav

    var body: some View {
        let p = MonthReport.lastPeriod()
        let report = MonthReport.make(store.data, year: p.year, month: p.month)
        Page(id: "screen-lastmonth") {
            PageTitle(title: "\(report.monthName) in review", subtitle: String(p.year))
            if report.rows.isEmpty {
                EmptyNote(text: report.emptyText, id: "month-empty")
            } else {
                BarChartCard(heading: "Ticks in each week of \(report.monthName)", values: report.weeks.map(\.n),
                             ceiling: report.ceiling, labels: report.labels, caption: report.caption, id: "month-chart")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(report.rows.enumerated()), id: \.element.id) { i, r in
                        Button { nav.open(habit: r.habit.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                ReviewRowTop(habit: r.habit, mid: r.mid, delta: r.delta, trend: r.trend, flame: r.best != nil)
                                if let b = r.best {
                                    Text("Longest run of the month: \(b) day\(b == 1 ? "" : "s").").font(.footnote).foregroundStyle(Ink.dim)
                                }
                            }
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Ink.border).frame(height: 1) } }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("month-row-\(r.habit.id)")
                    }
                }
                .padding(.vertical, 4).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Ink.surface).shadow(color: Ink.shadow, radius: 5, y: 2))
            }
        }
        .reviewChrome("Last month")
    }
}
