import SwiftUI

/// A group of compact rows on a card (heading above, thin lines between rows).
struct SettingsGroup<Content: View>: View {
    var title: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let title {
                Text(title.uppercased()).font(.footnote.weight(.bold)).tracking(0.4).foregroundStyle(Ink.dim).padding(.leading, 4)
            }
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(Ink.surface).shadow(color: Ink.shadow, radius: 4, y: 1))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Ink.border, lineWidth: 1))
            if let footer {
                Text(footer).font(.footnote).foregroundStyle(Ink.dim).padding(.horizontal, 4)
            }
        }
    }
}

/// The inside of one row: icon, words, optional figure next to the words, optional chevron.
struct RowLabel: View {
    var icon: String? = nil
    let title: String
    var detail: String? = nil
    var detailColor: Color = Ink.dim
    var chevron = false
    var tint: Color = Ink.text
    var body: some View {
        HStack(spacing: 10) {
            if let icon { TrackIcon(name: icon, size: 18, color: Ink.accent) }
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            if let detail { Text(detail).font(.subheadline).foregroundStyle(detailColor).lineLimit(1) }
            Spacer(minLength: 0)
            if chevron { TrackIcon(name: "chevR", size: 14, color: Ink.dim) }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .frame(minHeight: 42)
        .contentShape(Rectangle())
    }
}

struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 14) }
}

/// A full-colour pill button (Restore, Import …).
struct PillButton: View {
    let title: String
    var id: String
    var role: ButtonRole? = nil
    let action: () -> Void
    var body: some View {
        Button(role: role, action: action) {
            Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                .padding(.vertical, 6).padding(.horizontal, 14)
                .background(Capsule().fill(role == .destructive ? Ink.danger : Ink.accent))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// The page shell for a pushed settings screen: title, background, Done where it makes sense.
extension View {
    func settingsPage(_ title: String) -> some View {
        self.navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }
}

// MARK: - Reorder habits (drag and drop)

struct ReorderScreen: View {
    @EnvironmentObject var store: Store
    @State private var order: [Habit] = []

    var body: some View {
        List {
            ForEach(order) { h in
                HStack(spacing: 10) {
                    TrackIcon(name: h.icon, size: 24, color: Color(hex: h.color))
                    Text(h.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .listRowBackground(Ink.surface)
                .accessibilityIdentifier("reorder-\(h.id)")
            }
            .onMove { from, to in
                let before = order.map(\.id)
                order.move(fromOffsets: from, toOffset: to)
                store.reorder(order.map(\.id))
                store.showToast("Habits reordered") { store.reorder(before); order = store.data.activeHabits }
            }
        }
        .listStyle(.plain)
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
        .scrollContentBackground(.hidden)
        .background(Ink.bg.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Drag a habit by its handle to move it.").font(.footnote).foregroundStyle(Ink.dim)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 6)
        }
        .settingsPage("Reorder habits")
        .onAppear { order = store.data.activeHabits }
        .accessibilityIdentifier("screen-reorder")
    }
}

// MARK: - Archived habits

struct ArchivedScreen: View {
    @EnvironmentObject var store: Store
    @State private var toDelete: Habit?

    var body: some View {
        let list = store.data.archivedHabits
        Page(id: "screen-archived") {
            Text("Archived habits keep all their history and can be restored any time.")
                .font(.footnote).foregroundStyle(Ink.dim).padding(.top, 8)
            if list.isEmpty {
                Text("Nothing here — archive a habit from its detail view.").font(.subheadline).foregroundStyle(Ink.dim)
                    .accessibilityIdentifier("archived-empty")
            } else {
                SettingsGroup {
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, h in
                        if i > 0 { RowDivider() }
                        HStack(spacing: 10) {
                            TrackIcon(name: h.icon, size: 24, color: Color(hex: h.color))
                            Text(h.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Spacer(minLength: 6)
                            PillButton(title: "Restore", id: "restore-\(h.id)") { store.update(h.id) { $0.archived = false } }
                            Button("Delete", role: .destructive) { toDelete = h }
                                .font(.subheadline.weight(.semibold)).buttonStyle(.plain).foregroundStyle(Ink.danger)
                                .accessibilityIdentifier("delete-\(h.id)")
                        }
                        .padding(.vertical, 8).padding(.horizontal, 14)
                    }
                }
            }
        }
        .settingsPage("Archived habits")
        .confirmationDialog("Delete “\(toDelete?.name ?? "")” and all of its history? This cannot be undone.",
                            isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let h = toDelete { store.remove(habit: h.id) }; toDelete = nil }
            Button("Cancel", role: .cancel) { toDelete = nil }
        }
    }
}

// MARK: - Safety copies

struct SafetyCopiesScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @State private var picked: URL?
    @State private var pickedData: TrackingData?

    private var copies: [URL] {
        store.safetyCopies.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
    }

    var body: some View {
        Page(id: "screen-copies") {
            Text("A copy is made by itself every day, 30 kept. Tap one to see what is in it and put it back.")
                .font(.footnote).foregroundStyle(Ink.dim).padding(.top, 8)
            if copies.isEmpty {
                Text("No copies yet.").font(.subheadline).foregroundStyle(Ink.dim).accessibilityIdentifier("copies-empty")
            } else {
                SettingsGroup {
                    ForEach(Array(copies.enumerated()), id: \.element) { i, url in
                        if i > 0 { RowDivider() }
                        Button { picked = url; pickedData = store.peek(url) } label: {
                            RowLabel(title: url.deletingPathExtension().lastPathComponent, chevron: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("copy-\(i)")
                    }
                }
            }
        }
        .settingsPage("Safety copies")
        .confirmationDialog(dialogTitle, isPresented: Binding(get: { picked != nil }, set: { if !$0 { picked = nil; pickedData = nil } }), titleVisibility: .visible) {
            if let d = pickedData {
                Button("Restore this copy", role: .destructive) {
                    store.writeCopy(named: "Before restore")
                    store.replaceAll(with: d)
                    store.showToast("Copy restored", seconds: 5)
                    picked = nil; pickedData = nil
                }
            }
            Button("Cancel", role: .cancel) { picked = nil; pickedData = nil }
        } message: {
            Text(pickedData == nil ? "This copy cannot be read." : "Your data now is saved as a copy first, so you can come back.")
        }
    }

    private var dialogTitle: String {
        guard let d = pickedData else { return "Copy" }
        return "\(Fmt.count(d.liveHabits.count, "habit")) in this copy. Replace current data with it?"
    }
}

// MARK: - Import fasting history

struct HistoryImportSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private var habit: Habit? { store.data.fastingHabit }

    var body: some View {
        let existing = Set(habit?.fastDays.ms.keys.map { $0 } ?? [])
        let p = HistoryImport.preview(text, existingEndDays: existing)
        let empty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        VStack(alignment: .leading, spacing: 8) {
            Text("Import fasting history").font(.title2.weight(.heavy))
            Text("Paste rows from another app's export. Understood formats, one fast per line:").font(.footnote).foregroundStyle(Ink.dim)
            VStack(alignment: .leading, spacing: 2) {
                Text("• 2026-08-15;14  (day; hours — also with , . or tab)")
                Text("• 2026-08-15 19:00;2026-08-16 11:00  (start; end)")
                Text("• rows from this app's own fasts.csv")
            }.font(.footnote).foregroundStyle(Ink.dim)
            TextEditor(text: $text)
                .font(.system(.footnote, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 130, maxHeight: 200)
                .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.border, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if empty { Text("2026-08-01;13\n2026-08-02;14,5\n…").font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Ink.dim.opacity(0.7)).padding(.horizontal, 11).padding(.vertical, 14).allowsHitTesting(false) }
                }
                .accessibilityIdentifier("histimport-text")
            Text(habit == nil ? "No fasting habit to import into." : HistoryImport.message(p, empty: empty))
                .font(.footnote.weight(.semibold)).foregroundStyle(habit == nil ? Ink.stale : Ink.dim)
                .accessibilityIdentifier("histimport-preview")
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Cancel").font(.body.weight(.semibold)).foregroundStyle(Ink.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Ink.surface))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Ink.border, lineWidth: 1))
                }
                .buttonStyle(.plain).keyboardShortcut(.cancelAction).accessibilityIdentifier("btn-histimport-cancel")
                Button { save(p) } label: {
                    Text("Import").font(.body.weight(.bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Ink.accent))
                        .opacity(p.fresh.isEmpty || habit == nil ? 0.4 : 1)
                }
                .buttonStyle(.plain).disabled(p.fresh.isEmpty || habit == nil)
                .accessibilityIdentifier("btn-histimport-save")
            }
        }
        .padding(16)
        .background(Ink.bg.ignoresSafeArea())
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 460)
        #endif
        .accessibilityIdentifier("sheet-histimport")
    }

    private func save(_ p: HistoryImport.Preview) {
        guard let h = habit else { return }
        let add = HistoryImport.toSave(p.fresh)
        guard !add.isEmpty else { return }
        store.update(h.id) { $0.sessions.append(contentsOf: add.map { Session(s: $0.s, e: $0.e) }) }
        let starts = Set(add.map(\.s))
        store.showToast(Fmt.count(add.count, "fast") + " imported") {
            store.update(h.id) { $0.sessions.removeAll { starts.contains($0.s) } }
        }
        dismiss()
    }
}
