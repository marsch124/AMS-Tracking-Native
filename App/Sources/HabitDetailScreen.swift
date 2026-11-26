import SwiftUI

/// A habit's page (Lane A): calendar, fasting stages and fasts (timer habits), a pixel grid per year, poster,
/// archive and delete. Web spec: screens 6.
struct HabitDetailScreen: View {
    let habitID: String
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @State private var daySheet: DaySheet?
    @State private var poster: PosterFile?
    @State private var confirmDelete = false

    var body: some View {
        let _ = store.tick
        Page(id: "screen-detail") {
            if let h = store.data.habit(habitID) {
                PageTitle(title: h.name, subtitle: subtitle(h), icon: h.icon, iconColor: Color(hex: h.color))
                CalendarCard(habit: h, daySheet: $daySheet)
                if h.type == .timer {
                    StagesCard(habit: h)
                    FastsCard(habit: h, daySheet: $daySheet)
                }
                ForEach(h.yearsShown(today: DayKey.today()), id: \.self) { y in
                    YearCard(habit: h, year: y) { year in
                        poster = PosterMaker.make(h, year: year, today: DayKey.today())
                    }
                }
                actions(h)
            }
        }
        .daySheets($daySheet)
        .sheet(item: $poster) { p in PosterSheet(poster: p) }
        .confirmationDialog(confirmText, isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete habit", role: .destructive) { delete() }
                .accessibilityIdentifier("btn-delete-confirm")
            Button("Cancel", role: .cancel) {}
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { nav.sheet = .editHabit(habitID) } label: {
                    HStack(spacing: 5) {
                        TrackIcon(name: "pencil", size: 16, color: Ink.accent)
                        Text("Edit").font(.body.weight(.semibold))
                    }
                }
                .accessibilityIdentifier("btn-edit")
            }
        }
    }

    private var confirmText: String {
        "Delete “\(store.data.habit(habitID)?.name ?? "")” and all of its history? This cannot be undone."
    }

    private func subtitle(_ h: Habit) -> String {
        switch h.type {
        case .timer: "Start / stop timer habit"
        case .weekly: "Weekly target · \(h.weeklyTarget)× a week"
        case .daily: "Daily habit"
        }
    }

    private func actions(_ h: Habit) -> some View {
        VStack(spacing: 10) {
            Button { archive(h) } label: {
                Text("Archive habit").font(.body.weight(.semibold)).foregroundStyle(Ink.accent)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Ink.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Ink.border, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("btn-archive")
            Button { confirmDelete = true } label: {
                Text("Delete habit").font(.body.weight(.semibold)).foregroundStyle(Ink.danger)
                    .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("btn-delete")
        }
        .padding(.top, 6)
    }

    /// Back to Today (iPhone: pop; iPad and Mac: empty the right column).
    private func leave() {
        if nav.wide { nav.selectedHabit = nil } else { nav.back() }
    }

    private func archive(_ h: Habit) {
        let snapshot = h
        store.update(h.id) { $0.archived = true }
        store.showToast("“\(h.name)” archived") { [weak store] in store?.restore(snapshot) }
        leave()
    }

    private func delete() {
        store.remove(habit: habitID)
        leave()
    }
}
