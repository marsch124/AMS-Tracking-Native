import SwiftUI

// Stats (web `renderStats` 4292): a card per habit, the fasting rhythm, the Achievements. Rules 5.6 and 7.2.

// MARK: - The figures

/// What the fasting rhythm card shows (web `fastRhythm` 4148). nil until five fasts are finished.
struct FastRhythm: Equatable {
    var startMin: Int
    var avgByDay: [Double?]
    var avgAll: Double
    var count: Int

    /// The weekday with the highest average fast (the first one wins a tie).
    var bestIndex: Int? {
        var best: Int?
        for (i, v) in avgByDay.enumerated() {
            guard let v else { continue }
            if best == nil || v > (avgByDay[best!] ?? 0) { best = i }
        }
        return best
    }
    var usualStart: String { String(format: "%02d:%02d", startMin / 60, startMin % 60) }
}

extension Habit {
    func fastRhythm() -> FastRhythm? {
        let sess = finishedSessions
        guard sess.count >= 5, let startMin = Insights.meanStartMin(sess) else { return nil }
        var sums = [Double](repeating: 0, count: 7), counts = [Int](repeating: 0, count: 7)
        for s in sess {
            guard let end = s.end, let e = s.e else { continue }
            let wd = DayKey.weekday(end)
            sums[wd] += e - s.s; counts[wd] += 1
        }
        let avg: [Double?] = (0..<7).map { counts[$0] > 0 ? sums[$0] / Double(counts[$0]) : nil }
        let all = sess.reduce(0.0) { $0 + ($1.e! - $1.s) } / Double(sess.count)
        return FastRhythm(startMin: startMin, avgByDay: avg, avgAll: all, count: sess.count)
    }

    /// The four tiles of a habit's stat card: streak, best, this month, last month.
    func statTiles(today: String = DayKey.today()) -> [(value: String, label: String)] {
        let weekly = type == .weekly
        let unit = weekly ? "wk" : "d"
        let now = DayKey.date(today) ?? DayKey.now
        let cal = DayKey.calendar
        let first = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let prev = cal.date(byAdding: .month, value: -1, to: first) ?? now
        func month(_ d: Date) -> String {
            let c = cal.dateComponents([.year, .month], from: d)
            let m = monthStats(year: c.year ?? 0, month: c.month ?? 1, today: today)
            return weekly ? "\(m.done)×" : (m.scheduled > 0 ? "\(m.pct)%" : "–")
        }
        return [("\(shownStreak(today: today))\(unit)", "streak"), ("\(bestStreak(today: today))\(unit)", "best"),
                (month(now), "this month"), (month(prev), "last month")]
    }

    /// "2 days to your record", or nil.
    func recordLine(today: String = DayKey.today()) -> String? {
        guard let gap = recordGap(today: today) else { return nil }
        let word = type == .weekly ? (gap == 1 ? "week" : "weeks") : (gap == 1 ? "day" : "days")
        return "\(gap) \(word) to your record"
    }
}

/// The totals and milestones of the Achievements card.
struct Achievements {
    var daysTracked: Int
    var bestStreak: Int
    var longestFast: Double

    init(_ habits: [Habit], today: String = DayKey.today()) {
        daysTracked = habits.reduce(0) { $0 + $1.doneKeys.count }
        bestStreak = habits.filter { $0.type != .weekly }.map { $0.longestStreak(today: today) }.max() ?? 0
        longestFast = habits.flatMap(\.sessions).compactMap { s in s.e.map { $0 - s.s } }.max() ?? 0
    }

    /// Milestones reached, and the next one to aim for.
    static func milestones(_ h: Habit, today: String = DayKey.today()) -> (earned: [Int], next: Int?, unit: String) {
        let weekly = h.type == .weekly
        let best = h.bestStreak(today: today)
        let list = weekly ? Milestones.weeks : Milestones.days
        return (list.filter { best >= $0 }, list.first { best < $0 }, weekly ? "w" : "d")
    }
}

// MARK: - The screen

struct StatsScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav

    var body: some View {
        let _ = store.tick
        let habits = store.data.activeHabits
        Page(id: "screen-stats") {
            PageTitle(title: "Stats", subtitle: "All habits at a glance")
            VStack(spacing: 8) {
                ListButton(icon: "bulb", title: "Last week’s analysis", id: "btn-notes") { nav.open(.lastWeek) }
                ListButton(icon: "grid", title: "Last month", id: "btn-month") { nav.open(.lastMonth) }
                ListButton(icon: "mountain", title: "Aspirations", id: "btn-asp") { nav.open(.aspirations) }
            }
            if habits.isEmpty {
                Text("No habits yet.").font(.subheadline).foregroundStyle(Ink.dim).accessibilityIdentifier("stats-empty")
            } else {
                ForEach(habits) { h in HabitStatsCard(habit: h) }
                ForEach(habits.filter { $0.type == .timer }) { h in
                    if let r = h.fastRhythm() { RhythmCard(habit: h, rhythm: r) }
                }
                AchievementsCard(habits: habits)
            }
        }
        .reviewChrome("Stats")
    }
}

/// Four figures in a row, each with its small label.
private struct TileRow: View {
    let tiles: [(value: String, label: String)]
    let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(tiles.indices, id: \.self) { i in
                VStack(spacing: 2) {
                    Text(tiles[i].value).font(.title3.weight(.heavy)).foregroundStyle(color)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(tiles[i].label.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(Ink.dim)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct HabitStatsCard: View {
    let habit: Habit
    @EnvironmentObject var nav: Nav

    var body: some View {
        let c = Color(hex: habit.color)
        let done = habit.doneKeys
        let today = DayKey.today()
        Button { nav.open(habit: habit.id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TrackIcon(name: habit.icon, size: 19, color: c)
                    Text(habit.displayName).font(.headline.weight(.heavy)).foregroundStyle(Ink.text).lineLimit(1)
                    Spacer(minLength: 0)
                }
                TileRow(tiles: habit.statTiles(today: today), color: c)
                if let line = habit.recordLine(today: today) {
                    HStack(spacing: 5) {
                        Flame(size: 15, color: c)
                        Text(line).font(.subheadline.weight(.bold)).foregroundStyle(c)
                    }
                    .accessibilityIdentifier("record-\(habit.id)")
                }
                // The last 30 days, oldest on the left, today on the right.
                HStack(spacing: 3) {
                    ForEach((0..<30).reversed(), id: \.self) { i in
                        let k = DayKey.add(today, days: -i)
                        ZStack {
                            if done.contains(k) { RoundedRectangle(cornerRadius: 4).fill(c) }
                            else if habit.skip.contains(k) {
                                RoundedRectangle(cornerRadius: 4).fill(Ink.border)
                                RoundedRectangle(cornerRadius: 4).strokeBorder(c.opacity(0.55), lineWidth: 1.5)
                            } else { RoundedRectangle(cornerRadius: 4).fill(Ink.border) }
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Last 30 days, \(done.filter { $0 >= DayKey.add(today, days: -29) && $0 <= today }.count) done")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Ink.surface).shadow(color: Ink.shadow, radius: 5, y: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stats-card-\(habit.id)")
    }
}

private struct RhythmCard: View {
    let habit: Habit
    let rhythm: FastRhythm

    var body: some View {
        let c = Color(hex: habit.color)
        let best = rhythm.bestIndex
        let maxV = rhythm.avgByDay.compactMap { $0 }.max() ?? 0
        DetailCard {
            HStack(spacing: 8) {
                TrackIcon(name: habit.icon, size: 19, color: c)
                Text("\(habit.name) rhythm").font(.headline.weight(.heavy)).foregroundStyle(Ink.text).lineLimit(1)
            }
            TileRow(tiles: [(rhythm.usualStart, "usual start"),
                            (best.map { DayKey.shortNames[$0] } ?? "–", "strongest day"),
                            (Fmt.duration(rhythm.avgAll) + "h", "avg fast")], color: c)
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(0..<7, id: \.self) { i in
                    let v = rhythm.avgByDay[i]
                    VStack(spacing: 3) {
                        Text(v.map { Self.hoursText($0) } ?? " ").font(.caption2).foregroundStyle(Ink.dim)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        ZStack(alignment: .bottom) {
                            Color.clear
                            if let v, maxV > 0 {
                                UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 7)
                                    .fill(c.opacity(i == best ? 1 : 0.55))
                                    .frame(maxWidth: 26)
                                    .frame(height: 90 * max(0.06, v / maxV))
                            } else {
                                RoundedRectangle(cornerRadius: 2).fill(Ink.border).opacity(0.5)
                                    .frame(maxWidth: 26).frame(height: 4)
                            }
                        }
                        .frame(height: 90)
                        Text(DayKey.letters[i]).font(.caption2.weight(i == best ? .bold : .regular))
                            .foregroundStyle(i == best ? Ink.text : Ink.dim)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityIdentifier("rhythm-\(habit.id)")
    }

    /// Hours with one decimal and a comma: "16,2".
    static func hoursText(_ ms: Double) -> String { String(format: "%.1f", ms / 3_600_000).replacingOccurrences(of: ".", with: ",") }
}

private struct AchievementsCard: View {
    let habits: [Habit]
    var body: some View {
        let a = Achievements(habits)
        DetailCard {
            HStack(spacing: 8) {
                TrackIcon(name: "trophy", size: 22, color: Ink.gold)
                Text("Achievements").font(.title3.weight(.heavy)).foregroundStyle(Ink.text)
            }
            TileRow(tiles: [(String(a.daysTracked), "days tracked"), ("\(a.bestStreak)d", "best streak"),
                            (a.longestFast > 0 ? Fmt.duration(a.longestFast) + "h" : "–", "longest fast")], color: Ink.gold)
            ForEach(habits) { h in
                let m = Achievements.milestones(h)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        TrackIcon(name: h.icon, size: 16, color: Color(hex: h.color))
                        Text(h.displayName).font(.subheadline.weight(.bold)).foregroundStyle(Ink.text).lineLimit(1)
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(m.earned, id: \.self) { n in
                            Text("\(n)\(m.unit)").font(.footnote.weight(.heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .background(Capsule().fill(Color(hex: h.color)))
                        }
                        if let next = m.next {
                            Text("\(next)\(m.unit)").font(.footnote.weight(.heavy)).foregroundStyle(Ink.dim)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .overlay(Capsule().strokeBorder(Ink.dim.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                        }
                    }
                }
                .accessibilityIdentifier("milestones-\(h.id)")
            }
        }
        .accessibilityIdentifier("achievements")
    }
}
