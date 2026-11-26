import SwiftUI

/// Today: one card per habit (list or two-column grid), then Last week and Last month. No header (web 1.48).
struct TodayScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @State private var daySheet: DaySheet?

    private var grid: Bool { store.data.settings.layout == "grid" }

    var body: some View {
        let _ = store.tick
        let habits = store.data.activeHabits
        ScrollView {
            VStack(spacing: 0) {
                if habits.isEmpty {
                    EmptyToday()
                } else if grid {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                              alignment: .center, spacing: 12) {
                        ForEach(habits) { h in HabitCard(habit: h, grid: true, daySheet: $daySheet) }
                    }
                    .accessibilityIdentifier("habit-list")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(habits) { h in HabitCard(habit: h, grid: false, daySheet: $daySheet) }
                    }
                    .accessibilityIdentifier("habit-list")
                }
                VStack(spacing: 8) {
                    ListButton(icon: "bulb", title: "Last week", id: "review-week") { nav.open(.lastWeek) }
                    ListButton(icon: "bulb", title: "Last month", id: "review-month") { nav.open(.lastMonth) }
                }
                .padding(.top, 16).padding(.bottom, 4)
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, nav.wide ? 40 : 104)
            .frame(maxWidth: .infinity)
        }
        .background(Ink.bg.ignoresSafeArea())
        .accessibilityIdentifier("screen-today")
        .overlay(alignment: .bottom) { if !nav.wide { BottomBar() } }
        .daySheets($daySheet)
        #if os(iOS)
        .toolbar(nav.wide ? .visible : .hidden, for: .navigationBar)
        #endif
        .navigationTitle(nav.wide ? "Today" : "")
        .toolbar {
            if nav.wide {
                ToolbarItem(placement: .primaryAction) {
                    Button { nav.sheet = .addHabit(prefill: nil) } label: { Label("Add habit", systemImage: "plus") }
                        .labelStyle(.titleAndIcon)
                        .accessibilityIdentifier("btn-add")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newHabit)) { _ in nav.sheet = .addHabit(prefill: nil) }
    }
}

private struct EmptyToday: View {
    var body: some View {
        VStack(spacing: 10) {
            TrackIcon(name: "sprout", size: 64, color: Ink.accent)
            Text("No habits yet").font(.title2.weight(.bold)).foregroundStyle(Ink.text)
            Text("Tap ＋ to add your first habit.\nDaily check-offs and start/stop timers\n(like intermittent fasting) are supported.")
                .font(.subheadline).foregroundStyle(Ink.dim).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90).padding(.bottom, 20)
        .accessibilityIdentifier("empty-today")
    }
}

/// The floating bar on the iPhone: Stats · Add · Settings, each with its word.
private struct BottomBar: View {
    @EnvironmentObject var nav: Nav
    var body: some View {
        HStack(spacing: 8) {
            item("chart", "Stats", "btn-stats") { nav.open(.stats) }
            item("plus", "Add", "btn-add") { nav.sheet = .addHabit(prefill: nil) }
            item("sliders", "Settings", "settings") { nav.sheet = .settings }
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(Capsule().fill(Ink.surface).shadow(color: .black.opacity(0.18), radius: 12, y: 6))
        .padding(.bottom, 14)
    }
    private func item(_ icon: String, _ word: String, _ id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                TrackIcon(name: icon, size: 21, color: Ink.text)
                Text(word).font(.system(size: 10, weight: .semibold)).foregroundStyle(Ink.dim)
            }
            .frame(width: 62, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityLabel(word)
    }
}

// MARK: - One habit's card

struct HabitCard: View {
    let habit: Habit
    let grid: Bool
    @Binding var daySheet: DaySheet?
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.colorScheme) private var scheme
    @State private var dx: CGFloat = 0
    @State private var swiping = false
    @State private var held = false
    @State private var taps = 0
    @State private var tapWork: Task<Void, Never>?
    @State private var dropTarget = false

    private var color: Color { Color(hex: habit.color) }
    private var today: String { DayKey.today() }
    private var zoned: Bool { habit.type == .timer && !grid }

    var body: some View {
        content
            .padding(.vertical, grid ? 12 : 11)
            .padding(.horizontal, grid ? 13 : 14)
            .padding(.bottom, zoned ? 12 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.tint(habit.color, 0.17, scheme)))
            .overlay(alignment: .bottom) { if zoned { zoneLabels } }
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(armColor ?? .clear, lineWidth: 2.5))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(dropTarget ? Ink.accent : .clear, lineWidth: 2))
            .shadow(color: Ink.shadow, radius: 5, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .offset(x: dx)
            .onTapGesture { if !swiping { nav.open(habit: habit.id) } }
            #if os(iOS)
            .simultaneousGesture(swipe)
            #else
            .contextMenu { macMenu }
            #endif
            .dropDestination(for: String.self) { ids, _ in
                guard let dragged = ids.first, dragged != habit.id else { return false }
                move(dragged, onto: habit.id)
                return true
            } isTargeted: { dropTarget = $0 }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("card-\(habit.id)")
    }

    @ViewBuilder private var content: some View {
        if grid {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    stat(alignment: .leading)
                    Spacer(minLength: 4)
                    actionButton
                }
                draggablePart {
                    VStack(alignment: .leading, spacing: 6) {
                        nameLine(iconSize: 22, font: .callout)
                        WeekDots(habit: habit, size: 16, gap: 4) { k in nav.open(habit: habit.id, day: k) }
                    }
                }
            }
        } else {
            HStack(spacing: 12) {
                actionButton
                draggablePart {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            nameLine(iconSize: 32, font: .body)
                            WeekDots(habit: habit, size: zoned ? 14 : 16, gap: zoned ? 3 : 5) { k in nav.open(habit: habit.id, day: k) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        stat(alignment: .trailing)
                    }
                }
            }
        }
    }

    /// Press and hold the card (not the circle) to lift it and drag it to a new place.
    private func draggablePart<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().contentShape(Rectangle())
            .draggable(habit.id) {
                Text(habit.displayName).font(.headline).padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.tint(habit.color, 0.3, scheme)))
            }
    }

    private func move(_ dragged: String, onto target: String) {
        var ids = store.data.activeHabits.map(\.id)
        let before = ids
        guard let from = ids.firstIndex(of: dragged), let to = ids.firstIndex(of: target) else { return }
        ids.remove(at: from)
        ids.insert(dragged, at: to)
        store.reorder(ids)
        store.showToast("Habits reordered") { [weak store] in store?.reorder(before) }
    }

    // MARK: Name line

    @ViewBuilder private func nameLine(iconSize: CGFloat, font: Font) -> some View {
        HStack(spacing: 6) {
            TrackIcon(name: habit.icon, size: iconSize, color: color)
            if let parts = habit.parts {
                partWords(parts, font: font)
            } else {
                Text(habit.name)
                    .font(nameFont(font))
                    .fontWeight(.bold)
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .accessibilityIdentifier("card-name")
            }
            if let note = habit.notes[today] {
                Circle().fill(color).frame(width: 8, height: 8)
                    .background(Circle().fill(color.opacity(0.25)).frame(width: 13, height: 13))
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle().inset(by: -8))
                    .onTapGesture {
                        store.showToast(note, action: "Edit", seconds: 7) { daySheet = .note(habit: habit.id, day: today) }
                    }
                    .accessibilityIdentifier("note-dot")
            }
        }
    }

    /// 17 pt, 15 pt past 15 letters, 13 pt past 24 (the web app's steps).
    private func nameFont(_ base: Font) -> Font {
        let n = habit.name.count
        if grid { return n > 15 ? .footnote : base }
        return n > 24 ? .footnote : n > 15 ? .subheadline : base
    }

    private func partWords(_ parts: [String], font: Font) -> some View {
        let done = habit.doneParts(today)
        let pendingIdx = taps > 0 ? min(taps, parts.count) - 1 : nil
        return HStack(spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                if i > 0 { Text("|").foregroundStyle(Ink.dim.opacity(0.5)).padding(.horizontal, 4) }
                Text(p)
                    .font(nameFont(font))
                    .fontWeight(done.contains(i) ? .heavy : .bold)
                    .foregroundStyle(done.contains(i) ? color : Ink.dim)
                    .lineLimit(1)
                    .padding(.horizontal, pendingIdx == i ? 3 : 0)
                    .background(RoundedRectangle(cornerRadius: 6).fill(pendingIdx == i ? color.opacity(0.18) : .clear))
                    .scaleEffect(pendingIdx == i ? 1.08 : 1)
                    .animation(.easeOut(duration: 0.2), value: taps)
                    .onTapGesture { cancelTaps(); store.togglePart(habit.id, i) }
                    .accessibilityIdentifier("part-\(i)")
            }
        }
        .minimumScaleFactor(0.7)
    }

    // MARK: The round button

    private var actionButton: some View {
        let isTimer = habit.type == .timer
        let running = habit.activeSession != nil
        let doneToday = habit.isDone(today)
        return ZStack {
            if isTimer, let p = habit.ringProgress() {
                Circle().stroke(Ink.border, lineWidth: 5)
                Circle().trim(from: 0, to: max(0.01, p))
                    .stroke(Color(hex: RingPhase.hex(p)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Button { circleTapped() } label: {
                ZStack {
                    if isTimer {
                        if running {
                            Circle().fill(color)
                            TrackIcon(name: "stop", size: 23, color: .white, lineWidth: 2)
                        } else {
                            Circle().strokeBorder(color, lineWidth: 3)
                            TrackIcon(name: "play", size: 23, color: color, lineWidth: 2)
                        }
                    } else if doneToday {
                        Circle().fill(color).shadow(color: .black.opacity(0.12), radius: 4, y: 3)
                        TrackIcon(name: "check", size: 23, color: .white, lineWidth: 2.2)
                    } else {
                        Circle().strokeBorder(color, lineWidth: 3)
                    }
                }
                .frame(width: 48, height: 48)
                .contentShape(Circle())
            }
            .buttonStyle(PressScale())
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in circleHeld() })
            .accessibilityIdentifier("check-\(habit.id)")
            .accessibilityLabel(isTimer ? (running ? "Stop fast" : "Start fast") : (doneToday ? "Done today" : "Not done today"))
        }
        .frame(width: 56, height: 56)
    }

    private func circleTapped() {
        if held { held = false; return }
        if habit.type == .timer { store.toggleFast(habit.id); return }
        if habit.parts != nil {
            taps += 1
            tapWork?.cancel()
            tapWork = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 320_000_000)
                guard !Task.isCancelled, let parts = habit.parts else { return }
                let idx = min(taps, parts.count) - 1
                taps = 0
                store.togglePart(habit.id, idx)
            }
            return
        }
        store.toggleToday(habit.id)
    }

    private func cancelTaps() { tapWork?.cancel(); taps = 0 }

    /// Press and hold: yesterday done; for a habit in parts, the parts sheet for yesterday. Fasting: nothing.
    private func circleHeld() {
        guard habit.type != .timer else { return }
        held = true
        if habit.parts != nil { daySheet = .parts(habit: habit.id, day: DayKey.add(today, days: -1)) }
        else { store.markYesterday(habit.id) }
    }

    // MARK: The number on the right

    @ViewBuilder private func stat(alignment: HorizontalAlignment) -> some View {
        let textAlign: TextAlignment = alignment == .trailing ? .trailing : .leading
        VStack(alignment: alignment, spacing: 2) {
            switch habit.type {
            case .daily:
                let n = habit.currentStreak()
                HStack(spacing: 3) { number("\(n)", color); Flame(color: color) }
                label(n == 1 ? "day" : "days")
            case .weekly:
                let count = habit.weekDoneCount(DayKey.weekStartKey(today))
                let met = count >= habit.weeklyTarget
                number("\(count)/\(habit.weeklyTarget)", met ? Ink.green : color)
                label("this week")
                let w = habit.weeklyStreak()
                HStack(spacing: 2) {
                    Text("\(w)")
                    Flame(size: 12, color: Ink.dim)
                    Text(w == 1 ? "week" : "weeks")
                }
                .font(.system(size: 10.5, weight: .bold)).foregroundStyle(Ink.dim).opacity(0.85)
            case .timer:
                timerStat(textAlign)
            }
        }
        .multilineTextAlignment(textAlign)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stat-\(habit.id)")
    }

    @ViewBuilder private func timerStat(_ align: TextAlignment) -> some View {
        let state = habit.timerState()
        Group {
            switch state {
            case .overlong(let e):
                number(Fmt.duration(e), Ink.amber); label("still fasting?\ntap timer to fix", Ink.amber)
            case .goalReached(let e):
                number(Fmt.duration(e), Ink.green); label("goal reached", Ink.green)
            case .running(let e, let left, let clock):
                number(Fmt.duration(e), color)
                label("\(Fmt.duration(left)) left")
                label("goal \(clock)", color)
            case .fasting(let e):
                number(Fmt.duration(e), color); label("fasting")
            case .eating(let since, let until):
                number(Fmt.duration(since), color)
                label("eating")
                if let until { label("until \(until)", color) } else { label("time to fast", color) }
            case .lastFast(let len):
                number(Fmt.duration(len), color); label("last fast")
            case .none:
                TrackIcon(name: "play", size: 24, color: color)
                label("tap to start")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editTapped() }
    }

    /// The number of the fasting card: fix the running fast's start, or the last fast.
    private func editTapped() {
        if let a = habit.activeSession { daySheet = .editFast(habit: habit.id, start: a.s) }
        else if let last = habit.lastFinished { daySheet = .editFast(habit: habit.id, start: last.s) }
        else { nav.open(habit: habit.id) }
    }

    private func number(_ s: String, _ c: Color) -> some View {
        Text(s).font(.title2.weight(.heavy)).monospacedDigit().tracking(-0.5).foregroundStyle(c)
            .lineLimit(1).minimumScaleFactor(0.7)
    }
    private func label(_ s: String, _ c: Color = Ink.dim) -> some View {
        Text(s.uppercased()).font(.system(size: 10.5, weight: .bold)).tracking(0.8).foregroundStyle(c)
            .lineLimit(2).minimumScaleFactor(0.8)
    }

    /// The fasting card's three tap areas, named under them: start/stop · stats · edit.
    private var zoneLabels: some View {
        let running = habit.activeSession != nil
        let hasEdit = running || habit.lastFinished != nil
        return HStack(spacing: 12) {
            Text(running ? "STOP" : "START").frame(width: 56)
            Text("STATS").frame(maxWidth: .infinity, alignment: .leading)
            if hasEdit { Text("EDIT") }
        }
        .font(.system(size: 8.5, weight: .bold)).tracking(0.9)
        .foregroundStyle(Ink.dim.opacity(0.8))
        .padding(.horizontal, 14).padding(.bottom, 5)
        .allowsHitTesting(false)
        .accessibilityIdentifier("zone-labels")
    }

    // MARK: Swipe (iPhone and iPad): right = done today, left = skip today

    private var armColor: Color? {
        guard abs(dx) > 72 else { return nil }
        return dx > 0 ? Ink.green : Ink.dim
    }

    #if os(iOS)
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { g in
                let x = g.translation.width, y = g.translation.height
                if !swiping {
                    guard abs(x) > 14, abs(x) > 1.6 * abs(y) else { return }
                    swiping = true
                    cancelTaps()
                }
                dx = max(-120, min(120, x))
            }
            .onEnded { _ in
                guard swiping else { return }
                let fire = dx
                withAnimation(.easeOut(duration: 0.18)) { dx = 0 }
                if fire > 72 {
                    if !store.swipeDone(habit.id) { daySheet = .hours(habit: habit.id, day: today) }
                } else if fire < -72 {
                    store.swipeSkip(habit.id)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { swiping = false }
            }
    }
    #endif

    #if os(macOS)
    @ViewBuilder private var macMenu: some View {
        Button("Open \(habit.displayName)") { nav.open(habit: habit.id) }
        if habit.type == .timer {
            Button(habit.activeSession != nil ? "Stop the fast" : "Start a fast") { store.toggleFast(habit.id) }
            Button("Record a fast for today…") { daySheet = .hours(habit: habit.id, day: today) }
        } else {
            Button("Done today") { _ = store.swipeDone(habit.id) }
            Button("Yesterday done") { circleHeld(); held = false }
        }
        Button("Skip today") { store.swipeSkip(habit.id) }
        Divider()
        Button("Edit habit…") { nav.sheet = .editHabit(habit.id) }
    }
    #endif
}

/// The round button shrinks a little while pressed.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.9 : 1).animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
