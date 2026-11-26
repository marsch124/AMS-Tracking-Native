import SwiftUI

// The small sheets about one day or one fast. Opened from Today and from a habit's page.
// (Lane A fills these in: record-hours, edit-fast, parts, day note, skip several days.)

enum DaySheet: Identifiable, Hashable {
    case note(habit: String, day: String)
    case hours(habit: String, day: String)
    case editFast(habit: String, start: Double)
    case parts(habit: String, day: String)
    case skipRange(habit: String)
    var id: String {
        switch self {
        case .note(let h, let d): "note-\(h)-\(d)"
        case .hours(let h, let d): "hours-\(h)-\(d)"
        case .editFast(let h, let s): "fast-\(h)-\(s)"
        case .parts(let h, let d): "parts-\(h)-\(d)"
        case .skipRange(let h): "skip-\(h)"
        }
    }
}

extension View {
    func daySheets(_ sheet: Binding<DaySheet?>) -> some View {
        modifier(DaySheetsModifier(sheet: sheet))
    }
}

private struct DaySheetsModifier: ViewModifier {
    @Binding var sheet: DaySheet?
    @EnvironmentObject var store: Store
    func body(content: Content) -> some View {
        content.sheet(item: $sheet) { s in
            Group {
                switch s {
                case .note(let h, let d): DayNoteSheet(habitID: h, day: d)
                case .hours(let h, let d): RecordHoursSheet(habitID: h, day: d)
                case .editFast(let h, let start): EditFastSheet(habitID: h, start: start)
                case .parts(let h, let d): PartsSheet(habitID: h, day: d)
                case .skipRange(let h): SkipRangeSheet(habitID: h)
                }
            }
            .environmentObject(store)
        }
    }
}

struct DayNoteSheet: View { let habitID: String; let day: String; var body: some View { Text("Note") } }
struct RecordHoursSheet: View { let habitID: String; let day: String; var body: some View { Text("Hours") } }
struct EditFastSheet: View { let habitID: String; let start: Double; var body: some View { Text("Edit fast") } }
struct PartsSheet: View { let habitID: String; let day: String; var body: some View { Text("Parts") } }
struct SkipRangeSheet: View { let habitID: String; var body: some View { Text("Skip several days") } }
