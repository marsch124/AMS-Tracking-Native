import SwiftUI

/// Settings (Lane C).
struct SettingsScreen: View {
    var body: some View { Page(id: "screen-settings") { PageTitle(title: "Settings"); Text("Version \(AppInfo.version)").accessibilityIdentifier("app-version") } }
}
