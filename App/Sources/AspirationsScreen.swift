import SwiftUI

// Aspirations (web `renderAspirations` 3665): what the habits are for. Each one says how many of its habits ran
// last week; one that has gone quiet is asked about. Rules 1.3 and 7.5.

enum AspirationSheetKind: Identifiable, Hashable {
    case new
    case edit(String)
    var id: String { switch self { case .new: "new"; case .edit(let i): "edit-\(i)" } }
}

struct AspirationsScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @State private var sheet: AspirationSheetKind?

    var body: some View {
        let ins = Insights(data: store.data)
        let ws = ins.ws
        let cover = ins.coverage(ws)
        let loose = ins.unattachedHabits
        Page(id: "screen-aspirations") {
            PageTitle(title: "Aspirations", subtitle: "What the habits are for")
            if cover.isEmpty {
                EmptyNote(text: "Nothing here yet. An aspiration is one sentence about who you are becoming — the thing your habits are actually for. Once you have one, every week says how many of its habits ran, and one that goes quiet gets asked about rather than left sitting there.",
                          id: "asp-empty")
            }
            ForEach(cover) { c in
                Button { sheet = .edit(c.asp.id) } label: {
                    NoteCard {
                        HStack(spacing: 8) {
                            Text(c.asp.title).font(.subheadline.weight(.heavy)).foregroundStyle(Ink.text)
                            Text(c.total > 0 ? "\(c.ran)/\(c.total)" : "—").font(.subheadline.weight(.heavy)).foregroundStyle(Ink.dim)
                            Spacer(minLength: 0)
                        }
                        Text(c.total > 0 ? "\(c.ran) of \(c.total) habit\(c.total == 1 ? "" : "s") ran last week" : "No habits under this yet")
                            .font(.footnote).foregroundStyle(Ink.dim)
                        if !c.habits.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(c.habits) { h in HabitChip(habit: h, ran: ins.habitActive(h, in: ws)) }
                            }
                        }
                        if c.quiet >= 3 {
                            Text("Nothing has run under this for \(c.quiet) weeks. Is it still true?")
                                .font(.footnote.weight(.bold)).foregroundStyle(Ink.stale)
                                .accessibilityIdentifier("asp-quiet-\(c.asp.id)")
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("asp-card-\(c.asp.id)")
            }
            if !cover.isEmpty && !loose.isEmpty {
                NoteCard {
                    HStack(spacing: 8) {
                        Text("Not attached to anything").font(.subheadline.weight(.heavy)).foregroundStyle(Ink.dim)
                        Text("\(loose.count)").font(.subheadline.weight(.heavy)).foregroundStyle(Ink.dim)
                        Spacer(minLength: 0)
                    }
                    Text("Perfectly fine — a habit does not need an aspiration. Edit a habit and use *Serves* if you want to attach one.")
                        .font(.footnote).foregroundStyle(Ink.dim)
                    FlowLayout(spacing: 6) { ForEach(loose) { h in HabitChip(habit: h, ran: false, plain: true) } }
                }
                .accessibilityIdentifier("asp-loose")
            }
            ListButton(icon: "plus", title: "Add an aspiration", id: "btn-asp-add") { sheet = .new }
        }
        .reviewChrome("Aspirations")
        .sheet(item: $sheet) { kind in
            AspirationSheet(kind: kind)
                .environmentObject(store)
                .environmentObject(nav)
        }
    }
}

/// A habit as a small pill: solid when it ran last week, hollow when it did not, plain when that is not the question.
private struct HabitChip: View {
    let habit: Habit
    let ran: Bool
    var plain = false
    var body: some View {
        HStack(spacing: 5) {
            TrackIcon(name: habit.icon, size: 14, color: Color(hex: habit.color))
            Text(habit.name).font(.footnote.weight(.semibold)).foregroundStyle(ran ? Ink.text : Ink.dim).lineLimit(1)
        }
        .padding(.vertical, 4).padding(.horizontal, 10)
        .background(Capsule().fill(ran ? Ink.border : .clear))
        .overlay(Capsule().strokeBorder(Ink.border, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plain ? habit.name : "\(habit.name), \(ran ? "ran last week" : "did not run last week")")
    }
}

// MARK: - The sheet: write one, attach habits, archive

struct AspirationSheet: View {
    let kind: AspirationSheetKind
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var habitIDs: [String] = []
    @State private var loaded = false
    @FocusState private var focused: Bool

    private var editingID: String? { if case .edit(let id) = kind { id } else { nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("One sentence about who you are becoming. No date, no number — the habits carry those.")
                        .font(.subheadline).foregroundStyle(Ink.dim)
                    label("Aspiration")
                    TextField("e.g. Strong and durable into my seventies", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focused)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Ink.surface))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(focused ? Ink.accent : Ink.border, lineWidth: focused ? 1.5 : 1))
                        .onChange(of: title) { _, t in if t.count > 80 { title = String(t.prefix(80)) } }
                        .accessibilityIdentifier("asp-title")

                    if editingID == nil {
                        label("Or start from one of these")
                        FlowLayout(spacing: 6) {
                            ForEach(Array(aspirationStarters.enumerated()), id: \.offset) { i, t in
                                Button { title = t; focused = true } label: {
                                    Text(t).font(.footnote.weight(.semibold)).foregroundStyle(Ink.text)
                                        .padding(.vertical, 6).padding(.horizontal, 11)
                                        .overlay(Capsule().strokeBorder(Ink.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("asp-starter-\(i)")
                            }
                        }
                    }

                    label("Which habits serve it?")
                    let habits = store.data.activeHabits
                    if habits.isEmpty {
                        Text("No habits yet — add one first and it can be attached here.").font(.footnote).foregroundStyle(Ink.dim)
                    } else {
                        FlowLayout(spacing: 6) { ForEach(habits) { h in chip(h) } }
                    }

                    if editingID != nil {
                        Button { archive() } label: {
                            HStack(spacing: 6) {
                                TrackIcon(name: "import", size: 16, color: Ink.dim)
                                Text("Archive this aspiration").font(.subheadline.weight(.bold)).foregroundStyle(Ink.dim)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("asp-archive")
                    }
                }
                .padding(16)
            }
            .background(Ink.bg.ignoresSafeArea())
            .navigationTitle(editingID == nil ? "New aspiration" : "Edit aspiration")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).accessibilityIdentifier("asp-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.bold).accessibilityIdentifier("asp-save")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 520)
        #endif
        .accessibilityIdentifier("sheet-aspiration")
        .onAppear { load() }
    }

    private func label(_ t: String) -> some View {
        Text(t.uppercased()).font(.footnote.weight(.heavy)).tracking(0.7).foregroundStyle(Ink.dim).padding(.top, 4)
    }

    /// A habit already under another aspiration can still be moved, but says so first.
    private func chip(_ h: Habit) -> some View {
        let on = habitIDs.contains(h.id)
        let other: String? = {
            guard let aid = h.aspirationId, aid != editingID,
                  let a = store.data.aspirations.first(where: { $0.id == aid && $0.deletedAt == nil && $0.archivedAt == nil }) else { return nil }
            return a.title
        }()
        return Button {
            if let i = habitIDs.firstIndex(of: h.id) { habitIDs.remove(at: i) } else { habitIDs.append(h.id) }
        } label: {
            HStack(spacing: 5) {
                TrackIcon(name: h.icon, size: 14, color: Color(hex: h.color))
                Text(h.name).font(.footnote.weight(.semibold)).foregroundStyle(Ink.text).lineLimit(1)
                if let other, !on { Text("· \(other)").font(.footnote).foregroundStyle(Ink.dim).lineLimit(1) }
            }
            .padding(.vertical, 6).padding(.horizontal, 11)
            .background(Capsule().fill(on ? Ink.accent.opacity(0.14) : .clear))
            .overlay(Capsule().strokeBorder(on ? Ink.accent : Ink.border, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("asp-habit-\(h.id)")
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let id = editingID, let a = store.data.aspirations.first(where: { $0.id == id }) {
            title = a.title
            habitIDs = store.data.activeHabits.filter { $0.aspirationId == id }.map(\.id)
        } else { focused = true }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { focused = true; return }
        let id: String
        if let e = editingID { id = e; if store.data.aspirations.first(where: { $0.id == e })?.title != t { store.updateAspiration(e) { $0.title = t } } }
        else { id = newID(); store.add(Aspiration(id: id, title: t)) }
        // The membership the sheet showed: ticked habits get this id, unticked ones that had it lose it.
        for h in store.data.activeHabits {
            let want = habitIDs.contains(h.id)
            if want && h.aspirationId != id { store.update(h.id) { $0.aspirationId = id } }
            else if !want && h.aspirationId == id { store.update(h.id) { $0.aspirationId = nil } }
        }
        dismiss()
    }

    /// The habits under it are left alone (they simply serve nothing); Undo brings it back with them still attached.
    private func archive() {
        guard let id = editingID else { return }
        store.updateAspiration(id) { $0.archivedAt = DayKey.today() }
        dismiss()
        store.showToast("Aspiration archived") { store.updateAspiration(id) { $0.archivedAt = nil } }
    }
}
