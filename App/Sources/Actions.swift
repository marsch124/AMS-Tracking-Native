import Foundation

// What the taps, swipes, Siri and the icon menu DO — the web app's toggleToday, togglePart, markYesterday,
// swipeDone, swipeSkip, startFast, endFast and applyFastAction, with the same messages and the same Undo.

extension Store {
    private var today: String { DayKey.today() }

    // MARK: Check-off habits

    /// The big circle: today done ⇄ not done (a skip mark on today goes). Silent, like the web app.
    func toggleToday(_ id: String) {
        guard let h = data.habit(id) else { return }
        let k = today
        let becomesDone = h.done[k] == nil
        update(id) { h in
            h.skip.remove(k)
            if becomesDone { h.done[k] = .all } else { h.done[k] = nil }
        }
        if becomesDone { maybeCelebrateStreak(id) }
    }

    /// One part of "Medit | Brea | Cold" for today.
    func togglePart(_ id: String, _ idx: Int) {
        guard let h = data.habit(id) else { return }
        let k = today
        let before = h.doneParts(k)
        let on = before.contains(idx)
        let after = on ? before.filter { $0 != idx } : (before + [idx]).sorted()
        let snapshot = h
        update(id) { h in
            h.skip.remove(k)
            h.done[k] = after.isEmpty ? nil : .parts(after)
        }
        if before.isEmpty && !after.isEmpty { maybeCelebrateStreak(id) }
        let name = h.parts.map { idx < $0.count ? $0[idx] : "Part" } ?? "Part"
        showToast("\(name) \(on ? "cleared" : "done")") { [weak self] in self?.restore(snapshot) }
    }

    /// Press and hold the circle: yesterday done (never celebrates).
    func markYesterday(_ id: String) {
        guard let h = data.habit(id) else { return }
        let y = DayKey.add(today, days: -1)
        if h.done[y] != nil { showToast("Yesterday is already done"); return }
        let snapshot = h
        update(id) { h in h.skip.remove(y); h.done[y] = .all }
        showToast("Yesterday marked done") { [weak self] in self?.restore(snapshot) }
    }

    /// Swipe right. Returns false when the fasting card wants the record-hours sheet instead.
    @discardableResult
    func swipeDone(_ id: String) -> Bool {
        guard let h = data.habit(id) else { return true }
        let k = today
        if h.type == .timer {
            if h.activeSession != nil { toggleFast(id); return true }
            if h.isDone(k) { showToast("Already done today"); return true }
            return false
        }
        if let parts = h.parts {
            let before = h.doneParts(k)
            if before.count >= parts.count { showToast("Already done today"); return true }
            let snapshot = h
            update(id) { h in h.skip.remove(k); h.done[k] = .all }
            if before.isEmpty { maybeCelebrateStreak(id) }
            showToast("All parts marked done") { [weak self] in self?.restore(snapshot) }
            return true
        }
        if h.done[k] != nil { showToast("Already done today"); return true }
        let snapshot = h
        update(id) { h in h.skip.remove(k); h.done[k] = .all }
        maybeCelebrateStreak(id)
        showToast("Marked done") { [weak self] in self?.restore(snapshot) }
        return true
    }

    /// Swipe left: today becomes a skip day.
    func swipeSkip(_ id: String) {
        guard let h = data.habit(id) else { return }
        let k = today
        if h.isDone(k) { showToast("Already done today — nothing to skip"); return }
        if h.skip.contains(k) { showToast("Today is already a skip day"); return }
        if h.type == .timer && h.activeSession != nil { showToast("A fast is running — stop it first"); return }
        let snapshot = h
        update(id) { $0.skip.insert(k) }
        showToast("Today marked as skip day") { [weak self] in self?.restore(snapshot) }
    }

    /// Milestones fire once each, only from a live check-off.
    func maybeCelebrateStreak(_ id: String) {
        guard let h = data.habit(id), h.type != .timer else { return }
        let weekly = h.type == .weekly
        let value = weekly ? h.weeklyStreak(today: today) : h.currentStreak(today: today)
        guard (weekly ? Milestones.weeks : Milestones.days).contains(value) else { return }
        let tag = (weekly ? "week" : "day") + String(value)
        guard h.lastCelebrated != tag else { return }
        update(id) { $0.lastCelebrated = tag }
        celebrate("\(value)-\(weekly ? "week" : "day") streak!", sub: h.displayName, colorHex: h.color)
    }

    // MARK: Fasting

    /// The fasting card's round button: start now, or end the running fast now.
    func toggleFast(_ id: String) {
        guard let h = data.habit(id) else { return }
        if h.activeSession != nil { endFast(id, at: nil, message: nil) } else { startFast(id, at: nil, message: nil) }
    }

    func startFast(_ id: String, at: Double?, message: String?) {
        let t = at ?? nowMs()
        update(id) { $0.sessions.append(Session(s: t, e: nil)) }
        showToast(message ?? "Fast started") { [weak self] in
            self?.update(id) { h in h.sessions.removeAll { $0.s == t && $0.e == nil } }
        }
    }

    func endFast(_ id: String, at: Double?, message: String?) {
        guard let h = data.habit(id), let i = h.activeIndex else { return }
        let t = at ?? nowMs()
        let start = h.sessions[i].s
        let others = h.finishedSessions
        update(id) { h in if let j = h.sessions.firstIndex(where: { $0.s == start && $0.e == nil }) { h.sessions[j].e = t } }
        let len = t - start
        showToast(message ?? "Fast ended — \(Fmt.duration(len)) h") { [weak self] in
            self?.update(id) { h in if let j = h.sessions.firstIndex(where: { $0.s == start && $0.e == t }) { h.sessions[j].e = nil } }
        }
        let best = others.map { ($0.e ?? $0.s) - $0.s }.max() ?? 0
        if others.count >= 3 && len > best {
            celebrate("Personal best fast!", sub: "\(Fmt.duration(len)) h · \(h.displayName)", colorHex: h.color)
        }
    }

    /// Siri, the icon menu and old `?fast=` links. `bySiri` = asked while the app was closed (more than a
    /// minute ago): no "ignored" messages, and the message names Siri's own time.
    @discardableResult
    func applyFastAction(_ action: String, at: Double?, source: String) -> Bool {
        let now = nowMs()
        let t = min(at ?? now, now)
        let bySiri = source == "siri" && now - t > 60_000
        guard let h = data.fastingHabit else {
            if !bySiri { showToast("No fasting habit found") }
            return false
        }
        var action = action
        if action == "toggle" { action = h.activeSession != nil ? "stop" : "start" }
        switch action {
        case "start":
            if let a = h.activeSession {
                if !bySiri { showToast("Already fasting — \(Fmt.duration(now - a.s)) h") }
                return false
            }
            startFast(h.id, at: t, message: bySiri ? "Siri: fast started at \(Fmt.clock(ms: t))" : nil)
            return true
        case "stop":
            guard let a = h.activeSession, t > a.s else {
                if !bySiri { showToast("No fast is running") }
                return false
            }
            endFast(h.id, at: t, message: bySiri ? "Siri: fast ended at \(Fmt.clock(ms: t)) — \(Fmt.duration(t - a.s)) h" : nil)
            return true
        default:
            return false
        }
    }
}
