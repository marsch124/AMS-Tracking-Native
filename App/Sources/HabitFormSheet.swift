import SwiftUI

/// New habit / Edit habit (screens doc 7): a live preview, then name, icon, colour, type, goals, aspiration, days.
struct HabitFormSheet: View {
    let editing: String?
    let prefill: HabitPrefill?

    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @FocusState private var nameFocused: Bool

    @State private var loaded = false
    @State private var name = ""
    @State private var icon = "meditate"
    @State private var color = Palette.all[0]
    @State private var type: HabitType = .daily
    @State private var originalType: HabitType = .daily
    @State private var target = 3
    @State private var days = Array(repeating: true, count: 7)
    @State private var goal = ""
    @State private var goalByDay = Array(repeating: "", count: 7)
    @State private var aspirationId: String?
    @State private var search = ""

    private var isEditing: Bool { editing != nil }
    private var typeLocked: Bool { isEditing && originalType == .timer }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "Edit habit" : "New habit").font(.title2.weight(.heavy)).padding(.bottom, 6)
                        .accessibilityIdentifier("form-title")
                    preview
                    label("Name")
                    TextField("e.g. Meditate", text: $name)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 10).padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.border, lineWidth: 1))
                        .focused($nameFocused)
                        .onChange(of: name) { _, v in if v.count > 40 { name = String(v.prefix(40)) } }
                        .accessibilityIdentifier("f-name")
                    Text("A | in the name makes parts, like Morning | Evening.").font(.footnote).foregroundStyle(Ink.dim)
                    label("Icon")
                    IconPicker(selection: $icon, search: $search)
                    label("Colour")
                    colours
                    label("Type")
                    typeButtons
                    if type == .weekly { label("Times per week"); targetChips }
                    if type == .timer { goalFields }
                    if !store.data.liveAspirations.isEmpty { label("Serves"); serves }
                    if type == .daily { label("On which days?"); dayChips }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
                .frame(maxWidth: .infinity)
            }
            .background(Ink.bg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { buttons }
            .accessibilityIdentifier("sheet-habit-form")
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 520, minHeight: 640, idealHeight: 760)
        #endif
        .onAppear(perform: load)
    }

    // MARK: Loading

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let id = editing, let h = store.data.habit(id) {
            name = h.name; icon = h.icon; color = h.color; type = h.type; originalType = h.type
            days = h.days.count == 7 ? h.days : Array(repeating: true, count: 7)
            target = min(7, max(1, h.target ?? 1))
            goal = h.goalHours.map(Fmt.hours) ?? ""
            goalByDay = (0..<7).map { i in (h.goalByDay.flatMap { i < $0.count ? $0[i] : nil }).map(Fmt.hours) ?? "" }
            aspirationId = h.aspirationId
        } else {
            color = Palette.all[store.data.liveHabits.count % 8]
            if let p = prefill {
                name = String(p.name.prefix(40))
                if TrackIcons.habitNames.contains(p.icon) { icon = p.icon }
                type = p.type == .timer ? .daily : p.type
                if let t = p.target { target = min(7, max(1, t)) }
            }
            nameFocused = prefill == nil
        }
    }

    // MARK: Pieces

    private func label(_ s: String) -> some View {
        Text(s.uppercased()).font(.footnote.weight(.bold)).tracking(0.4).foregroundStyle(Ink.dim)
            .padding(.top, 14).padding(.bottom, 4)
    }

    private var previewHabit: Habit {
        let today = DayKey.today()
        var h = Habit(id: "preview", name: name, icon: icon, color: color, type: type, days: days,
                      target: type == .weekly ? target : nil, createdAt: today)
        let off = type == .daily && !days[DayKey.weekday(today)]
        if type != .timer && !off { h.done[today] = .all }
        return h
    }

    private var preview: some View {
        let h = previewHabit
        let c = Color(hex: color)
        let shown = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Your habit" : name
        return HStack(spacing: 12) {
            ZStack {
                Circle().strokeBorder(c, lineWidth: 3)
                if type == .timer { TrackIcon(name: "play", size: 18, color: c) }
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    TrackIcon(name: icon, size: 28, color: c)
                    Text(shown).font(shown.count > 26 ? .footnote.weight(.bold) : shown.count > 18 ? .subheadline.weight(.bold) : .body.weight(.bold))
                        .foregroundStyle(Ink.text).lineLimit(1)
                }
                WeekDots(habit: h, size: 16, gap: 5)
                HStack(spacing: 4) {
                    if type == .timer {
                        TrackIcon(name: "play", size: 13, color: Ink.dim)
                        Text("tap to start").font(.caption).foregroundStyle(Ink.dim)
                    } else {
                        Text("1").font(.subheadline.weight(.heavy)).foregroundStyle(Ink.text)
                        Flame(size: 14, color: c)
                        Text(type == .weekly ? "week" : "day").font(.caption).foregroundStyle(Ink.dim)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11).padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.tint(color, 0.10, scheme)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Ink.border, lineWidth: 1))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview: \(shown)")
        .accessibilityIdentifier("sheet-preview")
    }

    private var colours: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 48), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Array(Palette.all.enumerated()), id: \.offset) { i, hex in
                Button { color = hex } label: {
                    Circle().fill(Color(hex: hex)).frame(width: 26, height: 26)
                        .frame(width: 44, height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color == hex ? Ink.accent : Ink.border, lineWidth: color == hex ? 2 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Palette.names[i])
                .accessibilityIdentifier("color-\(i)")
            }
        }
    }

    private var typeButtons: some View {
        VStack(spacing: 8) {
            typeButton(.daily, "check", "Daily check", "Tick it off once a day")
            typeButton(.weekly, "target", "Weekly target", "Hit a number per week, on any days")
            typeButton(.timer, "timer", "Start / Stop", "One button toggles a timer, e.g. fasting")
            if isEditing, let n = switchNote {
                Text(n).font(.footnote).foregroundStyle(Ink.dim).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("type-note")
            }
        }
    }

    private var switchNote: String? {
        guard isEditing, type != originalType else { return nil }
        if type == .weekly { return "Every day you have ticked stays. The streak will count weeks that reached the target, instead of days in a row." }
        if type == .daily { return "Every day you have ticked stays. The streak will count days in a row again, on the days you choose below." }
        return nil
    }

    private func typeButton(_ t: HabitType, _ ic: String, _ title: String, _ sub: String) -> some View {
        let disabled = isEditing && (originalType == .timer || t == .timer)
        return Button { choose(t) } label: {
            HStack(spacing: 10) {
                TrackIcon(name: ic, size: 23, color: Ink.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Ink.text)
                    Text(sub).font(.footnote).foregroundStyle(Ink.dim)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 9).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Ink.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(type == t ? Ink.accent : .clear, lineWidth: 2))
            .opacity(disabled ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityIdentifier("type-\(t.rawValue)")
    }

    /// Daily ⇄ weekly keeps the history; a daily habit switched to weekly starts at its scheduled days.
    private func choose(_ t: HabitType) {
        guard t != type else { return }
        if t == .weekly, type == .daily, isEditing { target = max(1, days.filter { $0 }.count) }
        type = t
    }

    private var targetChips: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { n in
                Button { target = n } label: {
                    Text("\(n)").font(.footnote.weight(.bold)).foregroundStyle(target == n ? Ink.accent : Ink.dim)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(target == n ? Ink.accent : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("target-\(n)")
            }
        }
    }

    @ViewBuilder private var goalFields: some View {
        label("Fasting goal (hours)")
        TextField("e.g. 16", text: $goal)
            .textFieldStyle(.plain)
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.border, lineWidth: 1))
            .accessibilityIdentifier("f-goal")
        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 2) {
                    Text(DayKey.letters[i]).font(.caption2).foregroundStyle(Ink.dim)
                    TextField("", text: $goalByDay[i])
                        .textFieldStyle(.plain).multilineTextAlignment(.center).font(.footnote)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Ink.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Ink.border, lineWidth: 1))
                        .accessibilityLabel(DayKey.longNames[i] + " goal")
                        .accessibilityIdentifier("gbd-\(i)")
                }
            }
        }
        .padding(.top, 6)
        Text("Optional: a different goal for certain days — the day a fast ends on. Empty days use the goal above.")
            .font(.footnote).foregroundStyle(Ink.dim)
    }

    private var serves: some View {
        FlowLayout(spacing: 8) {
            pill("Nothing in particular", selected: aspirationId == nil, id: "asp-none") { aspirationId = nil }
            ForEach(store.data.liveAspirations) { a in
                pill(a.title, selected: aspirationId == a.id, id: "asp-\(a.id)") { aspirationId = a.id }
            }
        }
    }

    private func pill(_ t: String, selected: Bool, id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.footnote.weight(.semibold)).foregroundStyle(Ink.text).lineLimit(1)
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(Capsule().fill(Ink.surface))
                .overlay(Capsule().stroke(selected ? Ink.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var dayChips: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                Button {
                    if days[i] && days.filter({ $0 }).count == 1 { return }   // one day always stays on
                    days[i].toggle()
                } label: {
                    Text(DayKey.letters[i]).font(.footnote.weight(.bold)).foregroundStyle(days[i] ? Ink.accent : Ink.dim)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(days[i] ? Ink.accent : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(DayKey.longNames[i])
                .accessibilityIdentifier("day-\(i)")
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("Cancel").font(.body.weight(.semibold)).foregroundStyle(Ink.text)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Ink.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Ink.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("btn-sheet-cancel")
            Button(action: save) {
                Text("Save").font(.body.weight(.bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Ink.accent))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("btn-sheet-save")
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Ink.bg.opacity(0.96))
    }

    // MARK: Save

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { nameFocused = true; return }
        let timerGoal = GoalInput.parse(goal)
        let byDay = GoalInput.byDay(goalByDay)
        if let id = editing {
            store.update(id) { h in
                h.name = trimmed; h.icon = icon; h.color = color; h.days = days; h.aspirationId = aspirationId
                if h.type == .timer {
                    h.goalHours = timerGoal; h.goalByDay = byDay
                } else {
                    h.type = type
                    h.target = type == .weekly ? target : nil
                }
            }
        } else {
            store.add(Habit(name: trimmed, icon: icon, color: color, type: type, days: days,
                            target: type == .weekly ? target : nil,
                            goalHours: type == .timer ? timerGoal : nil,
                            goalByDay: type == .timer ? byDay : nil,
                            aspirationId: aspirationId))
        }
        dismiss()
    }
}
