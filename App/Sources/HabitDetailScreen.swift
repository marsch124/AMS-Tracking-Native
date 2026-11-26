import SwiftUI

/// A habit's page (Lane A): calendar, year grid, fasting stages, fasts, poster.
struct HabitDetailScreen: View {
    let habitID: String
    @EnvironmentObject var store: Store
    var body: some View {
        Page(id: "screen-detail") {
            if let h = store.data.habit(habitID) { PageTitle(title: h.name, icon: h.icon, iconColor: Color(hex: h.color)) }
        }
    }
}
