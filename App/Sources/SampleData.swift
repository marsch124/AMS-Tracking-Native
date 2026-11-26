import Foundation

/// Made-up habits for screen tests and pictures (launch argument `-sample`). Never Martin's real data.
enum SampleData {
    static func make(today: Date = DayKey.now) -> TrackingData {
        let t = DayKey.key(today)
        func back(_ n: Int) -> String { DayKey.add(t, days: -n) }
        func doneDays(_ n: Int, every: Int = 1, miss: Set<Int> = []) -> [String: DayMark] {
            var d: [String: DayMark] = [:]
            for i in 1...n where i % every == 0 && !miss.contains(i) { d[back(i)] = .all }
            return d
        }
        // 40 finished fasts, 14–17 h, ending at about noon, plus one running since 9 h ago.
        var sessions: [Session] = []
        let cal = DayKey.calendar
        for i in stride(from: 40, through: 1, by: -1) {
            let day = DayKey.add(DayKey.startOfDay(today), days: -(i - 1))
            guard let end = cal.date(bySettingHour: 12, minute: (i * 7) % 60, second: 0, of: day) else { continue }
            let len = Double(14 + i % 4) * 3_600_000 + Double(i % 3) * 1_800_000
            let e = end.timeIntervalSince1970 * 1000
            if end < today.addingTimeInterval(-9 * 3600) { sessions.append(Session(s: e - len, e: e)) }
        }
        sessions.append(Session(s: today.addingTimeInterval(-9 * 3600 - 600).timeIntervalSince1970 * 1000, e: nil))

        var fasting = Habit(id: "h_fast", name: "Intermittent Fasting", icon: "moon", color: "#7a5af8", type: .timer,
                            goalHours: 16, goalByDay: [16, 16, 16, 16, 14, nil, nil], createdAt: back(60), sessions: sessions)
        fasting.notes[back(3)] = "Dinner with friends, ate late"
        var parts = Habit(id: "h_parts", name: "Medit | Brea | Cold", icon: "meditate", color: "#2fa96d", createdAt: back(60),
                          done: doneDays(30, miss: [6, 13]))
        parts.done[t] = .parts([0, 2])
        parts.skip = [back(6)]
        let workout = Habit(id: "h_work", name: "Workout", icon: "dumbbell", color: "#d9463e", type: .weekly, target: 3,
                            createdAt: back(60), done: doneDays(40, every: 2))
        var reading = Habit(id: "h_read", name: "Reading", icon: "book", color: "#3b70f0", createdAt: back(60),
                            done: doneDays(25, miss: [3, 9]), aspirationId: "a_strong")
        reading.notes[t] = "Finished chapter 4"
        let sugar = Habit(id: "h_sugar", name: "No sugar", icon: "leaf", color: "#ee8b2c",
                          days: [true, true, true, true, true, false, false], createdAt: back(60), done: doneDays(12))
        var d = TrackingData()
        d.habits = [fasting, parts, workout, reading, sugar]
        d.habits[2].aspirationId = "a_strong"
        d.aspirations = [Aspiration(id: "a_strong", title: "Strong and durable into my seventies", createdAt: back(30))]
        return d
    }
}
