import Foundation
import SwiftUI

/// Everything the app knows, and the only thing allowed to touch disk.
/// One file in iCloud Drive (iPhone, iPad and Mac read the same one), merged per habit before every write,
/// a proved safety copy each day (30 kept) — the pattern of AMS FermentLog / Subscriptions / Shopping, kept whole.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var data = TrackingData()
    @Published var device: DeviceSettings { didSet { if device != oldValue { device.save(to: defaults); effects() } } }
    @Published var toast: Toast?
    @Published var celebration: Celebration?
    @Published private(set) var cloudState = ""
    @Published private(set) var syncPlace = "This device"
    @Published private(set) var lastSynced: Date?
    @Published private(set) var syncing = false
    @Published private(set) var saveProblem: String?
    @Published private(set) var safetyCopies: [URL] = []
    @Published private(set) var conflictsMerged = 0
    /// Ticks every 20 s so running fasts and eating windows move on screen.
    @Published private(set) var tick = Date()

    var needsUpdate: Bool { data.format > TrackingData.currentFormat }
    let isTestRun: Bool
    let home: URL
    private let dataURL: URL
    let copiesURL: URL
    private let defaults: UserDefaults
    private let coordinator = NSFileCoordinator()
    private var saveWork: Task<Void, Never>?
    private var toastWork: Task<Void, Never>?
    private var watcher: FileWatcher?
    private var ticker: Timer?

    static let containerID = "iCloud.io.github.marsch124.amstracking"
    static let fileName = "tracking.json"

    init(root: URL? = nil) {
        let args = ProcessInfo.processInfo.arguments
        // A unit-test run hosts the app too: it never touches the real file (iCloud) either.
        isTestRun = args.contains("-uiTesting") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let d = isTestRun ? (UserDefaults(suiteName: "AMSTracking-UITest") ?? .standard) : .standard
        if isTestRun { d.removePersistentDomain(forName: "AMSTracking-UITest") }
        defaults = d
        device = DeviceSettings.load(from: d)
        home = root ?? Store.defaultRoot(freshForTests: isTestRun)
        let fm = FileManager.default
        try? fm.createDirectory(at: home, withIntermediateDirectories: true)
        dataURL = home.appendingPathComponent(Store.fileName)
        copiesURL = home.appendingPathComponent("Safety copies")
        try? fm.createDirectory(at: copiesURL, withIntermediateDirectories: true)
        load()
        if isTestRun {
            if args.contains("-sample") { data = SampleData.make() }
            if args.contains("-firstStart") { data = TrackingData.firstStart() }
            if args.contains("-grid") { data.settings.layout = "grid" }
            if args.contains("-needsUpdate") { data.format = TrackingData.currentFormat + 1 }
        } else if root == nil {
            takeOverShellCopy()
            watcher = FileWatcher(url: dataURL) { [weak self] in Task { @MainActor in self?.load() } }
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick = Date() }
        }
    }

    private static func defaultRoot(freshForTests: Bool) -> URL {
        let fm = FileManager.default
        if freshForTests {
            return fm.temporaryDirectory.appendingPathComponent("AMSTracking-UITest-\(UUID().uuidString)")
        }
        if let cloud = fm.url(forUbiquityContainerIdentifier: containerID) {
            let docs = cloud.appendingPathComponent("Documents")
            try? fm.createDirectory(at: docs, withIntermediateDirectories: true)
            return docs
        }
        return fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AMSTracking")
    }

    // MARK: Load & save

    func load() {
        if inCloud { try? FileManager.default.startDownloadingUbiquitousItem(at: dataURL) }
        var loaded: TrackingData?
        var err: NSError?
        coordinator.coordinate(readingItemAt: dataURL, options: [], error: &err) { url in
            if let raw = try? Data(contentsOf: url) { loaded = try? JSONDecoder().decode(TrackingData.self, from: raw) }
        }
        // Merge, never a blind replace: what this device changed and has not saved yet stays (newest change wins).
        if let loaded { data = TrackingData.merged(data, loaded); lastSynced = Date() }
        mergeConflictCopies()
        syncPlace = inCloud ? "iCloud Drive" : "This device"
        purgeRemoved()
        refreshCopies()
        refreshCloudState()
        effects()
    }

    var inCloud: Bool { dataURL.path.contains("Mobile Documents") }

    func refreshCloudState() {
        guard inCloud else { cloudState = "Not in iCloud — turn on iCloud Drive for Tracking on every device"; return }
        let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey, .ubiquitousItemIsUploadingKey,
                                         .ubiquitousItemIsUploadedKey, .ubiquitousItemDownloadingErrorKey, .ubiquitousItemUploadingErrorKey]
        guard let v = try? dataURL.resourceValues(forKeys: keys) else { cloudState = "No shared file yet"; return }
        if let e = v.ubiquitousItemUploadingError { cloudState = "Upload failed: \(e.localizedDescription)"; return }
        if let e = v.ubiquitousItemDownloadingError { cloudState = "Download failed: \(e.localizedDescription)"; return }
        if v.ubiquitousItemIsDownloading == true { cloudState = "Downloading…"; return }
        if v.ubiquitousItemIsUploading == true { cloudState = "Uploading…"; return }
        if let s = v.ubiquitousItemDownloadingStatus, s != .current { cloudState = "A newer version is waiting in iCloud"; return }
        if v.ubiquitousItemIsUploaded == false { cloudState = "Waiting to upload"; return }
        cloudState = "Up to date"
    }

    private var hasNewestVersion: Bool {
        guard inCloud, let v = try? dataURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey]) else { return true }
        return v.ubiquitousItemIsDownloading != true && (v.ubiquitousItemDownloadingStatus ?? .current) == .current
    }

    /// Two devices writing at the same moment: iCloud keeps one write and sets the other aside as a
    /// "conflict copy" nobody sees. Every copy set aside is merged in here, then cleared.
    private func mergeConflictCopies() {
        guard !isTestRun, inCloud else { return }
        let copies = NSFileVersion.unresolvedConflictVersionsOfItem(at: dataURL) ?? []
        guard !copies.isEmpty else { return }
        var merged = 0
        for v in copies {
            if let raw = try? Data(contentsOf: v.url), let other = try? JSONDecoder().decode(TrackingData.self, from: raw) {
                data = TrackingData.merged(data, other); merged += 1
            }
            v.isResolved = true
        }
        try? NSFileVersion.removeOtherVersionsOfItem(at: dataURL)
        if merged > 0 { conflictsMerged += merged; scheduleSave() }
    }

    /// Settings › Sync now (and every return to the app): fetch the newest version, merge, write back.
    func syncNow() {
        guard !syncing else { return }
        syncing = true
        Task { [weak self] in
            guard let self else { return }
            if inCloud {
                try? FileManager.default.startDownloadingUbiquitousItem(at: dataURL)
                for _ in 0..<20 where !hasNewestVersion {
                    refreshCloudState()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
            saveWork?.cancel()
            load()
            if data.savedAt > 0 { saveNow() }
            lastSynced = Date()
            refreshCloudState()
            syncing = false
        }
    }

    func scheduleSave() {
        effects()
        saveWork?.cancel()
        saveWork = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow(merge: Bool = true) {
        saveWork?.cancel()
        data.savedAt = nowMs()
        var toWrite = data
        var err: NSError?
        var problem: String?
        var held = false
        coordinator.coordinate(writingItemAt: dataURL, options: .forMerging, error: &err) { url in
            if merge, let raw = try? Data(contentsOf: url) {
                if let onDisk = try? JSONDecoder().decode(TrackingData.self, from: raw) {
                    toWrite = TrackingData.merged(onDisk, toWrite)
                } else if !raw.isEmpty {
                    // A file this app cannot read is never written over blind — parked in Safety copies first.
                    try? raw.write(to: copiesURL.appendingPathComponent("Could not read " + Store.stamp() + ".json"), options: .atomic)
                }
            }
            guard toWrite.format <= TrackingData.currentFormat else { held = true; return }
            do { try JSONEncoder.pretty.encode(toWrite).write(to: url, options: .atomic) } catch { problem = error.localizedDescription }
        }
        if let err { problem = err.localizedDescription }
        data = toWrite
        if held { refreshCloudState(); return }
        noteSave(problem)
        dailySafetyCopy()
        refreshCloudState()
        effects()
    }

    private func noteSave(_ problem: String?) {
        if problem != nil, saveProblem == nil { showToast("Could not save. Your changes are not stored yet.") }
        if saveProblem != problem { saveProblem = problem }
    }

    /// Badge, reminders, the icon menu and Siri's status follow every change.
    func effects() {
        guard !isTestRun || ProcessInfo.processInfo.arguments.contains("-effects") else { return }
        SideEffects.refresh(self)
    }

    // MARK: Safety copies — each one read back before it counts

    static func stamp() -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return f.string(from: Date())
    }

    private func dailySafetyCopy() {
        let url = copiesURL.appendingPathComponent("Daily " + DayKey.today() + ".json")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        writeCopy(to: url)
    }

    @discardableResult
    func writeCopy(named: String? = nil, to target: URL? = nil) -> Bool {
        let url = target ?? copiesURL.appendingPathComponent((named ?? "Copy") + " " + Store.stamp() + ".json")
        guard !needsUpdate, let payload = try? JSONEncoder.pretty.encode(data) else { return false }
        try? payload.write(to: url, options: .atomic)
        guard let back = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(TrackingData.self, from: back),
              decoded.habits.count == data.habits.count,
              decoded.aspirations.count == data.aspirations.count else {
            try? FileManager.default.removeItem(at: url)
            return false
        }
        pruneCopies()
        return true
    }

    private func pruneCopies() {
        let all = (try? FileManager.default.contentsOfDirectory(at: copiesURL, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let daily = all.filter { $0.lastPathComponent.hasPrefix("Daily ") }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in daily.dropFirst(30) { try? FileManager.default.removeItem(at: old) }
        refreshCopies()
    }

    func refreshCopies() {
        let all = (try? FileManager.default.contentsOfDirectory(at: copiesURL, includingPropertiesForKeys: nil)) ?? []
        safetyCopies = all.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func peek(_ url: URL) -> TrackingData? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TrackingData.self, from: raw)
    }

    /// Removed habits and aspirations leave for good after 30 days (long enough to reach every device).
    private func purgeRemoved() {
        let cutoff = nowMs() - 30 * 86_400_000
        let before = data
        data.habits.removeAll { ($0.deletedAt ?? .infinity) < cutoff }
        data.aspirations.removeAll { ($0.deletedAt ?? .infinity) < cutoff }
        if data != before { scheduleSave() }
    }

    // MARK: Changing things — one way in

    /// Changes one habit; it is stamped as changed now, so it wins the merge on the other devices.
    func update(_ id: String, _ change: (inout Habit) -> Void) {
        guard let i = data.habits.firstIndex(where: { $0.id == id }) else { return }
        change(&data.habits[i])
        data.habits[i].sessions.sort { $0.s < $1.s }
        data.habits[i].mt = nowMs()
        scheduleSave()
    }

    /// Puts a habit back exactly as it was (the Undo of a toast).
    func restore(_ h: Habit) {
        var h = h
        h.mt = nowMs()
        if let i = data.habits.firstIndex(where: { $0.id == h.id }) { data.habits[i] = h } else { data.habits.append(h) }
        scheduleSave()
    }

    func add(_ h: Habit) {
        var h = h
        h.mt = nowMs()
        data.habits.append(h)
        scheduleSave()
    }

    func remove(habit id: String) {
        update(id) { $0.deletedAt = nowMs() }
    }

    /// The new order of the habits (ids of the visible ones); archived and removed ones keep their place at the end.
    func reorder(_ ids: [String]) {
        let rank = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        data.habits = data.habits.enumerated().sorted { a, b in
            (rank[a.element.id] ?? 100_000 + a.offset) < (rank[b.element.id] ?? 100_000 + b.offset)
        }.map(\.element)
        data.orderMt = nowMs()
        scheduleSave()
    }

    func updateAspiration(_ id: String, _ change: (inout Aspiration) -> Void) {
        guard let i = data.aspirations.firstIndex(where: { $0.id == id }) else { return }
        change(&data.aspirations[i])
        data.aspirations[i].mt = nowMs()
        scheduleSave()
    }
    func add(_ a: Aspiration) {
        var a = a; a.mt = nowMs()
        data.aspirations.append(a)
        scheduleSave()
    }

    func updateSettings(_ change: (inout SharedSettings) -> Void) {
        change(&data.settings)
        data.settings.mt = nowMs()
        scheduleSave()
    }

    // MARK: Backup in and out (the web app's own shape)

    /// "Replace current data with this backup?" — every habit and aspiration here is replaced by the backup's.
    /// Done as removals + additions, so the other devices follow.
    func replaceAll(with backup: TrackingData) {
        let now = nowMs()
        let incoming = Set(backup.habits.map(\.id))
        let incomingAsp = Set(backup.aspirations.map(\.id))
        for i in data.habits.indices where !incoming.contains(data.habits[i].id) && data.habits[i].deletedAt == nil {
            data.habits[i].deletedAt = now; data.habits[i].mt = now
        }
        for i in data.aspirations.indices where !incomingAsp.contains(data.aspirations[i].id) && data.aspirations[i].deletedAt == nil {
            data.aspirations[i].deletedAt = now; data.aspirations[i].mt = now
        }
        let kept = data.habits.filter { !incoming.contains($0.id) }
        data.habits = backup.habits.map { var h = $0; h.mt = now; h.deletedAt = nil; return h } + kept
        let keptAsp = data.aspirations.filter { !incomingAsp.contains($0.id) }
        data.aspirations = backup.aspirations.map { var a = $0; a.mt = now; a.deletedAt = nil; return a } + keptAsp
        var s = backup.settings
        s.mt = now
        data.settings = s
        data.orderMt = now
        scheduleSave()
    }

    /// A first start after the TestFlight web-in-a-shell app (1.50/1.51, same App Store app): its safety copy
    /// `Library/amsTracking.v1.json` is taken over by itself — when this device has no habits yet.
    private func takeOverShellCopy() {
        let fm = FileManager.default
        guard let lib = fm.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        let shell = lib.appendingPathComponent("amsTracking.v1.json")
        guard fm.fileExists(atPath: shell.path) else { return }
        defer { try? fm.moveItem(at: shell, to: lib.appendingPathComponent("amsTracking.v1.taken-over.json")) }
        guard data.liveHabits.isEmpty, let raw = try? Data(contentsOf: shell),
              let old = try? JSONDecoder().decode(TrackingData.self, from: raw), !old.habits.isEmpty else { return }
        replaceAll(with: old)
        showToast("Your habits from the earlier Tracking app are here", seconds: 8)
    }

    // MARK: The toast — one line at the bottom, with Undo

    func showToast(_ text: String, action: String = "Undo", seconds: Double = 5, undo: (() -> Void)? = nil) {
        toastWork?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { toast = Toast(text: text, actionLabel: action, action: undo) }
        toastWork = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.hideToast()
        }
    }
    func hideToast() { toastWork?.cancel(); withAnimation(.easeIn(duration: 0.2)) { toast = nil } }

    func celebrate(_ title: String, sub: String, colorHex: String) {
        celebration = Celebration(title: title, sub: sub, colorHex: colorHex)
    }

    func resetForTests() { data = TrackingData() }
}

struct Toast: Equatable, Identifiable {
    let id = UUID()
    let text: String
    var actionLabel = "Undo"
    let action: (() -> Void)?
    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

struct Celebration: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let sub: String
    let colorHex: String
}

/// Tells the store when the shared file changes — written by another device through iCloud Drive.
final class FileWatcher: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()
    private let changed: () -> Void
    private let query = NSMetadataQuery()

    init(url: URL, changed: @escaping () -> Void) {
        presentedItemURL = url
        self.changed = changed
        super.init()
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
        NSFileCoordinator.addFilePresenter(self)
        if url.path.contains("Mobile Documents") {
            query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, url.lastPathComponent)
            NotificationCenter.default.addObserver(self, selector: #selector(queryUpdated), name: .NSMetadataQueryDidUpdate, object: query)
            NotificationCenter.default.addObserver(self, selector: #selector(queryUpdated), name: .NSMetadataQueryDidFinishGathering, object: query)
            DispatchQueue.main.async { self.query.start() }
        }
    }
    deinit { NSFileCoordinator.removeFilePresenter(self); query.stop() }
    func presentedItemDidChange() { changed() }
    @objc private func queryUpdated() {
        if let url = presentedItemURL { try? FileManager.default.startDownloadingUbiquitousItem(at: url) }
        changed()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.changed() }
    }
}

// MARK: - This device only (never synced): reminder, badge

struct DeviceSettings: Codable, Equatable {
    /// The daily reminder rings on this device at this time ("20:00").
    var reminderOn = false
    var reminderTime = "20:00"
    /// Show the number of habits still open today on the app icon.
    var badge = false
    /// The reminder was switched off because notifications were turned off in iPhone Settings.
    var lostPermission = false

    private static let key = "deviceSettings"
    static func load(from defaults: UserDefaults = .standard) -> DeviceSettings {
        guard let raw = defaults.data(forKey: key), let s = try? JSONDecoder().decode(DeviceSettings.self, from: raw) else { return DeviceSettings() }
        return s
    }
    func save(to defaults: UserDefaults = .standard) {
        if let raw = try? JSONEncoder().encode(self) { defaults.set(raw, forKey: DeviceSettings.key) }
    }
}
