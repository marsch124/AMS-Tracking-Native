import Foundation

// The data, in the SAME shape as the web app's `amsTracking.v1` (see docs/spec/01-data.md), so a backup
// from the web app imports here and a backup from here imports there. Three things are added for iCloud:
// every habit and aspiration carries `mt` (last change, ms) and, once removed, `deletedAt` (ms) — so two
// devices can be merged record by record — and the root carries `order`/`orderMt`, `format` and `savedAt`.
// Fields this app does not know are kept (`extra`) and written back unchanged.

// MARK: - Any JSON value (keeps unknown fields through a save)

enum JSONValue: Codable, Equatable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    /// Truthy the way JavaScript reads it (1, true, a non-empty string or any array/object).
    var isTruthy: Bool {
        switch self {
        case .null: false
        case .bool(let b): b
        case .number(let n): n != 0 && !n.isNaN
        case .string(let s): !s.isEmpty
        case .array, .object: true
        }
    }
    var number: Double? { if case .number(let n) = self { return n }; return nil }
    var string: String? { if case .string(let s) = self { return s }; return nil }
}

struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

/// Reads one key leniently: a wrong type or a missing key gives the fallback, never a failed import.
extension KeyedDecodingContainer where K == AnyKey {
    func get<T: Decodable>(_ key: String, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: AnyKey(key))) ?? fallback
    }
    func number(_ key: String) -> Double? {
        guard let v = try? decodeIfPresent(JSONValue.self, forKey: AnyKey(key)) else { return nil }
        if case .number(let n) = v, n.isFinite { return n }
        if case .string(let s) = v, let n = Double(s.replacingOccurrences(of: ",", with: ".")), n.isFinite { return n }
        return nil
    }
    func extras(known: Set<String>) -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for k in allKeys where !known.contains(k.stringValue) {
            if let v = try? decode(JSONValue.self, forKey: k) { out[k.stringValue] = v }
        }
        return out
    }
}

// MARK: - A habit

enum HabitType: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, timer
    var id: String { rawValue }
}

/// What a day holds for a check-off habit: done (`1` in the file — for a habit in parts: every part)
/// or the parts done that day (`[0, 2]`). An empty list is never stored: the day is removed instead.
enum DayMark: Equatable {
    case all
    case parts([Int])
}

/// One fast. Times are milliseconds since 1970, like the web app. `e == nil` = running.
/// `g` = an old per-fast goal in hours (no screen writes it since web 1.46, but old data keeps it and it still counts).
struct Session: Equatable, Hashable {
    var s: Double
    var e: Double?
    var g: Double?
    var extra: [String: JSONValue] = [:]

    var start: Date { Date(timeIntervalSince1970: s / 1000) }
    var end: Date? { e.map { Date(timeIntervalSince1970: $0 / 1000) } }
    var isRunning: Bool { e == nil }
    func hash(into h: inout Hasher) { h.combine(s); h.combine(e) }
}

struct Habit: Identifiable, Equatable {
    var id: String
    var name: String
    var icon: String
    var color: String
    var type: HabitType
    /// Scheduled weekdays, Monday first. Read only for daily habits.
    var days: [Bool]
    /// Weekly target (times a week). Read only for weekly habits; nil/0 counts as 1.
    var target: Int?
    var goalHours: Double?
    /// Per-weekday goal (Monday first), for the day a fast ENDS on. nil = none set.
    var goalByDay: [Double?]?
    var createdAt: String?
    var done: [String: DayMark]
    var skip: Set<String>
    var notes: [String: String]
    var sessions: [Session]
    var archived: Bool
    var aspirationId: String?
    var lastCelebrated: String?
    /// iCloud: when this habit last changed (ms) and when it was removed (ms, nil = alive).
    var mt: Double
    var deletedAt: Double?
    var extra: [String: JSONValue]

    init(id: String = newID(), name: String, icon: String = "meditate", color: String = "#3b70f0", type: HabitType = .daily,
         days: [Bool] = Array(repeating: true, count: 7), target: Int? = nil, goalHours: Double? = nil,
         goalByDay: [Double?]? = nil, createdAt: String? = DayKey.today(), done: [String: DayMark] = [:],
         skip: Set<String> = [], notes: [String: String] = [:], sessions: [Session] = [], archived: Bool = false,
         aspirationId: String? = nil, lastCelebrated: String? = nil, mt: Double = nowMs(), deletedAt: Double? = nil,
         extra: [String: JSONValue] = [:]) {
        self.id = id; self.name = name; self.icon = icon; self.color = color; self.type = type; self.days = days
        self.target = target; self.goalHours = goalHours; self.goalByDay = goalByDay; self.createdAt = createdAt
        self.done = done; self.skip = skip; self.notes = notes; self.sessions = sessions; self.archived = archived
        self.aspirationId = aspirationId; self.lastCelebrated = lastCelebrated; self.mt = mt; self.deletedAt = deletedAt
        self.extra = extra
    }

    var isRemoved: Bool { deletedAt != nil }
    /// The first-start habit Martin asked for in the web app: one fasting habit.
    static func firstStart() -> Habit {
        Habit(name: "Intermittent Fasting", icon: "moon", color: "#7a5af8", type: .timer, goalHours: 16)
    }
}

// MARK: - An aspiration ("Strong and durable into my seventies")

struct Aspiration: Identifiable, Equatable {
    var id: String
    var title: String
    var createdAt: String?
    var archivedAt: String?
    var mt: Double
    var deletedAt: Double?
    var extra: [String: JSONValue]

    init(id: String = newID(), title: String, createdAt: String? = DayKey.today(), archivedAt: String? = nil,
         mt: Double = nowMs(), deletedAt: Double? = nil, extra: [String: JSONValue] = [:]) {
        self.id = id; self.title = title; self.createdAt = createdAt; self.archivedAt = archivedAt
        self.mt = mt; self.deletedAt = deletedAt; self.extra = extra
    }
    var isLive: Bool { archivedAt == nil && deletedAt == nil }
}

// MARK: - Settings shared by every device (the web app's `settings`)

struct SharedSettings: Equatable {
    var layout: String = "list"      // "list" | "grid"
    var theme: String = "auto"       // "auto" | "light" | "dark"
    var lastBackup: Double?
    /// "quiet:<aspId>" | "empty:<aspId>" | "loose" → day key of the Monday of the week the nudge was last shown.
    var aspNudges: [String: String] = [:]
    var mt: Double = 0
    /// Everything else the web app keeps here (badge, reminder, lastBackupNudge …) — kept, not used for sync.
    var extra: [String: JSONValue] = [:]
}

// MARK: - The whole file

struct TrackingData: Equatable {
    /// Format of THIS app's file. A newer app may raise it; an older one then holds its writes.
    static let currentFormat = 1
    var format = TrackingData.currentFormat
    var version: Int? = 1
    var habits: [Habit] = []
    var aspirations: [Aspiration] = []
    var settings = SharedSettings()
    /// Habit order (ids) and when it last changed — so a reorder on one device reaches the others.
    var orderMt: Double = 0
    var savedAt: Double = 0
    var extra: [String: JSONValue] = [:]

    var liveHabits: [Habit] { habits.filter { !$0.isRemoved } }
    /// What Today, Stats and the reviews show: alive and not archived, in order.
    var activeHabits: [Habit] { habits.filter { !$0.isRemoved && !$0.archived } }
    var archivedHabits: [Habit] { habits.filter { !$0.isRemoved && $0.archived } }
    var liveAspirations: [Aspiration] { aspirations.filter(\.isLive) }
    func habit(_ id: String) -> Habit? { habits.first { $0.id == id && !$0.isRemoved } }
    /// Siri, the icon menu and `?fast=` act on the first fasting habit that is not archived.
    var fastingHabit: Habit? { activeHabits.first { $0.type == .timer } }

    /// The web app's very first start: one fasting habit.
    static func firstStart() -> TrackingData {
        var d = TrackingData()
        d.habits = [Habit.firstStart()]
        return d
    }
}

func nowMs() -> Double { (Date().timeIntervalSince1970 * 1000).rounded() }

/// "h" + base-36 time + 5 random base-36 characters, like the web app's ids.
func newID() -> String {
    let t = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
    let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    return "h" + t + String((0..<5).map { _ in chars.randomElement()! })
}

// MARK: - Reading and writing JSON

extension DayMark {
    /// `1`, `true` → all; a list of numbers → those parts (empty → nothing). Anything else → nothing.
    static func read(_ v: JSONValue) -> DayMark? {
        switch v {
        case .array(let a):
            let idx = a.compactMap { $0.number }.map { Int($0) }
            return idx.isEmpty ? nil : .parts(Array(Set(idx)).sorted())
        default:
            return v.isTruthy ? .all : nil
        }
    }
    var json: JSONValue {
        switch self {
        case .all: .number(1)
        case .parts(let p): .array(p.map { .number(Double($0)) })
        }
    }
}

extension Session: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        guard let s = c.number("s") else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "fast without a start"))
        }
        self.s = s
        e = c.number("e")
        g = c.number("g").flatMap { $0 > 0 ? $0 : nil }
        extra = c.extras(known: ["s", "e", "g"])
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        for (k, v) in extra { try c.encode(v, forKey: AnyKey(k)) }
        try c.encode(s, forKey: AnyKey("s"))
        if let e { try c.encode(e, forKey: AnyKey("e")) } else { try c.encodeNil(forKey: AnyKey("e")) }
        if let g { try c.encode(g, forKey: AnyKey("g")) }
    }
}

/// Lets an import skip one broken fast instead of failing the whole file.
private struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

extension Habit: Codable {
    static let knownKeys: Set<String> = ["id", "name", "icon", "color", "type", "days", "target", "goalHours", "goalByDay",
                                         "createdAt", "done", "skip", "notes", "sessions", "archived", "aspirationId",
                                         "lastCelebrated", "mt", "deletedAt"]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = c.get("id", "")
        if id.isEmpty { id = newID() }
        name = c.get("name", "Habit").trimmingCharacters(in: .whitespaces)
        if name.isEmpty { name = "Habit" }
        icon = c.get("icon", "sun")
        color = c.get("color", "#3b70f0")
        type = HabitType(rawValue: c.get("type", "daily")) ?? .daily
        let d: [Bool] = c.get("days", [])
        days = d.count == 7 && d.contains(true) ? d : Array(repeating: true, count: 7)
        target = c.number("target").map { Int($0) }
        goalHours = c.number("goalHours").flatMap { $0 > 0 ? $0 : nil }
        if let raw: [JSONValue] = try? c.decodeIfPresent([JSONValue].self, forKey: AnyKey("goalByDay")) {
            let g: [Double?] = (0..<7).map { i in
                guard i < raw.count, let n = raw[i].number, n > 0, n.isFinite else { return nil }
                return n
            }
            goalByDay = g.contains { $0 != nil } ? g : nil
        } else { goalByDay = nil }
        createdAt = c.get("createdAt", String?.none)
        let rawDone: [String: JSONValue] = c.get("done", [:])
        done = rawDone.compactMapValues { DayMark.read($0) }
        let rawSkip: [String: JSONValue] = c.get("skip", [:])
        skip = Set(rawSkip.filter { $0.value.isTruthy }.keys)
        let rawNotes: [String: JSONValue] = c.get("notes", [:])
        notes = rawNotes.compactMapValues { $0.string }.filter { !$0.value.isEmpty }
        let rawSessions: [Lenient<Session>] = c.get("sessions", [])
        sessions = rawSessions.compactMap(\.value).sorted { $0.s < $1.s }
        archived = c.get("archived", false)
        aspirationId = c.get("aspirationId", String?.none)
        lastCelebrated = c.get("lastCelebrated", String?.none)
        mt = c.number("mt") ?? 0
        deletedAt = c.number("deletedAt")
        extra = c.extras(known: Habit.knownKeys)
        Habit.migrate(&self)
    }

    /// The web app's `migrate()` for one habit: emoji icons from very old versions become drawings;
    /// an unknown icon becomes the sun.
    static func migrate(_ h: inout Habit) {
        if let mapped = TrackIcons.emoji[h.icon] { h.icon = mapped }
        else if TrackIcons.strokes[h.icon] == nil { h.icon = "sun" }
    }

    func encode(to encoder: Encoder) throws { try encode(to: encoder, sync: true) }

    /// `sync: false` = the plain web-app shape (for a backup another app reads): no `mt`/`deletedAt`.
    func encode(to encoder: Encoder, sync: Bool) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        for (k, v) in extra { try c.encode(v, forKey: AnyKey(k)) }
        try c.encode(id, forKey: AnyKey("id"))
        try c.encode(name, forKey: AnyKey("name"))
        try c.encode(icon, forKey: AnyKey("icon"))
        try c.encode(color, forKey: AnyKey("color"))
        try c.encode(type.rawValue, forKey: AnyKey("type"))
        try c.encode(days, forKey: AnyKey("days"))
        if let target { try c.encode(target, forKey: AnyKey("target")) } else { try c.encodeNil(forKey: AnyKey("target")) }
        if let goalHours { try c.encode(goalHours, forKey: AnyKey("goalHours")) } else { try c.encodeNil(forKey: AnyKey("goalHours")) }
        if let goalByDay { try c.encode(goalByDay, forKey: AnyKey("goalByDay")) } else { try c.encodeNil(forKey: AnyKey("goalByDay")) }
        if let createdAt { try c.encode(createdAt, forKey: AnyKey("createdAt")) }
        try c.encode(done.mapValues(\.json), forKey: AnyKey("done"))
        if !skip.isEmpty { try c.encode(Dictionary(uniqueKeysWithValues: skip.map { ($0, 1) }), forKey: AnyKey("skip")) }
        if !notes.isEmpty { try c.encode(notes, forKey: AnyKey("notes")) }
        try c.encode(sessions, forKey: AnyKey("sessions"))
        if archived { try c.encode(true, forKey: AnyKey("archived")) }
        if let aspirationId { try c.encode(aspirationId, forKey: AnyKey("aspirationId")) }
        if let lastCelebrated { try c.encode(lastCelebrated, forKey: AnyKey("lastCelebrated")) }
        if sync {
            try c.encode(mt, forKey: AnyKey("mt"))
            if let deletedAt { try c.encode(deletedAt, forKey: AnyKey("deletedAt")) }
        }
    }
}

extension Aspiration: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = c.get("id", "")
        if id.isEmpty { id = newID() }
        title = c.get("title", "")
        createdAt = c.get("createdAt", String?.none)
        archivedAt = c.get("archivedAt", String?.none)
        mt = c.number("mt") ?? 0
        deletedAt = c.number("deletedAt")
        extra = c.extras(known: ["id", "title", "createdAt", "archivedAt", "mt", "deletedAt"])
    }
    func encode(to encoder: Encoder) throws { try encode(to: encoder, sync: true) }
    func encode(to encoder: Encoder, sync: Bool) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        for (k, v) in extra { try c.encode(v, forKey: AnyKey(k)) }
        try c.encode(id, forKey: AnyKey("id"))
        try c.encode(title, forKey: AnyKey("title"))
        if let createdAt { try c.encode(createdAt, forKey: AnyKey("createdAt")) }
        if let archivedAt { try c.encode(archivedAt, forKey: AnyKey("archivedAt")) }
        if sync {
            try c.encode(mt, forKey: AnyKey("mt"))
            if let deletedAt { try c.encode(deletedAt, forKey: AnyKey("deletedAt")) }
        }
    }
}

extension SharedSettings: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        layout = c.get("layout", "list")
        if layout != "grid" { layout = "list" }
        theme = c.get("theme", "auto")
        if !["auto", "light", "dark"].contains(theme) { theme = "auto" }
        lastBackup = c.number("lastBackup")
        aspNudges = c.get("aspNudges", [:])
        mt = c.number("mt") ?? 0
        extra = c.extras(known: ["layout", "theme", "lastBackup", "aspNudges", "mt"])
    }
    func encode(to encoder: Encoder) throws { try encode(to: encoder, sync: true) }
    func encode(to encoder: Encoder, sync: Bool) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        for (k, v) in extra { try c.encode(v, forKey: AnyKey(k)) }
        try c.encode(layout, forKey: AnyKey("layout"))
        try c.encode(theme, forKey: AnyKey("theme"))
        if let lastBackup { try c.encode(lastBackup, forKey: AnyKey("lastBackup")) }
        if !aspNudges.isEmpty { try c.encode(aspNudges, forKey: AnyKey("aspNudges")) }
        if sync { try c.encode(mt, forKey: AnyKey("mt")) }
    }
}

extension TrackingData: Codable {
    /// The web app accepts any JSON with a `habits` list; so does this one. Everything else is optional.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        guard c.contains(AnyKey("habits")) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Not an AMS Tracking backup"))
        }
        let raw: [Lenient<Habit>] = (try? c.decode([Lenient<Habit>].self, forKey: AnyKey("habits"))) ?? []
        habits = raw.compactMap(\.value)
        // Two habits with one id (never written by either app, but a hand-made file could) keep the first.
        var seen = Set<String>()
        habits = habits.filter { seen.insert($0.id).inserted }
        let rawAsp: [Lenient<Aspiration>] = c.get("aspirations", [])
        aspirations = rawAsp.compactMap(\.value)
        settings = c.get("settings", SharedSettings())
        format = Int(c.number("format") ?? 1)
        version = c.number("version").map { Int($0) }
        orderMt = c.number("orderMt") ?? 0
        savedAt = c.number("savedAt") ?? 0
        extra = c.extras(known: ["habits", "aspirations", "settings", "format", "version", "orderMt", "savedAt"])
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        for (k, v) in extra { try c.encode(v, forKey: AnyKey(k)) }
        try c.encode(format, forKey: AnyKey("format"))
        if let version { try c.encode(version, forKey: AnyKey("version")) }
        try c.encode(habits, forKey: AnyKey("habits"))
        try c.encode(aspirations, forKey: AnyKey("aspirations"))
        try c.encode(settings, forKey: AnyKey("settings"))
        try c.encode(orderMt, forKey: AnyKey("orderMt"))
        try c.encode(savedAt, forKey: AnyKey("savedAt"))
    }

    /// A backup in the web app's own shape (`ams-tracking-backup-YYYY-MM-DD.json`): removed records left out,
    /// no iCloud bookkeeping. The web app's Import backup reads it as it is.
    func backupJSON() throws -> Data {
        var obj: [String: JSONValue] = extra
        obj["version"] = .number(Double(version ?? 1))
        obj["habits"] = .array(try liveHabits.map { h in try JSONValue.encoded { e in try h.encode(to: e, sync: false) } })
        obj["aspirations"] = .array(try aspirations.filter { $0.deletedAt == nil }.map { a in
            try JSONValue.encoded { e in try a.encode(to: e, sync: false) } })
        obj["settings"] = try JSONValue.encoded { e in try settings.encode(to: e, sync: false) }
        return try JSONEncoder.pretty.encode(obj)
    }
}

extension JSONValue {
    /// Runs an encode function and returns what it wrote, as a JSONValue.
    static func encoded(_ write: @escaping (Encoder) throws -> Void) throws -> JSONValue {
        struct Box: Encodable { let write: (Encoder) throws -> Void; func encode(to e: Encoder) throws { try write(e) } }
        let data = try JSONEncoder().encode(Box(write: write))
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

extension JSONEncoder {
    static let pretty: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e }()
}

// MARK: - Merging two copies (iCloud: newest change per record wins)

extension TrackingData {
    static func merged(_ a: TrackingData, _ b: TrackingData) -> TrackingData {
        var out = a
        out.habits = mergeRecords(a.habits, b.habits, id: \.id, mt: \.mt)
        out.aspirations = mergeRecords(a.aspirations, b.aspirations, id: \.id, mt: \.mt)
        out.settings = b.settings.mt > a.settings.mt ? b.settings : a.settings
        // Order: the copy whose order changed last decides; records it does not know keep their place after.
        if b.orderMt > a.orderMt {
            let rank = Dictionary(uniqueKeysWithValues: b.habits.enumerated().map { ($1.id, $0) })
            out.habits = out.habits.enumerated().sorted { x, y in
                (rank[x.element.id] ?? 100_000 + x.offset) < (rank[y.element.id] ?? 100_000 + y.offset)
            }.map(\.element)
            out.orderMt = b.orderMt
        }
        out.savedAt = max(a.savedAt, b.savedAt)
        out.format = max(a.format, b.format)
        return out
    }
}

func mergeRecords<T>(_ a: [T], _ b: [T], id: KeyPath<T, String>, mt: KeyPath<T, Double>) -> [T] {
    var byID: [String: T] = [:]
    var order: [String] = []
    for r in a { if byID[r[keyPath: id]] == nil { order.append(r[keyPath: id]) }; byID[r[keyPath: id]] = r }
    for r in b {
        let k = r[keyPath: id]
        if let have = byID[k] { if r[keyPath: mt] > have[keyPath: mt] { byID[k] = r } }
        else { byID[k] = r; order.append(k) }
    }
    return order.compactMap { byID[$0] }
}
