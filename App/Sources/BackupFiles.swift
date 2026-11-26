import SwiftUI
import UniformTypeIdentifiers

/// The JSON backup as a file the system's save panel (iPhone, iPad and Mac) can write.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// One CSV file for the share sheet (written to a temp file under its own name when shared).
struct CSVFile: Transferable {
    let name: String
    let text: String
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { f in
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent(f.name)
            try Data(f.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

enum BackupFiles {
    static func fileName(day: String = DayKey.today()) -> String { "ams-tracking-backup-\(day).json" }

    /// What a web backup says about its daily reminder (`settings.reminder`): on or off, and the time.
    static func reminder(in data: TrackingData) -> (on: Bool, time: String)? {
        guard case .object(let r)? = data.settings.extra["reminder"] else { return nil }
        let on = r["on"]?.isTruthy ?? false
        let time = r["time"]?.string ?? "20:00"
        return (on, time.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil ? time : "20:00")
    }

    static func lastBackupText(_ ms: Double?, now: Double = nowMs()) -> String {
        guard let ms else { return "No backup file yet" }
        let days = Int((now - ms) / 86_400_000)
        return days <= 0 ? "Last backup file: today" : days == 1 ? "Last backup file: yesterday" : "Last backup file: \(days) days ago"
    }
}
