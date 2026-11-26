import Foundation

/// Export CSV for Excel (rules 8.1): two files, semicolons, decimal commas (DACH Excel), no BOM,
/// lines joined with "\n", no trailing newline.
enum CSVExport {
    /// A value wrapped in quotes when it holds a quote, a semicolon or a line break (quotes doubled).
    static func field(_ v: String) -> String {
        if v.contains("\"") || v.contains(";") || v.contains("\n") || v.contains("\r") {
            return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return v
    }

    static func fileName(_ kind: String, day: String = DayKey.today()) -> String { "ams-tracking-\(kind)-\(day).csv" }

    /// date;habit;type;status;parts;note — every habit (archived too), every day with a mark or a note.
    static func daysCSV(_ habits: [Habit]) -> String {
        var lines = ["date;habit;type;status;parts;note"]
        for h in habits {
            let doneKeys = h.doneKeys
            let keys = doneKeys.union(h.skip).union(h.notes.keys).sorted()
            for k in keys {
                let isDone = doneKeys.contains(k)
                let status = isDone ? "done" : (h.skip.contains(k) ? "skip" : "")
                var partsText = ""
                if isDone, h.type != .timer, let names = h.parts {
                    partsText = h.doneParts(k).filter { $0 < names.count }.map { names[$0] }.joined(separator: ", ")
                }
                lines.append([k, field(h.name), h.type.rawValue, status, field(partsText), field(h.notes[k] ?? "")].joined(separator: ";"))
            }
        }
        return lines.joined(separator: "\n")
    }

    /// habit;start;end;hours — every finished fast; the hours with a decimal comma ("16,25").
    static func fastsCSV(_ habits: [Habit]) -> String {
        var lines = ["habit;start;end;hours"]
        for h in habits {
            for s in h.sessions {
                guard let e = s.e else { continue }
                let hours = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), (e - s.s) / 3_600_000)
                    .replacingOccurrences(of: ".", with: ",")
                lines.append([field(h.name), stamp(s.s), stamp(e), hours].joined(separator: ";"))
            }
        }
        return lines.joined(separator: "\n")
    }

    /// "YYYY-MM-DD HH:mm" in local time.
    static func stamp(_ ms: Double) -> String {
        let d = Date(timeIntervalSince1970: ms / 1000)
        return DayKey.key(d) + " " + Fmt.clock(d)
    }
}
