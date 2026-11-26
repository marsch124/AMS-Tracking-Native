import Foundation

/// Days as the web app keys them: local "YYYY-MM-DD"; weeks start on Monday (Monday = 0 … Sunday = 6).
enum DayKey {
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale.current
        c.timeZone = TimeZone.current
        c.firstWeekday = 2
        return c
    }()

    /// Tests and screen pictures can pin "now" (launch argument `-now 2026-11-26T09:30`).
    static var pinnedNow: Date? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-now"), i + 1 < args.count else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.date(from: args[i + 1])
    }()
    static var now: Date { pinnedNow ?? Date() }

    static func key(_ d: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    static func today() -> String { key(now) }

    /// Local midnight of that day.
    static func date(_ key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    static func add(_ d: Date, days n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: d) ?? d }
    static func add(_ key: String, days n: Int) -> String { date(key).map { Self.key(add($0, days: n)) } ?? key }

    /// Monday = 0 … Sunday = 6.
    static func weekday(_ d: Date) -> Int { (calendar.component(.weekday, from: d) + 5) % 7 }
    static func weekday(_ key: String) -> Int { date(key).map(weekday) ?? 0 }

    /// The Monday of that day's week, at midnight.
    static func weekStart(_ d: Date) -> Date { add(calendar.startOfDay(for: d), days: -weekday(d)) }
    static func weekStartKey(_ key: String) -> String { date(key).map { Self.key(weekStart($0)) } ?? key }

    static func startOfDay(_ d: Date) -> Date { calendar.startOfDay(for: d) }

    static let letters = ["M", "T", "W", "T", "F", "S", "S"]
    static let shortNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let longNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    /// Every key from `a` to `b`, both included (a ≤ b), at most `limit`.
    static func keys(from a: String, to b: String, limit: Int = 4000) -> [String] {
        guard var d = date(a), let end = date(b) else { return [] }
        var out: [String] = []
        while d <= end && out.count < limit { out.append(key(d)); d = add(d, days: 1) }
        return out
    }
}

/// Times and lengths, the web app's way.
enum Fmt {
    /// "h:mm" — hours not padded, may pass 24 ("16:05").
    static func duration(_ ms: Double) -> String {
        let total = Int(max(0, ms) / 60000)
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
    /// 24-hour clock "HH:MM".
    static func clock(_ d: Date) -> String {
        let c = DayKey.calendar.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
    static func clock(ms: Double) -> String { clock(Date(timeIntervalSince1970: ms / 1000)) }
    /// "16" or "15.5" — a goal in hours.
    static func hours(_ g: Double) -> String {
        g == g.rounded() ? String(Int(g)) : String(format: "%.1f", g)
    }
    /// "26 Nov" (device language for the month).
    static func dayMonth(_ d: Date) -> String {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("d MMM"); return f.string(from: d)
    }
    /// "26 November".
    static func dayMonthLong(_ d: Date) -> String {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("d MMMM"); return f.string(from: d)
    }
    /// "Thu, 26 Nov".
    static func weekdayDayMonth(_ d: Date) -> String {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEE d MMM"); return f.string(from: d)
    }
    /// "November 2026".
    static func monthYear(_ d: Date) -> String {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMMM yyyy"); return f.string(from: d)
    }
    /// "1 day" / "3 days".
    static func count(_ n: Int, _ one: String, _ many: String? = nil) -> String {
        "\(n) " + (n == 1 ? one : (many ?? one + "s"))
    }
}
