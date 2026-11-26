import Foundation

/// Test runs only (-uiTesting): open a part, a habit or a sheet straight away, so the Mac and iPad can be
/// photographed page by page without clicks (tools/mac-pictures.sh).  -section stats  -habit h_fast  -sheet add|settings
@MainActor
enum PictureArgs {
    static func apply(_ nav: Nav) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uiTesting") else { return }
        func value(_ key: String) -> String? {
            guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        if let s = value("-section"), let section = AppSection(rawValue: s) { nav.open(section) }
        if let h = value("-habit") { nav.open(habit: h) }
        switch value("-sheet") {
        case "add": nav.sheet = .addHabit(prefill: nil)
        case "settings": nav.sheet = .settings
        case "edit": if let h = value("-habit") { nav.sheet = .editHabit(h) }
        default: break
        }
    }
}
