import SwiftUI
import UniformTypeIdentifiers

/// Settings (screens doc 9): iCloud, your data, this device's reminder and badge, how the app looks, guides.
struct SettingsScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav

    @State private var exportDoc: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingImport: TrackingData?
    @State private var importError: String?
    @State private var showHistory = false

    var body: some View {
        let _ = store.tick
        Page(id: "screen-settings") {
            if nav.wide { PageTitle(title: "Settings") }
            icloud
            yourData
            reminder
            habits
            guides
            Text("Version \(AppInfo.version) (\(AppInfo.build))")
                .font(.footnote).foregroundStyle(Ink.dim).frame(maxWidth: .infinity)
                .padding(.top, 4)
                .accessibilityIdentifier("app-version")
        }
        .navigationTitle(nav.wide ? "" : "Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if nav.sheet == .settings {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { nav.sheet = nil }.keyboardShortcut(.cancelAction).accessibilityIdentifier("btn-settings-done")
                }
            }
        }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json, defaultFilename: BackupFiles.fileName()) { result in
            if case .success = result {
                store.updateSettings { $0.lastBackup = nowMs() }
                store.showToast("Backup saved")
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in readBackup(result) }
        .confirmationDialog("Replace current data with this backup (\(pendingImport?.habits.count ?? 0) habits)?",
                            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
            Button("Replace", role: .destructive) { applyImport() }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: { Text("A copy of your data now is saved first.") }
        .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "") }
        .sheet(isPresented: $showHistory) { HistoryImportSheet().environmentObject(store) }
    }

    // MARK: iCloud

    private var icloud: some View {
        SettingsGroup(title: "iCloud", footer: "A copy is made by itself every day, 30 kept.") {
            RowLabel(icon: "case", title: "Stored in", detail: store.syncPlace)
                .accessibilityIdentifier("sync-place")
            RowDivider()
            RowLabel(title: "State", detail: store.cloudState.isEmpty ? "—" : store.cloudState,
                     detailColor: store.cloudState == "Up to date" ? Ink.chart : Ink.stale)
                .accessibilityIdentifier("cloud-state")
            RowDivider()
            RowLabel(title: "Last synced", detail: store.lastSynced.map { Self.relative($0) } ?? "not yet")
                .accessibilityIdentifier("last-synced")
            RowDivider()
            Button { store.syncNow() } label: {
                RowLabel(icon: "export", title: store.syncing ? "Syncing…" : "Sync now")
            }
            .buttonStyle(.plain).disabled(store.syncing)
            .accessibilityIdentifier("btn-sync-now")
            RowDivider()
            NavigationLink { SafetyCopiesScreen() } label: {
                RowLabel(icon: "scroll", title: "Safety copies", detail: "\(store.safetyCopies.count)", chevron: true)
            }
            .buttonStyle(.plain).accessibilityIdentifier("btn-copies")
        }
    }

    static func relative(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .full
        return f.localizedString(for: d, relativeTo: Date())
    }

    // MARK: Your data

    private var yourData: some View {
        SettingsGroup(title: "Your data", footer: BackupFiles.lastBackupText(store.data.settings.lastBackup)) {
            Button(action: exportBackup) { RowLabel(icon: "export", title: "Export backup (JSON)") }
                .buttonStyle(.plain).accessibilityIdentifier("btn-export")
            RowDivider()
            Button { importing = true } label: { RowLabel(icon: "import", title: "Import backup") }
                .buttonStyle(.plain).accessibilityIdentifier("btn-import")
            RowDivider()
            ShareLink(items: [CSVFile(name: CSVExport.fileName("days"), text: CSVExport.daysCSV(store.data.liveHabits)),
                              CSVFile(name: CSVExport.fileName("fasts"), text: CSVExport.fastsCSV(store.data.liveHabits))],
                      preview: { SharePreview($0.name) }) {
                RowLabel(icon: "chart", title: "Export CSV for Excel")
            }
            .buttonStyle(.plain).accessibilityIdentifier("btn-csv")
            RowDivider()
            Button { showHistory = true } label: { RowLabel(icon: "timer", title: "Import fasting history", chevron: true) }
                .buttonStyle(.plain).accessibilityIdentifier("btn-histimport")
        }
    }

    private func exportBackup() {
        guard let data = try? store.data.backupJSON() else { store.showToast("Backup failed"); return }
        exportDoc = BackupDocument(data: data)
        exporting = true
    }

    private func readBackup(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let e): importError = e.localizedDescription
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let raw = try? Data(contentsOf: url) else { importError = "The file could not be read."; return }
            do { pendingImport = try JSONDecoder().decode(TrackingData.self, from: raw) }
            catch { importError = "Not an AMS Tracking backup" }
        }
    }

    private func applyImport() {
        guard let backup = pendingImport else { return }
        pendingImport = nil
        store.writeCopy(named: "Before import")
        store.replaceAll(with: backup)
        store.showToast("Backup imported — \(Fmt.count(backup.habits.count, "habit"))")
        // A reminder that was on in the backup turns on here only once notifications are allowed.
        if let r = BackupFiles.reminder(in: backup), r.on {
            Task {
                if await SideEffects.askPermission() { store.device.reminderOn = true; store.device.reminderTime = r.time; store.device.lostPermission = false }
            }
        }
    }

    // MARK: Reminder and badge

    private var reminder: some View {
        SettingsGroup(title: "On this device") {
            ReminderRow()
            RowDivider()
            Button(action: toggleBadge) {
                RowLabel(icon: "sun", title: store.device.badge ? "Hide the count on the app icon" : "Show the count on the app icon")
            }
            .buttonStyle(.plain).accessibilityIdentifier("btn-badge")
        }
    }

    private func toggleBadge() {
        if store.device.badge {
            store.device.badge = false
            store.showToast("The count is off the app icon")
            return
        }
        Task {
            if await SideEffects.askPermission() {
                store.device.badge = true
                store.showToast("The count will now show on the app icon")
            } else {
                store.showToast("Not allowed — turn notifications on for Tracking in Settings", seconds: 6)
            }
        }
    }

    // MARK: Habits and looks

    private var habits: some View {
        SettingsGroup(title: "Habits and look") {
            NavigationLink { ReorderScreen() } label: { RowLabel(icon: "reorder", title: "Reorder habits", chevron: true) }
                .buttonStyle(.plain).accessibilityIdentifier("btn-reorder")
            RowDivider()
            pickerRow("Layout", icon: "grid", id: "picker-layout",
                      selection: Binding(get: { store.data.settings.layout }, set: { v in store.updateSettings { $0.layout = v } }),
                      options: [("list", "List"), ("grid", "Grid")])
            RowDivider()
            pickerRow("Theme", icon: "moon", id: "picker-theme",
                      selection: Binding(get: { store.data.settings.theme }, set: { v in store.updateSettings { $0.theme = v } }),
                      options: [("auto", "Auto"), ("light", "Light"), ("dark", "Dark")])
            RowDivider()
            NavigationLink { ArchivedScreen() } label: {
                RowLabel(icon: "case", title: "Archived habits", detail: "(\(store.data.archivedHabits.count))", chevron: true)
            }
            .buttonStyle(.plain).accessibilityIdentifier("btn-archived")
            RowDivider()
            Button {
                if !nav.wide { nav.sheet = nil }
                nav.open(.lastWeek)
            } label: { RowLabel(icon: "export", title: "Send last week's report", chevron: true) }
                .buttonStyle(.plain).accessibilityIdentifier("btn-week-report")
        }
    }

    private func pickerRow(_ title: String, icon: String, id: String, selection: Binding<String>, options: [(String, String)]) -> some View {
        HStack(spacing: 10) {
            TrackIcon(name: icon, size: 18, color: Ink.accent)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer(minLength: 6)
            Picker(title, selection: selection) {
                ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .accessibilityIdentifier(id)
        }
        .padding(.vertical, 6).padding(.horizontal, 14)
        .frame(minHeight: 42)
    }

    // MARK: Guides

    private var guides: some View {
        SettingsGroup {
            NavigationLink { GuideScreen() } label: { RowLabel(icon: "help", title: "How it works", chevron: true) }
                .buttonStyle(.plain).accessibilityIdentifier("btn-guide")
            RowDivider()
            NavigationLink { WhatsNewScreen() } label: { RowLabel(icon: "scroll", title: "What's new", chevron: true) }
                .buttonStyle(.plain).accessibilityIdentifier("btn-whatsnew")
        }
    }
}

/// Daily reminder on this device: switch + time, with the one-line state under it.
struct ReminderRow: View {
    @EnvironmentObject var store: Store

    private var timeBinding: Binding<Date> {
        Binding {
            let p = store.device.reminderTime.split(separator: ":").compactMap { Int($0) }
            let h = p.count == 2 ? p[0] : 20, m = p.count == 2 ? p[1] : 0
            return DayKey.calendar.date(bySettingHour: h, minute: m, second: 0, of: DayKey.now) ?? DayKey.now
        } set: { d in
            let t = Fmt.clock(d)
            guard t != store.device.reminderTime else { return }
            store.device.reminderTime = t
            if store.device.reminderOn { store.showToast("Reminder moved to \(t)") }
        }
    }

    private var onBinding: Binding<Bool> {
        Binding(get: { store.device.reminderOn }, set: { on in
            if !on {
                store.device.reminderOn = false
                return
            }
            Task {
                if await SideEffects.askPermission() {
                    store.device.lostPermission = false
                    store.device.reminderOn = true
                    store.showToast("Reminder on — every day at \(store.device.reminderTime)")
                } else {
                    store.device.reminderOn = false
                    store.device.lostPermission = true
                }
            }
        })
    }

    private var note: String {
        if store.device.reminderOn { return "Every day at \(store.device.reminderTime) — also when the app is closed." }
        if store.device.lostPermission { return "Off — notifications were turned off for Tracking in Settings." }
        return "Pick the time, then switch it on."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                TrackIcon(name: "bell", size: 18, color: Ink.accent)
                Toggle(isOn: onBinding) { Text("Daily reminder").font(.subheadline.weight(.semibold)) }
                    .accessibilityIdentifier("reminder-toggle")
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden().fixedSize()
                    .accessibilityIdentifier("reminder-time")
            }
            Text(note).font(.footnote).foregroundStyle(store.device.lostPermission && !store.device.reminderOn ? Ink.stale : Ink.dim)
                .accessibilityIdentifier("reminder-note")
        }
        .padding(.vertical, 8).padding(.horizontal, 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reminder-row")
    }
}
