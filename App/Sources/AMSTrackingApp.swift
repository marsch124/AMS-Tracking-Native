import SwiftUI

@main
struct AMSTrackingApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @StateObject private var store = Store.shared

    var body: some Scene {
        // Nothing may be added to the view directly inside WindowGroup: macOS remembers windows by that
        // view's TYPE, and a changed type opens the Mac app with no window (Steward, 23 Nov 2026).
        WindowGroup {
            AppRoot(store: store)
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Habit") { NotificationCenter.default.post(name: .newHabit, object: nil) }
                    .keyboardShortcut("n")
            }
        }
        #endif
    }
}

/// The one view inside WindowGroup — everything else goes in here.
struct AppRoot: View {
    @ObservedObject var store: Store
    var body: some View {
        RootView()
            .environmentObject(store)
            #if os(macOS)
            .frame(minWidth: 900, minHeight: 600)
            #endif
    }
}

extension Notification.Name {
    static let newHabit = Notification.Name("AMSTrackingNewHabit")
}
