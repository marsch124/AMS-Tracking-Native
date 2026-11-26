import Foundation
import SwiftUI
import AppIntents
import UserNotifications
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// Start / Stop Fasting from Siri, Shortcuts and the Home Screen icon menu (web 1.51, now native):
// they change the data directly — no hand-over queue any more — and Siri answers without opening the app.
// Plus what follows every save: the icon menu item, the badge and the daily reminder.

// MARK: - Siri and Shortcuts

@MainActor
enum SiriFasting {
    static let noHabit = "Tracking has no fasting habit."

    static func start() -> String {
        let store = Store.shared
        store.load()
        guard let h = store.data.fastingHabit else { return noHabit }
        let now = nowMs()
        if let a = h.activeSession {
            return "You are already fasting, since \(Fmt.clock(ms: a.s)) — \(spoken(now - a.s))."
        }
        store.startFast(h.id, at: now, message: nil)
        store.saveNow()
        var words = "Fast started at \(Fmt.clock(ms: now))."
        if let goal = store.data.habit(h.id)?.goalMs(for: Session(s: now, e: nil)) {
            words += " Goal \(Fmt.hours(goal / 3_600_000)) h, until \(Fmt.clock(ms: now + goal))."
        }
        return words
    }

    static func stop() -> String {
        let store = Store.shared
        store.load()
        guard let h = store.data.fastingHabit else { return noHabit }
        guard let a = h.activeSession else { return "No fast is running." }
        let now = nowMs()
        let goal = h.goalMs(for: a)
        store.endFast(h.id, at: now, message: nil)
        store.saveNow()
        var words = "Fast ended after \(spoken(now - a.s))."
        if let goal {
            words += now - a.s >= goal ? " Goal of \(Fmt.hours(goal / 3_600_000)) h met." : " Goal was \(Fmt.hours(goal / 3_600_000)) h."
        }
        return words
    }

    /// "16 h 5 min", "45 min", "3 h".
    static func spoken(_ ms: Double) -> String {
        let min = max(0, Int(ms / 60000))
        let h = min / 60, m = min % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }
}

struct StartFastingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Fasting"
    static let description = IntentDescription("Starts a fast in Tracking now, without opening the app.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let words = SiriFasting.start()
        return .result(dialog: "\(words)")
    }
}

struct StopFastingIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Fasting"
    static let description = IntentDescription("Ends the running fast in Tracking now, without opening the app.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let words = SiriFasting.stop()
        return .result(dialog: "\(words)")
    }
}

/// Apple requires the app name in every phrase. "Hey Siri, start fasting" alone works through a shortcut
/// of his own named "Start Fasting" (the tip in How it works).
struct TrackingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartFastingIntent(), phrases: [
            "Start fasting in \(.applicationName)",
            "Start a fast in \(.applicationName)",
            "Start my fast in \(.applicationName)",
            "Start fasting with \(.applicationName)",
            "\(.applicationName) start fasting",
        ], shortTitle: "Start Fasting", systemImageName: "moon")
        AppShortcut(intent: StopFastingIntent(), phrases: [
            "Stop fasting in \(.applicationName)",
            "End my fast in \(.applicationName)",
            "Stop my fast in \(.applicationName)",
            "Stop fasting with \(.applicationName)",
            "\(.applicationName) stop fasting",
        ], shortTitle: "Stop Fasting", systemImageName: "fork.knife")
    }
    static let shortcutTileColor: ShortcutTileColor = .purple
}

// MARK: - The Home Screen icon menu (long-press the icon)

enum QuickActions {
    static let startItem = "ams.fast.start"
    static let stopItem = "ams.fast.stop"
    /// A tap on the menu item that launched the app, applied once the window is there.
    @MainActor static var pending: String?

    #if os(iOS)
    @MainActor
    static func refresh(_ data: TrackingData) {
        let items: [UIApplicationShortcutItem]
        if let h = data.fastingHabit {
            if let a = h.activeSession {
                items = [UIApplicationShortcutItem(type: stopItem, localizedTitle: "Stop Fasting",
                                                   localizedSubtitle: "Since \(Fmt.clock(ms: a.s))",
                                                   icon: UIApplicationShortcutIcon(templateImageName: "QuickStop"), userInfo: nil)]
            } else {
                items = [UIApplicationShortcutItem(type: startItem, localizedTitle: "Start Fasting", localizedSubtitle: nil,
                                                   icon: UIApplicationShortcutIcon(templateImageName: "QuickStart"), userInfo: nil)]
            }
        } else { items = [] }
        UIApplication.shared.shortcutItems = items
    }
    #endif

    @MainActor
    static func handle(_ type: String) {
        switch type {
        case startItem: Store.shared.applyFastAction("start", at: nil, source: "menu")
        case stopItem: Store.shared.applyFastAction("stop", at: nil, source: "menu")
        default: break
        }
    }

    /// Steps Siri or the menu left in the earlier Tracking app (1.51) while it was closed — applied once.
    @MainActor
    static func takeShellSteps() {
        let key = "ams.fasting.pending"
        struct Step: Codable { var a: String; var t: Double; var src: String }
        guard let raw = UserDefaults.standard.data(forKey: key),
              let steps = try? JSONDecoder().decode([Step].self, from: raw) else { return }
        UserDefaults.standard.removeObject(forKey: key)
        for s in steps.sorted(by: { $0.t < $1.t }) { Store.shared.applyFastAction(s.a, at: s.t, source: s.src) }
    }
}

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem { MainActor.assumeIsolated { QuickActions.pending = item.type } }
        let c = UISceneConfiguration(name: nil, sessionRole: session.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        MainActor.assumeIsolated { QuickActions.handle(shortcutItem.type) }
        completionHandler(true)
    }
}
#endif

// MARK: - Badge and daily reminder (this device)

@MainActor
enum SideEffects {
    private static var planWork: Task<Void, Never>?

    static func refresh(_ store: Store) {
        #if os(iOS)
        QuickActions.refresh(store.data)
        #endif
        let data = store.data
        let device = store.device
        planWork?.cancel()
        planWork = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await updateBadge(data, device)
            await planReminders(data, device, store: store)
        }
    }

    /// Habits still open today: scheduled, neither done nor skipped, and not a fast that is running.
    static func openToday(_ data: TrackingData, day: Date = DayKey.now) -> [Habit] {
        let k = DayKey.key(day)
        let isToday = k == DayKey.today()
        return data.activeHabits.filter { h in
            guard h.isScheduled(k), !h.isDone(k), !h.skip.contains(k) else { return false }
            if isToday && h.type == .timer && h.activeSession != nil { return false }
            return true
        }
    }

    static func updateBadge(_ data: TrackingData, _ device: DeviceSettings) async {
        let n = device.badge ? openToday(data).count : 0
        #if os(iOS)
        let allowed = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
        try? await UNUserNotificationCenter.current().setBadgeCount(allowed ? n : 0)
        #else
        NSApp?.dockTile.badgeLabel = n > 0 ? String(n) : nil
        #endif
    }

    /// "2 still open: Intermittent Fasting, Reading" — the next 30 days at the chosen time,
    /// a day with nothing open is left out.
    static func reminderBody(_ open: [Habit]) -> String {
        switch open.count {
        case 0: return "Time to fill in your tracked items."
        case 1: return "Still open: \(open[0].displayName)"
        default: return "\(open.count) still open: " + open.map(\.displayName).joined(separator: ", ")
        }
    }

    static let ids = (0..<30).map { "ams.reminder.\($0)" }

    static func planReminders(_ data: TrackingData, _ device: DeviceSettings, store: Store) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard device.reminderOn else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else {
            if status == .denied { store.device.reminderOn = false; store.device.lostPermission = true }
            return
        }
        let parts = device.reminderTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let now = DayKey.now
        for i in 0..<30 {
            let day = DayKey.add(DayKey.startOfDay(now), days: i)
            guard let at = DayKey.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day),
                  at > now.addingTimeInterval(5) else { continue }
            let open = openToday(data, day: day)
            guard !open.isEmpty else { continue }
            let content = UNMutableNotificationContent()
            content.title = "AMS Tracking"
            content.body = reminderBody(open)
            content.sound = .default
            let comps = DayKey.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            let req = UNNotificationRequest(identifier: ids[i], content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            try? await center.add(req)
        }
    }

    /// Asks for notifications (reminder, badge). True when allowed.
    static func askPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let s = await center.notificationSettings().authorizationStatus
        if s == .authorized || s == .provisional { return true }
        if s == .denied { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
}
