import Foundation

/// Import fasting history (rules 8.2): the parser, the preview and the save step — pure functions.
enum HistoryImport {
    struct Fast: Equatable { var s: Double; var e: Double }
    struct Parsed: Equatable { var fasts: [Fast] = []; var bad = 0 }
    struct Preview: Equatable { var fresh: [Fast] = []; var dupes = 0; var bad = 0 }

    static let maxMs = 48.0 * 3_600_000

    private static func match(_ pattern: String, _ s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).compactMap { i in Range(m.range(at: i), in: s).map { String(s[$0]) } }
    }

    /// JavaScript's parseFloat: the number at the start of the text, the rest ignored.
    static func parseFloat(_ s: String) -> Double? {
        guard let m = match(#"^\s*([+-]?(?:\d+\.?\d*|\.\d+))"#, s) else { return nil }
        return Double(m[1])
    }

    /// "2026-08-15 19:00" or "2026-08-15T19:00:00" → local time in ms; anything else → nil.
    static func dateTime(_ v: String) -> Double? {
        guard let m = match(#"^(\d{4})-(\d{2})-(\d{2})[ T](\d{1,2}):(\d{2})"#, v), m.count == 6 else { return nil }
        let n = m.dropFirst().compactMap { Int($0) }
        guard n.count == 5, (1...12).contains(n[1]), (1...31).contains(n[2]), n[3] < 24, n[4] < 60,
              let d = DayKey.calendar.date(from: DateComponents(year: n[0], month: n[1], day: n[2], hour: n[3], minute: n[4])) else { return nil }
        return d.timeIntervalSince1970 * 1000
    }

    static func noon(of key: String) -> Double? {
        guard let d = DayKey.date(key), let n = DayKey.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: d) else { return nil }
        return n.timeIntervalSince1970 * 1000
    }

    static func parse(_ text: String, now: Date = DayKey.now) -> Parsed {
        var out = Parsed()
        let nowMs = now.timeIntervalSince1970 * 1000
        for raw in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if let first = line.first, !first.isNumber, line.range(of: "date|start|habit|hours", options: [.regularExpression, .caseInsensitive]) != nil { continue }
            let sep: Character = line.contains(";") ? ";" : (line.contains("\t") ? "\t" : ",")
            var parts = line.split(separator: sep, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !line.contains(";"), !line.contains("\t"), parts.count == 3,
               match(#"^\d{1,2}$"#, parts[1]) != nil, match(#"^\d{1,2}$"#, parts[2]) != nil {
                parts = [parts[0], parts[1] + "." + parts[2]]
            }
            var found: Fast?
            if parts.count >= 3, let s = dateTime(parts[1]), let e = dateTime(parts[2]) { found = Fast(s: s, e: e) }
            else if parts.count >= 2, let s = dateTime(parts[0]), let e = dateTime(parts[1]) { found = Fast(s: s, e: e) }
            else if parts.count >= 2, match(#"^\d{4}-\d{2}-\d{2}$"#, parts[0]) != nil,
                    let h = parseFloat(parts[1].replacingOccurrences(of: ",", with: ".")), h.isFinite, h > 0, h <= 48,
                    let e = noon(of: parts[0]) {
                found = Fast(s: e - h * 3_600_000, e: e)
            }
            if let f = found, f.e > f.s, f.e - f.s <= maxMs, f.e <= nowMs { out.fasts.append(f) } else { out.bad += 1 }
        }
        return out
    }

    static func endDay(_ f: Fast) -> String { DayKey.key(Date(timeIntervalSince1970: f.e / 1000)) }

    /// New fasts = those whose end day has no fast yet in the habit.
    static func preview(_ text: String, existingEndDays: Set<String>, now: Date = DayKey.now) -> Preview {
        let p = parse(text, now: now)
        let fresh = p.fasts.filter { !existingEndDays.contains(endDay($0)) }
        return Preview(fresh: fresh, dupes: p.fasts.count - fresh.count, bad: p.bad)
    }

    /// One fast per end day: the first of each.
    static func toSave(_ fresh: [Fast]) -> [Fast] {
        var seen = Set<String>()
        return fresh.filter { seen.insert(endDay($0)).inserted }
    }

    /// "Found 2 new fasts · 1 already recorded · 1 unreadable line." — empty text shows nothing.
    static func message(_ p: Preview, empty: Bool) -> String {
        if empty { return "" }
        var m = "Found " + Fmt.count(p.fresh.count, "new fast")
        if p.dupes > 0 { m += " · \(p.dupes) already recorded" }
        if p.bad > 0 { m += " · " + Fmt.count(p.bad, "unreadable line") }
        return m + "."
    }
}

/// What the habit form reads from the weekday goal fields: "15,5" → 15.5; empty, zero, over 48 → nothing.
enum GoalInput {
    static func parse(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), v.isFinite, v > 0, v <= 48 else { return nil }
        return v
    }
    /// Seven fields (Monday first) → the per-weekday goals, or nil when all are empty.
    static func byDay(_ fields: [String]) -> [Double?]? {
        let g = (0..<7).map { $0 < fields.count ? parse(fields[$0]) : nil }
        return g.contains { $0 != nil } ? g : nil
    }
}
