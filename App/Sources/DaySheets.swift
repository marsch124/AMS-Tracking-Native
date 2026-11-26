import SwiftUI

// The small sheets about one day or one fast. Opened from Today and from a habit's page.
// (Lane A fills these in: record-hours, edit-fast, parts, day note, skip several days.)

enum DaySheet: Identifiable, Hashable {
    case note(habit: String, day: String)
    case hours(habit: String, day: String)
    case editFast(habit: String, start: Double)
    case parts(habit: String, day: String)
    case skipRange(habit: String)
    var id: String {
        switch self {
        case .note(let h, let d): "note-\(h)-\(d)"
        case .hours(let h, let d): "hours-\(h)-\(d)"
        case .editFast(let h, let s): "fast-\(h)-\(s)"
        case .parts(let h, let d): "parts-\(h)-\(d)"
        case .skipRange(let h): "skip-\(h)"
        }
    }
}

extension View {
    func daySheets(_ sheet: Binding<DaySheet?>) -> some View {
        modifier(DaySheetsModifier(sheet: sheet))
    }
}

private struct DaySheetsModifier: ViewModifier {
    @Binding var sheet: DaySheet?
    @EnvironmentObject var store: Store
    func body(content: Content) -> some View {
        content.sheet(item: $sheet) { s in
            Group {
                switch s {
                case .note(let h, let d): DayNoteSheet(habitID: h, day: d)
                case .hours(let h, let d): RecordHoursSheet(habitID: h, day: d)
                case .editFast(let h, let start): EditFastSheet(habitID: h, start: start)
                case .parts(let h, let d): PartsSheet(habitID: h, day: d)
                case .skipRange(let h): SkipRangeSheet(habitID: h)
                }
            }
            .environmentObject(store)
        }
    }
}

// MARK: - Shared frame: title, content, Cancel + Save (Escape = Cancel on the Mac)

private struct SheetShell<Content: View>: View {
    let title: String
    var idPrefix: String
    var saveLabel = "Save"
    var canSave = true
    var error: String? = nil
    var onSave: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.weight(.heavy)).foregroundStyle(Ink.text)
                .accessibilityIdentifier("sheet-\(idPrefix)-title")
            ScrollView { VStack(alignment: .leading, spacing: 12) { content }.frame(maxWidth: .infinity, alignment: .leading) }
            if let error {
                Text(error).font(.footnote.weight(.semibold)).foregroundStyle(Ink.danger)
                    .accessibilityIdentifier("sheet-error")
            }
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Cancel").font(.body.weight(.semibold)).foregroundStyle(Ink.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.border, lineWidth: 1))
                }
                .buttonStyle(.plain).keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("btn-\(idPrefix)-cancel")
                Button(action: onSave) {
                    Text(saveLabel).font(.body.weight(.bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.accent))
                }
                .buttonStyle(.plain).keyboardShortcut(.defaultAction).disabled(!canSave)
                .accessibilityIdentifier("btn-\(idPrefix)-save")
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
        .background(Ink.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}

private struct FieldLabel: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.bold)).foregroundStyle(Ink.dim)
    }
}

/// "Mon, 5 Oct" for a day key.
private func dayTitle(_ key: String) -> String { DayKey.date(key).map { Fmt.weekdayDayMonth($0) } ?? key }

private struct LinkLikeButton: View {
    let title: String
    var color: Color = Ink.accent
    var id: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

// MARK: - Note for a day (8.5)

struct DayNoteSheet: View {
    let habitID: String
    let day: String
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var existing = false
    @FocusState private var focus: Bool

    var body: some View {
        SheetShell(title: "Note for \(dayTitle(day))", idPrefix: "note", onSave: save) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text).font(.body).scrollContentBackground(.hidden)
                    .focused($focus)
                    .frame(minHeight: 84, maxHeight: 120)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.border, lineWidth: 1))
                    .accessibilityIdentifier("note-input")
                if text.isEmpty {
                    Text("e.g. skipped, travel day").foregroundStyle(Ink.dim).padding(.horizontal, 11).padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            if existing {
                LinkLikeButton(title: "Delete this note", color: Ink.danger, id: "btn-note-delete") {
                    store.update(habitID) { $0.notes[day] = nil }
                    dismiss()
                }
            }
        }
        .onChange(of: text) { _, t in if t.count > 200 { text = String(t.prefix(200)) } }
        .onAppear {
            let n = store.data.habit(habitID)?.notes[day] ?? ""
            text = n; existing = !n.isEmpty
            if n.isEmpty { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = true } }
        }
    }

    private func save() {
        let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        store.update(habitID) { h in if t.isEmpty { h.notes[day] = nil } else { h.notes[day] = t } }
        dismiss()
    }
}

// MARK: - Record a forgotten fast (8.1)

struct RecordHoursSheet: View {
    let habitID: String
    let day: String
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?

    private var habit: Habit? { store.data.habit(habitID) }

    var body: some View {
        let goal = habit.flatMap { h in DayKey.date(day).flatMap { h.goalHours(on: $0) } }
        SheetShell(title: "Fast on \(dayTitle(day))", idPrefix: "hours", error: error, onSave: { save(FastHours.parse(text)) }) {
            FieldLabel("How many hours?")
            HStack(spacing: 8) {
                ForEach(FastHours.presets(goal: goal), id: \.self) { h in
                    Button { save(h) } label: {
                        Text("\(Fmt.hours(h))h").font(.subheadline.weight(.bold)).foregroundStyle(Ink.accent)
                            .frame(minWidth: 52, minHeight: 40).padding(.horizontal, 6)
                            .background(Capsule().fill(Ink.surface))
                            .overlay(Capsule().stroke(Ink.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("goal-chip-\(Fmt.hours(h))")
                }
            }
            .accessibilityIdentifier("hours-chips")
            TextField("Or type the hours…", text: $text)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .accessibilityIdentifier("hours-input")
            LinkLikeButton(title: "Mark as skip day instead", id: "btn-hours-skip") {
                store.update(habitID) { $0.skip.insert(day) }
                dismiss()
            }
        }
    }

    private func save(_ hours: Double?) {
        guard let hours, let s = FastHours.session(hours: hours, day: day) else { error = FastHours.message; return }
        store.update(habitID) { $0.sessions.append(s) }
        dismiss()
    }
}

// MARK: - Edit a fast (8.2)

struct EditFastSheet: View {
    let habitID: String
    let start: Double
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var from = Date()
    @State private var to = Date()
    @State private var running = false
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        let dur = (running ? DayKey.now : to).timeIntervalSince(from) * 1000
        SheetShell(title: running ? "Fast in progress" : "Edit fast", idPrefix: "fast", error: error, onSave: save) {
            FieldLabel("Started")
            DatePicker("Started", selection: $from, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden().accessibilityIdentifier("fast-start")
            if !running {
                FieldLabel("Ended")
                DatePicker("Ended", selection: $to, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden().accessibilityIdentifier("fast-end")
            }
            Text("Duration: \(Fmt.duration(dur)) h").font(.subheadline).foregroundStyle(Ink.dim)
                .accessibilityIdentifier("fast-duration")
            LinkLikeButton(title: "Delete this fast", color: Ink.danger, id: "btn-fast-delete", action: delete)
        }
        .onAppear {
            guard !loaded, let s = store.data.habit(habitID)?.sessions.first(where: { $0.s == start }) else { return }
            loaded = true
            from = s.start; running = s.isRunning; to = s.end ?? DayKey.now
        }
    }

    private func save() {
        if let problem = FastEdit.validate(start: from, end: running ? nil : to, running: running) { error = problem; return }
        let newS = (from.timeIntervalSince1970 * 1000).rounded(), newE = (to.timeIntervalSince1970 * 1000).rounded()
        store.update(habitID) { h in
            guard let i = h.sessions.firstIndex(where: { $0.s == start }) else { return }
            h.sessions[i].s = newS
            if !running { h.sessions[i].e = newE }
        }
        dismiss()
    }

    private func delete() {
        guard let h = store.data.habit(habitID) else { dismiss(); return }
        let snapshot = h
        store.update(habitID) { h in h.sessions.removeAll { $0.s == start } }
        store.showToast(running ? "Running fast deleted" : "Fast deleted") { [weak store] in store?.restore(snapshot) }
        dismiss()
    }
}

// MARK: - Parts of a day (8.4)

struct PartsSheet: View {
    let habitID: String
    let day: String
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<Int> = []
    @State private var loaded = false

    private var habit: Habit? { store.data.habit(habitID) }

    private var title: String {
        let t = DayKey.today()
        if day == t { return "Today · \(dayTitle(day))" }
        if day == DayKey.add(t, days: -1) { return "Yesterday · \(dayTitle(day))" }
        return dayTitle(day)
    }

    var body: some View {
        let parts = habit?.parts ?? []
        SheetShell(title: title, idPrefix: "parts", onSave: save) {
            FieldLabel("Tap the parts you did")
            VStack(spacing: 8) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, name in
                    let on = chosen.contains(i)
                    Button { if on { chosen.remove(i) } else { chosen.insert(i) } } label: {
                        HStack(spacing: 8) {
                            if on { TrackIcon(name: "check", size: 16, color: Ink.accent) }
                            Text(name).font(.body.weight(.semibold)).foregroundStyle(Ink.text)
                            Spacer()
                        }
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Ink.accent : Ink.border, lineWidth: on ? 2 : 1))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("parts-chip-\(i)")
                }
            }
            .accessibilityIdentifier("parts-chips")
            LinkLikeButton(title: "Mark as skip day instead", id: "btn-parts-skip") { apply(skip: true) }
        }
        .onAppear {
            guard !loaded, let h = habit else { return }
            loaded = true; chosen = Set(h.doneParts(day))
        }
    }

    private func save() { apply(skip: false) }

    /// Writes the day and shows the toast; Undo puts back exactly this day's done and skip.
    private func apply(skip: Bool) {
        guard let h = habit, let parts = h.parts else { dismiss(); return }
        let before = h.done[day], hadSkip = h.skip.contains(day)
        let picked = chosen.sorted()
        let message: String
        store.update(habitID) { h in
            if skip { h.done[day] = nil; h.skip.insert(day) }
            else if picked.isEmpty { h.done[day] = nil; h.skip.remove(day) }
            else { h.done[day] = .parts(picked); h.skip.remove(day) }
        }
        if skip { message = "Marked as a skip day" }
        else if picked.isEmpty { message = "Day cleared" }
        else { message = picked.map { $0 < parts.count ? parts[$0] : "Part" }.joined(separator: ", ") + " saved" }
        let id = habitID, d = day
        store.showToast(message) { [weak store] in
            store?.update(id) { h in
                h.done[d] = before
                if hadSkip { h.skip.insert(d) } else { h.skip.remove(d) }
            }
        }
        dismiss()
    }
}

// MARK: - Skip several days (8.3)

struct SkipRangeSheet: View {
    let habitID: String
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var from = DayKey.startOfDay(DayKey.now)
    @State private var to = DayKey.startOfDay(DayKey.now)
    @State private var all = false
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        SheetShell(title: "Skip several days", idPrefix: "skiprange", saveLabel: "Mark skip days", error: error, onSave: save) {
            Text("On holiday or out sick? Every day in the range becomes an excused skip day — streaks survive, and days already done stay done.")
                .font(.footnote).foregroundStyle(Ink.dim)
            FieldLabel("First day")
            DatePicker("First day", selection: $from, displayedComponents: .date).labelsHidden()
                .accessibilityIdentifier("skip-from")
            FieldLabel("Last day")
            DatePicker("Last day", selection: $to, displayedComponents: .date).labelsHidden()
                .accessibilityIdentifier("skip-to")
            Toggle("Apply to all habits", isOn: $all).accessibilityIdentifier("skip-all")
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            all = store.data.activeHabits.count > 1
        }
    }

    private func save() {
        let a = DayKey.key(from), b = DayKey.key(to)
        if let problem = SkipRange.validate(from: a, to: b) { error = problem; return }
        let targets = all ? store.data.activeHabits.map(\.id) : [habitID]
        var added: [(String, [String])] = []
        for id in targets {
            guard let h = store.data.habit(id) else { continue }
            let keys = SkipRange.newSkips(h, from: a, to: b)
            if !keys.isEmpty { store.update(id) { $0.skip.formUnion(keys) }; added.append((id, keys)) }
        }
        let n = SkipRange.days(from: a, to: b)
        let text = SkipRange.message(days: n, habits: targets.count)
        if added.isEmpty { store.showToast(text) } else {
            store.showToast(text) { [weak store] in
                for (id, keys) in added { store?.update(id) { $0.skip.subtract(keys) } }
            }
        }
        dismiss()
    }
}
