import SwiftUI

/// Where the user is. iPhone: one stack on Today, the floating bar (Stats · ＋ · Settings).
/// iPad and Mac (his pick 2, 26 Nov 2026): sidebar · the chosen part (Today, Stats …) · the tapped habit's page.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today, stats, lastWeek, lastMonth, aspirations, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: "Today"
        case .stats: "Stats"
        case .lastWeek: "Last week"
        case .lastMonth: "Last month"
        case .aspirations: "Aspirations"
        case .settings: "Settings"
        }
    }
    var icon: String {
        switch self {
        case .today: "grid"
        case .stats: "chart"
        case .lastWeek, .lastMonth: "bulb"
        case .aspirations: "target"
        case .settings: "sliders"
        }
    }
}

enum Route: Hashable {
    case habit(String)
    case section(AppSection)
}

enum SheetKind: Identifiable, Hashable {
    case addHabit(prefill: HabitPrefill?)
    case editHabit(String)
    case settings
    var id: String {
        switch self {
        case .addHabit(let p): "add-\(p?.name ?? "")"
        case .editHabit(let id): "edit-\(id)"
        case .settings: "settings"
        }
    }
}

/// A suggestion from Last week ("Add this habit") fills the new-habit sheet; nothing is made until Save.
struct HabitPrefill: Hashable {
    var name: String
    var icon: String
    var type: HabitType
    var target: Int?
}

@MainActor
final class Nav: ObservableObject {
    @Published var path: [Route] = []
    @Published var section: AppSection? = .today
    @Published var selectedHabit: String?
    @Published var sheet: SheetKind?
    /// A week dot was tapped: the habit page opens on that day's month and flashes the day.
    @Published var focusDay: String?
    var wide = false

    func open(habit id: String, day: String? = nil) {
        focusDay = day
        if wide { selectedHabit = id } else {
            if case .habit(let current)? = path.last, current == id { return }
            path.append(.habit(id))
        }
    }
    func open(_ s: AppSection) {
        if s == .settings && !wide { sheet = .settings; return }
        if wide { section = s } else { path.append(.section(s)) }
    }
    func back() { if !path.isEmpty { path.removeLast() } }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @StateObject private var nav = Nav()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var phase

    private var wide: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }
    private var scheme: ColorScheme? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-dark") { return .dark }
        if args.contains("-light") { return .light }
        switch store.data.settings.theme { case "light": return .light; case "dark": return .dark; default: return nil }
    }

    var body: some View {
        Group {
            if wide { WideRoot() } else { PhoneRoot() }
        }
        .environmentObject(nav)
        .onAppear { nav.wide = wide }
        .onChange(of: wide) { _, w in nav.wide = w }
        .overlay(alignment: .bottom) { ToastBar().padding(.bottom, wide ? 22 : 92) }
        .overlay { CelebrationOverlay() }
        .sheet(item: $nav.sheet) { kind in
            Group {
                switch kind {
                case .addHabit(let prefill): HabitFormSheet(editing: nil, prefill: prefill)
                case .editHabit(let id): HabitFormSheet(editing: id, prefill: nil)
                case .settings: NavigationStack { SettingsScreen() }
                }
            }
            .environmentObject(store)
            .environmentObject(nav)
            .preferredColorScheme(scheme)
        }
        .preferredColorScheme(scheme)
        .tint(Ink.accent)
        .onChange(of: phase) { _, p in
            if p == .active { store.syncNow(); applyPendingQuickAction() }
            if p == .background { store.saveNow() }
        }
        .onAppear {
            applyPendingQuickAction()
            QuickActions.takeShellSteps()
        }
    }

    private func applyPendingQuickAction() {
        if let t = QuickActions.pending { QuickActions.pending = nil; QuickActions.handle(t) }
    }
}

// MARK: - iPhone

struct PhoneRoot: View {
    @EnvironmentObject var nav: Nav

    var body: some View {
        NavigationStack(path: $nav.path) {
            TodayScreen()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .habit(let id): HabitDetailScreen(habitID: id)
                    case .section(let s): SectionScreen(section: s)
                    }
                }
        }
    }
}

/// One part of the app by its section.
struct SectionScreen: View {
    let section: AppSection
    var body: some View {
        switch section {
        case .today: TodayScreen()
        case .stats: StatsScreen()
        case .lastWeek: LastWeekScreen()
        case .lastMonth: LastMonthScreen()
        case .aspirations: AspirationsScreen()
        case .settings: SettingsScreen()
        }
    }
}

// MARK: - iPad and Mac

struct WideRoot: View {
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var store: Store
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $nav.section) {
                ForEach(AppSection.allCases) { s in
                    Label { Text(s.title) } icon: { TrackIcon(name: s.icon, size: 20, color: Ink.accent) }
                        .tag(s)
                        .accessibilityIdentifier("sidebar-\(s.rawValue)")
                }
            }
            .navigationTitle("Tracking")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
            #endif
            .safeAreaInset(edge: .bottom) {
                Text("Version \(AppInfo.version)").font(.caption2).foregroundStyle(Ink.dim)
                    .padding(8).accessibilityIdentifier("sidebar-version")
            }
        } content: {
            NavigationStack {
                SectionScreen(section: nav.section ?? .today)
            }
            .navigationSplitViewColumnWidth(min: 340, ideal: 400, max: 520)
        } detail: {
            NavigationStack {
                if let id = nav.selectedHabit, store.data.habit(id) != nil {
                    HabitDetailScreen(habitID: id).id(id)
                } else {
                    PickAHabit()
                }
            }
        }
    }
}

private struct PickAHabit: View {
    var body: some View {
        VStack(spacing: 10) {
            TrackIcon(name: "grid", size: 44, color: Ink.dim)
            Text("Tap a habit to see its page here.").font(.subheadline).foregroundStyle(Ink.dim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.bg)
        .accessibilityIdentifier("detail-empty")
    }
}

enum AppInfo {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
}
