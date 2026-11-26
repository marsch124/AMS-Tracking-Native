import SwiftUI

// The cards on a habit's page (Lane A): calendar, year pixels, fasting stages, fasts.

private let dashed = StrokeStyle(lineWidth: 2, dash: [4, 3])

// MARK: - Calendar card (6.1)

struct CalendarCard: View {
    let habit: Habit
    @Binding var daySheet: DaySheet?
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = MonthGrid(containing: DayKey.now).first
    @State private var noteMode = false
    @State private var flash: String?
    @State private var flashOn = false

    private var today: String { DayKey.today() }
    private var isTimer: Bool { habit.type == .timer }

    var body: some View {
        let grid = MonthGrid(containing: shown)
        let atCurrent = DayKey.key(grid.first).prefix(7) == today.prefix(7)
        DetailCard {
            HStack(spacing: 8) {
                Text(Fmt.monthYear(grid.first)).font(.title3.weight(.heavy)).foregroundStyle(Ink.text)
                    .accessibilityIdentifier("cal-month")
                Spacer()
                if !atCurrent { pill("target", "Today", id: "cal-today") { shown = MonthGrid(containing: DayKey.now).first } }
                pill("pen", "Note", on: noteMode, id: "cal-note-mode") { noteMode.toggle() }
                chev("chevL", "Previous month", id: "cal-prev", enabled: true) { shown = grid.shifted(-1) }
                chev("chevR", "Next month", id: "cal-next", enabled: MonthGrid.canGoNext(from: shown, today: today)) { shown = grid.shifted(1) }
            }
            Text(hint).font(.footnote).foregroundStyle(Ink.dim)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(maximum: 52), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Text(DayKey.letters[i]).font(.caption2.weight(.bold)).foregroundStyle(Ink.dim)
                }
                ForEach(0..<grid.lead, id: \.self) { _ in Color.clear.frame(height: 1) }
                ForEach(Array(grid.keys.enumerated()), id: \.offset) { i, k in
                    Button { tap(k) } label: { cell(k, i + 1) }
                        .buttonStyle(.plain)
                        .disabled(isDisabled(k))
                        .accessibilityIdentifier("cal-day-\(k)")
                }
            }
            .frame(maxWidth: .infinity)
            if isTimer { legend }
            monthNotes(grid)
            Button { daySheet = .skipRange(habit: habit.id) } label: {
                HStack(spacing: 8) {
                    TrackIcon(name: "case", size: 18, color: Ink.dim)
                    Text("Skip several days (vacation)…").font(.footnote.weight(.semibold)).foregroundStyle(Ink.dim)
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.border, style: dashed))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("skip-range-btn")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar-card")
        .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { v in
            let dx = v.translation.width, dy = v.translation.height
            guard abs(dx) >= 50, abs(dx) > 1.5 * abs(dy) else { return }
            if dx < 0 { if MonthGrid.canGoNext(from: shown, today: today) { shown = grid.shifted(1) } } else { shown = grid.shifted(-1) }
        })
        .onAppear { focusIfAsked() }
        .onChange(of: nav.focusDay) { _, _ in focusIfAsked() }
    }

    private var hint: String {
        if noteMode { return "Note mode: tap a day to write or edit its note." }
        if isTimer { return "Tap a day to record a forgotten fast (0 = skip day) or to edit a recorded one." }
        return "Tap a day to cycle: done → skip day → empty."
    }

    // MARK: Header buttons

    private func pill(_ icon: String, _ title: String, on: Bool = false, id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                TrackIcon(name: icon, size: 15, color: on ? .white : Ink.accent)
                Text(title).font(.footnote.weight(.bold)).foregroundStyle(on ? .white : Ink.accent)
            }
            .padding(.horizontal, 10).frame(minHeight: 34)
            .background(Capsule().fill(on ? Ink.accent : Ink.accent.opacity(0.12)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }

    private func chev(_ icon: String, _ label: String, id: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TrackIcon(name: icon, size: 16, color: Ink.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Ink.accent.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label).accessibilityIdentifier(id)
    }

    // MARK: Days

    private func isDisabled(_ k: String) -> Bool { k > today && !habit.skip.contains(k) }

    private func tap(_ k: String) {
        let future = k > today
        if noteMode {
            if !future || habit.skip.contains(k) { daySheet = .note(habit: habit.id, day: k) }
            return
        }
        if future {
            if habit.skip.contains(k) { store.update(habit.id) { $0.skip.remove(k) } }
            return
        }
        if isTimer {
            switch habit.fastTap(k) {
            case .removeSkip: store.update(habit.id) { $0.skip.remove(k) }
            case .editFast(let s): daySheet = .editFast(habit: habit.id, start: s)
            case .recordHours: daySheet = .hours(habit: habit.id, day: k)
            }
        } else if habit.parts != nil {
            daySheet = .parts(habit: habit.id, day: k)
        } else {
            store.update(habit.id) { $0.cycleHistoryDay(k) }
        }
    }

    @ViewBuilder private func cell(_ k: String, _ n: Int) -> some View {
        let isToday = k == today
        let flashing = flash == k && flashOn
        Group {
            if isTimer { timerCell(k, n, isToday: isToday) } else { plainCell(k, n, isToday: isToday) }
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.accent, lineWidth: flash == k ? 3 : 0).opacity(flashing || (flash == k && reduceMotion) ? 1 : 0))
        .scaleEffect(flashing && !reduceMotion ? 1.12 : 1)
    }

    private func plainCell(_ k: String, _ n: Int, isToday: Bool) -> some View {
        let c = Color(hex: habit.color)
        let future = k > today
        let done = !future && habit.isDone(k)
        let skip = !done && habit.skip.contains(k)
        return ZStack {
            if !skip { RoundedRectangle(cornerRadius: 12).fill(done ? c : Ink.border) }
            if skip { RoundedRectangle(cornerRadius: 12).strokeBorder(c, style: dashed) }
            if isToday { RoundedRectangle(cornerRadius: 12).strokeBorder(c, lineWidth: 2) }
            Text("\(n)").font(.system(size: 14.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(done ? .white : skip ? c : Ink.text)
            if habit.notes[k] != nil {
                Circle().fill(done ? .white : (skip ? c : Ink.text)).frame(width: 4, height: 4)
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(future && !skip ? 0.45 : skip ? 0.75 : habit.isScheduled(k) ? 1 : 0.5)
    }

    private func timerCell(_ k: String, _ n: Int, isToday: Bool) -> some View {
        let c = Color(hex: habit.color)
        let future = k > today
        return VStack(spacing: 2) {
            Text("\(n)").font(.system(size: 11, weight: .bold)).foregroundStyle(isToday ? Ink.text : Ink.dim)
            ZStack {
                if future {
                    if habit.skip.contains(k) { skipCircle(c) } else { Circle().stroke(Ink.border, lineWidth: 1.5).opacity(0.35) }
                } else {
                    switch habit.fastCell(k, today: today) {
                    case .met(let h): filled(Ink.green, "\(h)", .white)
                    case .under(let h): filled(Ink.border, "\(h)", Ink.text)
                    case .running(let h): filled(Ink.red, "\(h)", .white)
                    case .skip: skipCircle(c)
                    case .empty:
                        Circle().stroke(isToday ? Ink.dim : Ink.border, lineWidth: isToday ? 2 : 1.5)
                    }
                }
                if habit.notes[k] != nil {
                    Circle().fill(Ink.text).frame(width: 4, height: 4).frame(maxHeight: .infinity, alignment: .bottom).offset(y: 6)
                }
            }
            .frame(width: 30, height: 30)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
    }

    private func filled(_ bg: Color, _ text: String, _ fg: Color) -> some View {
        ZStack {
            Circle().fill(bg)
            Text(text).font(.system(size: 13, weight: .heavy).monospacedDigit()).foregroundStyle(fg)
        }
    }
    private func skipCircle(_ c: Color) -> some View {
        ZStack {
            Circle().strokeBorder(c, style: dashed)
            Text("–").font(.system(size: 14, weight: .heavy)).foregroundStyle(c)
        }
    }

    private var legend: some View {
        let c = Color(hex: habit.color)
        return HStack(spacing: 12) {
            key(Circle().fill(Ink.green), "goal met")
            key(Circle().fill(Ink.border), "fell short")
            key(Circle().fill(Ink.red), "running")
            key(Circle().strokeBorder(c, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])), "skip day")
        }
        .font(.caption.weight(.semibold)).foregroundStyle(Ink.dim)
        .accessibilityIdentifier("cal-legend")
    }
    private func key<S: View>(_ shape: S, _ text: String) -> some View {
        HStack(spacing: 4) { shape.frame(width: 12, height: 12); Text(text) }
    }

    @ViewBuilder private func monthNotes(_ grid: MonthGrid) -> some View {
        let notes = grid.keys.filter { habit.notes[$0] != nil }
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                ForEach(notes, id: \.self) { k in
                    Button { daySheet = .note(habit: habit.id, day: k) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(Int(k.suffix(2)) ?? 0)").font(.subheadline.weight(.heavy).monospacedDigit())
                                .foregroundStyle(Color(hex: habit.color)).frame(minWidth: 20, alignment: .trailing)
                            Text(habit.notes[k] ?? "").font(.subheadline).foregroundStyle(Ink.text)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("month-note-\(k)")
                }
            }
            .accessibilityIdentifier("month-notes")
        }
    }

    // MARK: Week-dot jump

    private func focusIfAsked() {
        guard let k = nav.focusDay, let d = DayKey.date(k) else { return }
        shown = MonthGrid(containing: d).first
        flash = k
        nav.focusDay = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.45)) { flashOn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                withAnimation(.easeInOut(duration: 0.3)) { flashOn = false }
                if flash == k { DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 1.5 : 0.4)) { if flash == k { flash = nil } } }
            }
        }
    }
}

// MARK: - Year card (6.2)

struct YearCard: View {
    let habit: Habit
    let year: Int
    var onShare: (Int) -> Void
    @EnvironmentObject var store: Store

    var body: some View {
        let today = DayKey.today()
        let c = Color(hex: habit.color)
        let months = Habit.yearKeys(year)
        DetailCard(title: String(year), trailing: AnyView(
            Button { onShare(year) } label: {
                HStack(spacing: 5) {
                    TrackIcon(name: "export", size: 15, color: Ink.accent)
                    Text("Poster").font(.footnote.weight(.bold)).foregroundStyle(Ink.accent)
                }
                .padding(.horizontal, 10).frame(minHeight: 34)
                .background(Capsule().fill(Ink.accent.opacity(0.12)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain).accessibilityLabel("Share \(year) as a poster")
            .accessibilityIdentifier("btn-share-\(year)")
        )) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 14, maximum: 20), spacing: 4)], spacing: 4) {
                ForEach(0..<12, id: \.self) { m in
                    Text(["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"][m])
                        .font(.system(size: 9, weight: .heavy)).foregroundStyle(Ink.dim)
                        .aspectRatio(1, contentMode: .fit)
                    ForEach(months[m], id: \.self) { k in
                        pixel(k, today, c)
                            .aspectRatio(1, contentMode: .fit)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if k <= today { store.showToast(habit.pixelToast(k, today: today)) }
                            }
                            .accessibilityIdentifier("pixel-\(k)")
                    }
                }
            }
            .accessibilityIdentifier("year-grid-\(year)")
            stats(today)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("year-card-\(year)")
    }

    @ViewBuilder private func pixel(_ k: String, _ today: String, _ c: Color) -> some View {
        switch habit.pixel(k, today: today) {
        case .done: RoundedRectangle(cornerRadius: 4).fill(c)
        case .skip:
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Ink.border)
                RoundedRectangle(cornerRadius: 4).strokeBorder(c.opacity(0.55), lineWidth: 1.5)
            }
        case .empty: RoundedRectangle(cornerRadius: 4).fill(Ink.border)
        case .future: RoundedRectangle(cornerRadius: 4).fill(Ink.border).opacity(0.35)
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(key).font(.subheadline.weight(.medium)).foregroundStyle(Ink.dim)
            Text(value).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(Ink.text)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private func stats(_ today: String) -> some View {
        let cur = Int(today.prefix(4)) ?? year
        VStack(spacing: 0) {
            if year == cur {
                if habit.type == .weekly {
                    let w = habit.weeklyStats(today: today)
                    row("Current streak", Fmt.count(habit.weeklyStreak(today: today), "week"))
                    row("Longest streak", Fmt.count(w.best, "week"))
                    row("Weeks met", "\(w.weeksMet) of \(w.weeksTotal)")
                } else {
                    let comp = habit.completion(today: today)
                    row("Current streak", Fmt.count(habit.currentStreak(today: today), "day"))
                    row("Longest streak", Fmt.count(habit.longestStreak(today: today), "day"))
                    row("Completion", "\(comp.pct)% (\(comp.done) of \(comp.total) days)")
                }
            } else {
                let s = habit.yearSummary(year, today: today)
                row("Days completed", "\(s.done) of \(s.scheduled)")
            }
        }
        .accessibilityIdentifier("year-stats-\(year)")
    }
}

// MARK: - Fasting stages (6.3)

struct StagesCard: View {
    let habit: Habit
    @EnvironmentObject var store: Store

    var body: some View {
        let _ = store.tick
        let now = DayKey.now
        let elapsedMs = habit.activeSession.map { now.timeIntervalSince1970 * 1000 - $0.s }
        let hours = elapsedMs.map { $0 / 3_600_000 }
        let current = hours.map { FastStage.current(hours: $0) }
        DetailCard(title: "Fasting stages") {
            track(hours: hours, current: current)
            Group {
                if let current, let elapsedMs {
                    (Text("Now: ").foregroundStyle(Ink.text)
                     + Text(current.name).foregroundStyle(Color(hex: current.hex)).bold()
                     + Text(" · \(Fmt.duration(elapsedMs)) h").foregroundStyle(Ink.text))
                } else {
                    Text("While a fast runs, a marker shows which stage you are in.").foregroundStyle(Ink.dim)
                }
            }
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("stages-now")
            Divider()
            ForEach(FastStage.all) { st in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(Color(hex: st.hex)).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(st.name).font(.subheadline.weight(.bold)).foregroundStyle(Ink.text)
                            Text(range(st)).font(.footnote).foregroundStyle(Ink.dim)
                        }
                        Text(st.hint).font(.footnote).foregroundStyle(Ink.dim)
                    }
                }
                .opacity(current != nil && current?.name != st.name ? 0.55 : 1)
            }
            Text("A popular approximation from fasting literature — every body is different. Not medical advice.")
                .font(.caption).foregroundStyle(Ink.dim)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stages-card")
    }

    private func range(_ st: FastStage) -> String {
        let all = FastStage.all
        guard let i = all.firstIndex(where: { $0.name == st.name }) else { return "" }
        return i == all.count - 1 ? "\(Int(st.from))h+" : "\(Int(st.from))–\(Int(all[i + 1].from))h"
    }

    private func track(hours: Double?, current: FastStage?) -> some View {
        let all = FastStage.all
        return GeometryReader { g in
            let w = g.size.width
            let pad = w * 10 / 320, span = w * 300 / 320
            let x: (Double) -> CGFloat = { h in pad + CGFloat(h / 20) * span }
            ZStack(alignment: .topLeading) {
                ForEach(Array(all.enumerated()), id: \.offset) { i, st in
                    let from = st.from, to = i + 1 < all.count ? all[i + 1].from : 20
                    RoundedRectangle(cornerRadius: 6).fill(Color(hex: st.hex))
                        .frame(width: x(to) - x(from) - 1, height: 12)
                        .offset(x: x(from), y: 16)
                        .opacity(current != nil && current?.name != st.name ? 0.3 : 1)
                }
                if let hours {
                    let mx = x(min(20, hours))
                    Capsule().fill(Ink.text).frame(width: 2.4, height: 26).offset(x: mx - 1.2, y: 5)
                    Circle().fill(Ink.text).frame(width: 5.2, height: 5.2).offset(x: mx - 2.6, y: 2.4)
                }
                ForEach([(0.0, "0h"), (4, "4h"), (12, "12h"), (16, "16h")], id: \.0) { h, t in
                    Text(t).font(.system(size: 10, weight: .bold)).foregroundStyle(Ink.dim)
                        .fixedSize().position(x: x(h) + (h == 0 ? 6 : 0), y: 40)
                }
                Text("20h+").font(.system(size: 10, weight: .bold)).foregroundStyle(Ink.dim)
                    .fixedSize().position(x: x(20) - 10, y: 40)
            }
        }
        .frame(height: 48)
        .accessibilityHidden(true)
    }
}

// MARK: - Fasts (6.4)

struct FastsCard: View {
    let habit: Habit
    @Binding var daySheet: DaySheet?
    @EnvironmentObject var store: Store

    var body: some View {
        let _ = store.tick
        let st = habit.fastStats
        let fin = habit.finishedSessions
        DetailCard(title: "Fasts") {
            if !fin.isEmpty {
                VStack(spacing: 0) {
                    row("Average", "\(Fmt.duration(st.average)) h")
                    row("Longest", "\(Fmt.duration(st.longest)) h")
                    row("Goal met", Fmt.count(st.goalMetDays, "day"))
                    row("Total fasts", "\(st.total)")
                }
                if fin.count >= 2 { chart(Array(fin.suffix(30))) }
                Text("Tap a fast to correct its times or delete it.").font(.footnote).foregroundStyle(Ink.dim)
            } else if habit.activeSession == nil {
                Text("No completed fasts yet — press the round button on the card to start one.")
                    .font(.footnote).foregroundStyle(Ink.dim)
            }
            VStack(spacing: 0) {
                if let a = habit.activeSession {
                    let started = a.start
                    listRow("In progress — started \(weekdayClock(started))",
                            "\(Fmt.duration(DayKey.now.timeIntervalSince1970 * 1000 - a.s)) h", strong: true, id: "fast-row-running") {
                        daySheet = .editFast(habit: habit.id, start: a.s)
                    }
                }
                ForEach(Array(fin.suffix(10).reversed()), id: \.s) { s in
                    Divider()
                    listRow(s.end.map { Fmt.weekdayDayMonth($0) } ?? "", "\(Fmt.duration((s.e ?? s.s) - s.s)) h", strong: false,
                            id: "fast-row-\(Int(s.s))") { daySheet = .editFast(habit: habit.id, start: s.s) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fasts-card")
    }

    private func weekdayClock(_ d: Date) -> String {
        DayKey.shortNames[DayKey.weekday(d)] + " " + Fmt.clock(d)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(key).font(.subheadline.weight(.medium)).foregroundStyle(Ink.dim)
            Text(value).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(Ink.text)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func listRow(_ left: String, _ right: String, strong: Bool, id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(left).font(.subheadline.weight(strong ? .semibold : .regular)).foregroundStyle(strong ? Ink.text : Ink.dim)
                Text(right).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(Ink.text)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }

    // The last 30 fasts as bars; a dashed line at the habit's goal.
    private func chart(_ list: [Session]) -> some View {
        let c = Color(hex: habit.color)
        let lens = list.map { (($0.e ?? $0.s) - $0.s) }
        let goalMs = (habit.goalHours ?? 0) * 3_600_000
        let maxV = max(lens.max() ?? 1, goalMs) * 1.12
        let plotH: CGFloat = 96
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { g in
                let slot = g.size.width / CGFloat(list.count)
                let bw = min(14, max(3, slot - 2))
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(Array(list.enumerated()), id: \.offset) { i, s in
                            Button { daySheet = .editFast(habit: habit.id, start: s.s) } label: {
                                ZStack(alignment: .bottom) {
                                    Color.clear
                                    RoundedRectangle(cornerRadius: 3).fill(c)
                                        .frame(width: bw, height: max(3, CGFloat(lens[i] / maxV) * plotH))
                                }
                                .frame(width: slot, height: plotH).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).accessibilityIdentifier("fast-bar-\(i)")
                        }
                    }
                    Rectangle().fill(Ink.border).frame(height: 1)
                    if goalMs > 0 {
                        let y = CGFloat(goalMs / maxV) * plotH
                        Path { p in p.move(to: CGPoint(x: 0, y: plotH - y)); p.addLine(to: CGPoint(x: g.size.width, y: plotH - y)) }
                            .stroke(Ink.dim.opacity(0.75), style: StrokeStyle(lineWidth: 1.3, dash: [5, 4]))
                            .allowsHitTesting(false)
                        Text("goal \(Fmt.hours(habit.goalHours ?? 0))h").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Ink.dim).frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(y: -(y + 2)).allowsHitTesting(false)
                    }
                }
            }
            .frame(height: plotH)
            Text("Last \(list.count) fasts · tap a bar to edit that fast.").font(.caption).foregroundStyle(Ink.dim)
        }
        .accessibilityIdentifier("fast-chart")
    }
}
