import SwiftUI

// Last week's analysis (web `renderNotes` 3858): the week that just ended — chart, headline, one row per habit,
// the week in words (sent as text or as a picture), aspirations, how it went, what to try, something new.

struct LastWeekScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    /// Aspiration nudges this screen has shown — they stay on screen while it is open, then rest for four weeks.
    @State private var shown: Set<String> = []
    @State private var posterURL: URL?

    var body: some View {
        let ins = Insights(data: store.data, forcedNudges: shown)
        let ws = ins.ws
        let report = WeekReport.make(store.data, ws: ws)
        let paras = ins.summaryParagraphs(report: report)
        let cover = ins.coverage(ws)
        let past = ins.lastWeekNotes()
        let notes = ins.weekNotes()
        let picks = ins.suggestions(3)
        let range = Self.range(ws)

        Page(id: "screen-lastweek") {
            PageTitle(title: "Last week’s analysis", subtitle: range)

            if !report.rows.isEmpty {
                BarChartCard(heading: "Habits completed each day", values: report.perDay, ceiling: report.ceiling,
                             labels: DayKey.letters, caption: report.chartCaption, id: "lw-chart")
                HeroCard(report: report)
            }

            SectionHeading(title: "The week in words")
            if paras.isEmpty {
                EmptyNote(text: store.data.activeHabits.isEmpty
                          ? "Nothing to summarise yet. Add a habit and give it a week."
                          : "Nothing to summarise yet. Everything you track began during or after last week, so there is no complete week to report on — there will be on Monday.",
                          id: "summary-empty")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(paras.indices, id: \.self) { i in
                        Text(paras[i]).font(.callout).lineSpacing(4).foregroundStyle(Ink.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 14).padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Ink.surface).shadow(color: Ink.shadow, radius: 5, y: 2))
                .accessibilityIdentifier("summary-box")

                ShareLink(item: ins.summaryText(report: report)) { OutlineLabel(icon: "export", text: "Send this summary as text") }
                    .buttonStyle(.plain).accessibilityIdentifier("share-text")
                Group {
                    if let posterURL {
                        ShareLink(item: posterURL) { OutlineLabel(icon: "export", text: "Send the week as a picture") }
                            .buttonStyle(.plain)
                    } else {
                        OutlineLabel(icon: "export", text: "Send the week as a picture").opacity(0.5)
                    }
                }
                .accessibilityIdentifier("share-picture")
            }

            if !cover.isEmpty {
                SectionHeading(title: "Your aspirations")
                ForEach(cover) { c in
                    Button { nav.open(.aspirations) } label: {
                        NoteCard {
                            HStack(spacing: 8) {
                                Text(c.asp.title).font(.subheadline.weight(.heavy)).foregroundStyle(Ink.text)
                                Text(c.total > 0 ? "\(c.ran)/\(c.total)" : "—").font(.subheadline.weight(.heavy)).foregroundStyle(Ink.dim)
                                Spacer(minLength: 0)
                            }
                            Text(Self.coverLine(c)).font(.footnote).foregroundStyle(Ink.dim)
                            if c.quiet >= 3 {
                                Text("Quiet for \(c.quiet) weeks. Is it still true?").font(.footnote.weight(.bold)).foregroundStyle(Ink.stale)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lw-asp-\(c.asp.id)")
                }
            }

            if !past.isEmpty {
                SectionHeading(title: "How it went")
                ForEach(past) { n in
                    Button { nav.open(habit: n.habit.id) } label: {
                        NoteCard {
                            HStack(spacing: 8) {
                                TrackIcon(name: n.habit.icon, size: 18, color: Color(hex: n.habit.color))
                                Text(n.habit.name).font(.subheadline.weight(.heavy)).foregroundStyle(Ink.text)
                            }
                            Text(n.text).font(.subheadline).foregroundStyle(Ink.text)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("went-\(n.habit.id)")
                }
            }

            SectionHeading(title: "What to try next week",
                           hint: "Read from your own data. Every note names the figure it came from, so you can disagree with it.")
            if notes.isEmpty {
                EmptyNote(text: "Nothing worth saying yet. A weekday pattern needs a few weeks before it is a pattern rather than a coincidence, and a confident sentence about a coincidence would be worse than this one.",
                          id: "notes-empty")
            } else {
                ForEach(Array(notes.enumerated()), id: \.element.id) { i, n in
                    Button {
                        if n.aspiration != nil { nav.open(.aspirations) }
                        else if let h = n.habit { nav.open(habit: h.id) }
                    } label: {
                        NoteCard {
                            HStack(alignment: .top, spacing: 8) {
                                if let h = n.habit { TrackIcon(name: h.icon, size: 18, color: Color(hex: h.color)) }
                                else { TrackIcon(name: "mountain", size: 18, color: Ink.dim) }
                                Text(n.title).font(.subheadline.weight(.heavy)).foregroundStyle(Ink.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Text(n.body).font(.subheadline).foregroundStyle(Ink.dim)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("try-\(i)")
                }
            }

            if !picks.isEmpty {
                SectionHeading(title: "Something new?", hint: "Only ideas. Nothing here is added until you add it.")
                ForEach(Array(picks.enumerated()), id: \.element.id) { i, sg in
                    NoteCard {
                        HStack(spacing: 8) {
                            TrackIcon(name: sg.icon, size: 18, color: Ink.accent)
                            Text(sg.name).font(.subheadline.weight(.heavy)).foregroundStyle(Ink.text)
                            Text(sg.kind).font(.footnote.weight(.bold)).foregroundStyle(Ink.dim)
                            Spacer(minLength: 0)
                        }
                        Text(sg.why).font(.subheadline).foregroundStyle(Ink.dim)
                        Button { nav.sheet = .addHabit(prefill: sg.prefill) } label: {
                            OutlineLabel(icon: "plus", text: "Add this habit", compact: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .accessibilityIdentifier("suggest-add-\(i)")
                    }
                    .accessibilityIdentifier("suggest-\(i)")
                }
            }
        }
        .reviewChrome("Last week")
        .onAppear { markNudges() }
        .task(id: report.signature) { posterURL = report.rows.isEmpty ? nil : WeekPoster.render(report) }
    }

    /// Opening the screen is what "seen" means: the aspiration notes on show start their four weeks of rest.
    private func markNudges() {
        let keys = Insights.nudgeKeys(of: Insights(data: store.data, forcedNudges: shown).weekNotes())
        guard !keys.isEmpty else { return }
        shown.formUnion(keys)
        let monday = DayKey.weekStartKey(DayKey.today())
        guard keys.contains(where: { store.data.settings.aspNudges[$0] != monday }) else { return }
        store.updateSettings { s in for k in keys { s.aspNudges[k] = monday } }
    }

    static func range(_ ws: String) -> String {
        guard let a = DayKey.date(ws), let b = DayKey.date(DayKey.add(ws, days: 6)) else { return "" }
        return Fmt.dayMonth(a) + " – " + Fmt.dayMonth(b)
    }

    static func coverLine(_ c: AspirationCover) -> String {
        guard c.total > 0 else { return "No habits under this yet." }
        var s = "\(c.ran) of \(c.total) habit\(c.total == 1 ? "" : "s") ran last week"
        if c.judged > 0 { s += ", \(c.met) of \(c.judged) did what \(c.judged == 1 ? "it" : "they") asked" }
        return s + "."
    }
}

/// An outlined accent button face with a small icon (the web's wr-cta).
struct OutlineLabel: View {
    let icon: String
    let text: String
    var compact = false
    var body: some View {
        HStack(spacing: 8) {
            TrackIcon(name: icon, size: 16, color: Ink.accent)
            Text(text).font(.subheadline.weight(.bold)).foregroundStyle(Ink.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 8 : 11)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.accent, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

/// The headline and one row per habit.
private struct HeroCard: View {
    let report: WeekReport
    @EnvironmentObject var nav: Nav
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(report.headFigure).font(.largeTitle.weight(.heavy)).foregroundStyle(report.allMet ? Ink.green : Ink.text)
                Text(report.headLabel).font(.subheadline.weight(.semibold)).foregroundStyle(Ink.dim)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 6)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("lw-headline")
            ForEach(report.rows) { r in
                Button { nav.open(habit: r.habit.id) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        ReviewRowTop(habit: r.habit, mid: r.mid, met: r.met == true, delta: r.delta, trend: r.trend, flame: r.deltaValue != nil)
                        WeekMarks(row: r)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { Rectangle().fill(Ink.border).frame(height: 1) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("lw-row-\(r.habit.id)")
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Ink.surface).shadow(color: Ink.shadow, radius: 5, y: 2))
    }
}
