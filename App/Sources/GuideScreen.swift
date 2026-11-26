import SwiftUI

/// Settings › How it works — the whole app in topics you open one at a time, ending in "Signs in this app" (Lane D).
/// The words are the web app's guide, rewritten for the native app 2.0 (iPhone, iPad, Mac, iCloud).
struct GuideItem: Identifiable {
    let lead: String
    let text: String
    var id: String { lead }
}

struct GuideTopic: Identifiable {
    let id: String
    let icon: String
    let title: String
    let items: [GuideItem]
}

struct GuideScreen: View {
    @State private var open: Set<String> = []

    var body: some View {
        Page(id: "screen-guide") {
            PageTitle(title: "How it works", subtitle: "Tap a topic to open it")
            ForEach(GuideContent.topics) { t in topic(t) }
            signsTopic
        }
    }

    private func header(icon: String, title: String, id: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if open.contains(id) { open.remove(id) } else { open.insert(id) }
            }
        } label: {
            HStack(spacing: 10) {
                TrackIcon(name: icon, size: 22, color: Ink.accent)
                Text(title).font(.headline.weight(.bold)).foregroundStyle(Ink.text)
                Spacer(minLength: 0)
                Text(open.contains(id) ? "Hide" : "Show").font(.footnote.weight(.semibold)).foregroundStyle(Ink.accent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id == "signs" ? "signs" : "topic-\(id)")
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Ink.surface))
    }

    private func topic(_ t: GuideTopic) -> some View {
        card {
            header(icon: t.icon, title: t.title, id: t.id)
            if open.contains(t.id) {
                ForEach(t.items) { item in
                    (Text(item.lead).fontWeight(.bold) + Text(" — ") + Text(item.text))
                        .font(.subheadline).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Signs in this app

    private var signsTopic: some View {
        card {
            header(icon: "help", title: "Signs in this app", id: "signs")
            if open.contains("signs") {
                Text("Every mark and colour that means something, and what it means. A mark or colour keeps the same meaning everywhere.")
                    .font(.subheadline).foregroundStyle(Ink.dim)
                ForEach(SignList.groups) { g in
                    Text(g.title).font(.footnote.weight(.heavy)).foregroundStyle(Ink.dim).textCase(.uppercase).padding(.top, 6)
                    ForEach(g.rows) { r in
                        HStack(alignment: .top, spacing: 12) {
                            r.mark.frame(width: 38, height: 26)
                            (Text(r.name).fontWeight(.bold) + Text(" — ") + Text(r.meaning))
                                .font(.subheadline).foregroundStyle(Ink.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - The marks

struct SignRow: Identifiable {
    let name: String
    let meaning: String
    let mark: AnyView
    var id: String { name }
}

struct SignGroup: Identifiable {
    let title: String
    let rows: [SignRow]
    var id: String { title }
}

private func icon(_ n: String, _ c: Color = Ink.text) -> AnyView { AnyView(TrackIcon(name: n, size: 22, color: c)) }
private func dot(_ c: Color, size: CGFloat = 14, filled: Bool = true, dashed: Bool = false) -> AnyView {
    AnyView(Group {
        if filled { Circle().fill(c) }
        else if dashed { Circle().strokeBorder(c, style: StrokeStyle(lineWidth: 1.6, dash: [3, 2.5])) }
        else { Circle().strokeBorder(c, lineWidth: 2) }
    }.frame(width: size, height: size))
}
private func ring(_ c: Color) -> AnyView { AnyView(Circle().strokeBorder(c, lineWidth: 3.5).frame(width: 22, height: 22)) }
private func word(_ t: String, _ c: Color = Ink.text) -> AnyView {
    AnyView(Text(t).font(.caption.weight(.bold)).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.6))
}
private func squares() -> AnyView {
    AnyView(HStack(spacing: 2) {
        RoundedRectangle(cornerRadius: 2).fill(Ink.accent).frame(width: 7, height: 7)
        RoundedRectangle(cornerRadius: 2).fill(Ink.accent.opacity(0.25)).frame(width: 7, height: 7)
        RoundedRectangle(cornerRadius: 2).strokeBorder(Ink.accent, style: StrokeStyle(lineWidth: 1, dash: [2, 1.5])).frame(width: 7, height: 7)
        RoundedRectangle(cornerRadius: 2).fill(Ink.dim.opacity(0.12)).frame(width: 7, height: 7)
    })
}
private func badge() -> AnyView {
    AnyView(Text("3").font(.caption2.weight(.heavy)).foregroundStyle(.white)
        .frame(minWidth: 18, minHeight: 18).background(Circle().fill(Ink.danger)))
}
private func tick() -> AnyView {
    AnyView(Circle().fill(Ink.accent).frame(width: 22, height: 22)
        .overlay(TrackIcon(name: "check", size: 14, color: .white, lineWidth: 2.2)))
}
private func forkAndKnife() -> AnyView {
    AnyView(Image("QuickStop").renderingMode(.template).resizable().scaledToFit().frame(width: 20, height: 20).foregroundStyle(Ink.text))
}
private func dropOutline() -> AnyView {
    AnyView(RoundedRectangle(cornerRadius: 6).strokeBorder(Ink.accent, lineWidth: 2.5).frame(width: 34, height: 20))
}

enum SignList {
    static let groups: [SignGroup] = [
        SignGroup(title: "Today", rows: [
            SignRow(name: "Big circle with a tick", meaning: "the habit is done today. Tap again to undo.", mark: tick()),
            SignRow(name: "Plus (＋)", meaning: "add a new habit.", mark: icon("plus", Ink.accent)),
            SignRow(name: "Flame and a number", meaning: "your streak: days (or weeks) in a row.", mark: icon("flame", Ink.accent)),
            SignRow(name: "Week dots, M to S", meaning: "this week, Monday first. Filled = done, dimmed = not scheduled that day, dashed outline = skip day. Tap a dot to open that day in the calendar.", mark: dot(Ink.accent)),
            SignRow(name: "Skip day (hollow, dashed outline)", meaning: "an excused day. It neither breaks nor extends a streak. In the fasting calendar it is a dashed circle with a dash (–).", mark: dot(Ink.accent, filled: false, dashed: true)),
            SignRow(name: "Small dot next to a name", meaning: "today has a note. Tap it to read it. In the calendar, a small dot under a day also means a note.", mark: dot(Ink.accent, size: 8)),
            SignRow(name: "Pencil", meaning: "edit a habit, or turn on note mode in the calendar.", mark: icon("pencil")),
            SignRow(name: "Words under the floating bar (iPhone)", meaning: "the three buttons at the bottom of Today carry their words: Stats, Add, Settings — so no mark is left to guess.", mark: word("Stats")),
        ]),
        SignGroup(title: "Moving things", rows: [
            SignRow(name: "Blue outline around a card", meaning: "while you drag a card, the blue outline shows the card it will land on. Let go and it takes that place.", mark: dropOutline()),
            SignRow(name: "Ring while swiping a card", meaning: "grey: not far enough yet, let go and nothing happens. Green: far enough, let go and it fires. Right = done today, left = skip today.", mark: ring(Ink.green)),
            SignRow(name: "Drag handle (Settings, Reorder habits)", meaning: "hold and drag a row up or down to put it in order.", mark: icon("reorder")),
        ]),
        SignGroup(title: "Calendar and pixels", rows: [
            SignRow(name: "Pixel grid", meaning: "solid is a day done, pale is a day not done, dashed is a skip day, very faint is a day still to come. Tap one to see its date and note.", mark: squares()),
        ]),
        SignGroup(title: "Fasting", rows: [
            SignRow(name: "Fasting ring, red", meaning: "a fast is running and is still in the first third of its goal.", mark: ring(Ink.red)),
            SignRow(name: "Fasting ring, yellow", meaning: "the middle third of the goal.", mark: ring(Ink.amber)),
            SignRow(name: "Fasting ring, green", meaning: "nearing or past the goal.", mark: ring(Ink.green)),
            SignRow(name: "Fasting calendar circles", meaning: "green: the day's goal was met. Grey: the fast fell short. Red with a live count: today's fast is still running. Dashed with a dash: skip day.", mark: dot(Ink.green, size: 16)),
            SignRow(name: "Fasting stage colours", meaning: "red: Digestion, yellow: Settling in, light green: Fat burning, deep green: Deep fast.", mark: dot(Ink.chart, size: 16)),
            SignRow(name: "Small capital words under the fasting card", meaning: "they name what a spot does: the one under the button starts or stops, the middle one opens the stats, “edit” under the running timer fixes the start.", mark: word("EDIT", Ink.dim)),
            SignRow(name: "Moon (icon menu)", meaning: "“Start Fasting”: no fast is running.", mark: icon("moon", Ink.accent)),
            SignRow(name: "Fork and knife (icon menu)", meaning: "“Stop Fasting”: a fast is running; the line under it says since when.", mark: forkAndKnife()),
        ]),
        SignGroup(title: "iPad and Mac sidebar", rows: [
            SignRow(name: "Grid", meaning: "Today — your habit cards.", mark: icon("grid", Ink.accent)),
            SignRow(name: "Chart", meaning: "Stats — streaks, months and achievements.", mark: icon("chart", Ink.accent)),
            SignRow(name: "Light bulb", meaning: "Last week and Last month — the written look back.", mark: icon("bulb", Ink.accent)),
            SignRow(name: "Target", meaning: "Aspirations — who you are becoming.", mark: icon("target", Ink.accent)),
            SignRow(name: "Sliders", meaning: "Settings.", mark: icon("sliders", Ink.accent)),
        ]),
        SignGroup(title: "Colours and warnings", rows: [
            SignRow(name: "Amber text", meaning: "something is out of date or needs a look: iCloud is not in step, a fast running past 24 hours (“still fasting? tap timer to fix”), or an aspiration with nothing running under it.", mark: word("Amber", Ink.stale)),
            SignRow(name: "Number on the app icon", meaning: "scheduled habits still open today, if you switched it on in Settings. On this device only; on the Mac it is on the Dock icon.", mark: badge()),
            SignRow(name: "Red button text or red Delete", meaning: "it removes something for good. Undo bars and the blue word “Undo” take back the last step for a few seconds.", mark: word("Delete", Ink.danger)),
            SignRow(name: "Blue", meaning: "the colour of buttons and links. A habit's own colour always means that habit.", mark: dot(Ink.accent, size: 16)),
        ]),
    ]
}

// MARK: - The topics

enum GuideContent {
    static let topics: [GuideTopic] = [
        GuideTopic(id: "start", icon: "grid", title: "Your devices and the screens", items: [
            GuideItem(lead: "One app, three devices", text: "Tracking runs on iPhone, iPad and Mac with the same icon, and iCloud Drive keeps them in step."),
            GuideItem(lead: "iPhone", text: "Today is the home screen. It has no header: it starts with the first habit card, and each card shows its own state. The settings, stats and add buttons float at the bottom within thumb reach, each with its word under the mark (Stats, Add, Settings). Screens slide like native iOS: a habit's page and Stats push in from the right, going back slides home."),
            GuideItem(lead: "iPad and Mac", text: "Three columns side by side. Left, a sidebar with Today, Stats, Last week, Last month, Aspirations and Settings. In the middle, the part you picked. On the right, the page of the habit you tapped. Nothing needs a back button: tap another habit and the right column changes."),
            GuideItem(lead: "Text size", text: "The app follows the system's text size: make text larger or smaller there and every screen scales with it, icons and buttons included."),
            GuideItem(lead: "Gestures", text: "Swipe the month calendar left or right to change months, and drag any sheet downward to close it. On the Mac, Escape closes a sheet like Cancel, and ⌘N starts a new habit."),
        ]),
        GuideTopic(id: "daily", icon: "check", title: "Daily and weekly habits", items: [
            GuideItem(lead: "Daily habits", text: "tap the big circle on a card to check the habit off for today; tap again to undo. The flame shows your current streak: consecutive scheduled days completed. Today doesn't break the streak until it's over. A daily habit can be limited to certain weekdays."),
            GuideItem(lead: "Weekly-target habits", text: "for things like working out, where it's the count that matters, not the day: set a target such as 3× per week and check days off whenever they happen. The card leads with this week's count, “4/6” with “this week” under it, and turns green the moment you reach the target. Under that the flame counts weeks in which you hit the target; the running week never breaks that streak until it's over."),
            GuideItem(lead: "Forgot yesterday?", text: "press and hold the check circle of a daily or weekly habit to mark yesterday done, without opening the calendar. A short Undo bar confirms it, or tells you yesterday was already done. A normal tap still checks off today. On the Mac you can also right-click the card: Done today, Skip today, Yesterday done. Days filled in afterwards never trigger a milestone celebration."),
            GuideItem(lead: "Week dots", text: "the M to S dots show this week, Monday first. Filled dots are completed days, dimmed dots are days the habit isn't scheduled. Each dot is also a shortcut: tap one and the habit's calendar opens on that day, briefly flashing it."),
            GuideItem(lead: "Swipe to act", text: "on iPhone and iPad swipe a card to the right to mark the habit done for today (for fasting: it stops a running fast, or opens the record-hours sheet when none is running), or swipe left to excuse today as a skip day. A ring shows when the swipe is far enough to fire: grey not yet, green yes. Every swipe has the usual Undo bar. Days already done or skipped just tell you so."),
            GuideItem(lead: "Undo", text: "starting or ending a fast, marking days, and removing entries can be taken back for a few seconds with the Undo bar at the bottom, so a stray tap never costs you anything."),
        ]),
        GuideTopic(id: "parts", icon: "sliders", title: "Habits with several parts", items: [
            GuideItem(lead: "Several parts", text: "name a habit with vertical bars, like Medit | Brea | Cold, and the app tracks each part on its own. The number of taps on the big circle picks the part: one tap toggles the first part, two quick taps the second, three the third. While you tap, the part you're about to toggle lights up; a moment after your last tap it registers, and a bar confirms it (“Brea done”) with Undo. Two, three or four parts are supported."),
            GuideItem(lead: "Colours", text: "done parts are written in the habit's colour, the others stay grey, and the circle is checked as soon as any part is done — so streaks and week dots count the day as complete. You can also tap a part's word to toggle exactly that one, and swiping the card to the right marks all parts at once."),
            GuideItem(lead: "Parts on an earlier day", text: "press and hold the big circle of a multi-part habit and a small sheet opens for yesterday with one button per part: tick the ones you did and save. The same sheet opens when you tap any day in that habit's calendar; it opens with that day's parts already ticked. Saving with nothing ticked empties the day, and “Mark as skip day instead” excuses it. Every change shows an Undo bar."),
        ]),
        GuideTopic(id: "fasting", icon: "moon", title: "Fasting (start and stop habits)", items: [
            GuideItem(lead: "Start and stop", text: "the same button does both: tap it in the evening to start the fast, and tap it when you eat again. While fasting, the card shows the live elapsed time; after stopping, it counts the eating window and shows when it closes — “6:22 eating, until 19:01” means 19:01 is the moment to start the next fast to keep a steady rhythm (the window is 24 h minus your goal). Once that time passes it says “time to fast”. A fast counts for the day it ends on."),
            GuideItem(lead: "Goal and ring", text: "set a fasting goal when editing the habit, and if you like a different goal for certain weekdays (the goal belongs to the day a fast ends on, so Friday's number is for the fast you start Thursday evening; empty fields use the main goal). A ring fills around the button like a traffic light — red for the first third of the goal, yellow for the middle third, green for the home stretch — while the card counts down how long is left and shows the clock time at which you'll hit the goal (“2:30 left, goal 11:30”). Everything turns green when you reach it."),
            GuideItem(lead: "Still fasting?", text: "a fast running past 24 hours turns amber and asks “still fasting?” — tap the timer to fix a forgotten stop."),
            GuideItem(lead: "Editing a fast", text: "forgot to press start or stop on time? While fasting, tap the running timer number to correct the start time. All fasts can also be edited from the detail page's list: start, end, or delete. Nothing changes until you save."),
            GuideItem(lead: "The tap areas", text: "faint dashed lines on the fasting card mark its separate touch zones, with a tiny word under each: start (or stop) under the round button, stats under the middle, which opens the habit's details, and edit under the timer number on the right. Between fasts, edit opens your most recent fast."),
            GuideItem(lead: "Fasting stages", text: "the detail page shows the commonly cited phases on a coloured track: Digestion (0–4 h), Settling in (4–12 h), Fat burning (12–16 h) and Deep fast (16 h+). While a fast runs, a marker sits at your elapsed time and a line names the stage (“Now: Fat burning”). A popular approximation, not medical advice."),
            GuideItem(lead: "Fasting calendar and chart", text: "each day shows the fasted hours in a circle: green when the goal was met, grey when short, red with a live count for today's fast, dashed with a dash for skip days. A line under the calendar explains the circles. The detail page also charts recent fasts as bars against the dashed goal line; tap a bar to edit that fast."),
            GuideItem(lead: "Old history", text: "switching from another fasting app? Settings, Import fasting history accepts pasted rows (day + hours, or start + end times, or this app's own CSV), previews what it found, and adds them as fasts — days that already have a fast are left untouched, and the import can be undone."),
        ]),
        GuideTopic(id: "siri", icon: "play", title: "Siri, Shortcuts and the icon menu", items: [
            GuideItem(lead: "Which habit", text: "all of these act on your first fasting habit (the first start and stop habit in the list that is not archived)."),
            GuideItem(lead: "Press and hold the icon", text: "on iPhone and iPad the Home Screen menu shows one fasting entry, the one that fits right now: Start Fasting (a small moon) when no fast runs, or Stop Fasting (a small fork and knife) with the line “Since 20:13” while one runs. Tapping it changes the fast directly — at that moment, with no waiting until the app opens."),
            GuideItem(lead: "Siri", text: "nothing to set up. Say “Hey Siri, start fasting in Tracking” or “stop fasting in Tracking” (“start a fast in Tracking” and “end my fast in Tracking” work too). Siri changes your data directly and answers out loud without opening the app, for example “Fast started at 20:13. Goal 16 h, until 12:13.” or “Fast ended after 16 h 5 min. Goal of 16 h met.” Start while a fast runs: “You are already fasting, since 20:13.” Stop with none running: “No fast is running.”"),
            GuideItem(lead: "Shortcuts and Spotlight", text: "Start Fasting and Stop Fasting appear by themselves in the Shortcuts app under Tracking — put them in your own shortcuts, on the Action button, or find them in Spotlight. To say only “Hey Siri, start fasting”, add the Tracking action in Shortcuts and name the shortcut “Start Fasting” (the same for Stop Fasting)."),
            GuideItem(lead: "On the Mac", text: "Siri and Shortcuts work too, with the same two actions."),
            GuideItem(lead: "Open the app once", text: "if Siri says “Open Tracking once, then try again”, open the app one time after installing, and it will work from then on."),
        ]),
        GuideTopic(id: "calendar", icon: "pencil", title: "Calendar, notes and the past", items: [
            GuideItem(lead: "Details", text: "tap anywhere else on a card for the habit's page: the year-by-year pixel grid, current and longest streak, and completion %. Small letters mark where each month begins, and tapping any pixel shows that day's date, status and note. Timer habits also list recent fasts with average and longest duration."),
            GuideItem(lead: "Fixing the past", text: "in a habit's page the month calendar is editable. For daily and weekly habits, tapping a day cycles it: done, then skip day, then empty. (For a habit with several parts it opens the part sheet.) A skip day (hollow with a dashed outline) is excused — it neither breaks nor extends a streak and leaves the completion count. For fasting, tapping an empty day opens a small sheet to pick or type the hours (or mark a skip day); tapping a day with a recorded fast opens it in the editor."),
            GuideItem(lead: "Moving through months", text: "use the arrows to move through months — up to a year ahead, so a planned vacation is visible; future days are locked except vacation-marked skip days, which a tap un-marks. Once you've wandered off the current month, a target button in the calendar header jumps straight back to today."),
            GuideItem(lead: "Vacations and sick weeks", text: "under the month calendar, “Skip several days” marks a whole date range as skip days at once: pick the first and last day (future dates included, up to 92 days), and tick “Apply to all habits” when the whole life pauses. Days already done stay done, and Undo takes back exactly the days the range added."),
            GuideItem(lead: "Day notes", text: "tap the pencil in the calendar header to enter note mode, then tap any day to write a short note. Days with notes get a mark, and the month's notes are listed under the calendar. When today has a note, a small dot in the habit's colour appears next to the name on its card — tap the dot to read it."),
            GuideItem(lead: "Year poster", text: "the share button next to a year heading turns that year into a poster picture: the habit's icon and name, all 365 days as a month-by-month pixel grid in the habit's colour, and the year's headline stats. It opens the system share sheet, so it can go to Messages, Photos or anywhere else."),
        ]),
        GuideTopic(id: "review", icon: "bulb", title: "Last week and Last month", items: [
            GuideItem(lead: "Two permanent buttons", text: "Last week and Last month sit under your habits on Today (and in the sidebar on iPad and Mac); neither can be dismissed or lost. They are pure summary — nothing about your data changes."),
            GuideItem(lead: "Last week", text: "opens the week that ended, dated to that week. It starts with a chart of how many habits you completed on each day, Monday first, naming the day that carried the most. Then the week drawn — the headline count of habits on target, and one row per habit with its figure, its streak change, and its seven days as coloured squares: solid done, plain missed, dashed excused, dim not asked for. Tap a row to open that habit."),
            GuideItem(lead: "The written summary", text: "paragraphs on what happened, whether that was any good measured against your recent normal, what the last eight weeks show underneath it and what to do next week, and one habit idea. Send this summary as text hands the words to the share sheet; Send the week as a picture hands over the drawn report."),
            GuideItem(lead: "How it went, and what to try", text: "cards in each habit's colour, tappable through to that habit, then Something new? with three habit ideas. Last week says whether the week was good against your normal; What to try next week ignores any single week and reads eight of them for a pattern."),
            GuideItem(lead: "Last month", text: "the same idea for the month: a chart of the ticks in each week of it, then each habit's figure and its change on the month before."),
            GuideItem(lead: "How the notes are worked out", text: "there is no intelligence behind them and nothing is sent anywhere: the app does arithmetic on what is already on your devices and picks the sentences that fit. Every note names the figure it came from, and thresholds are set high on purpose: most notes need several weeks before they speak. It never calls a weekly target's rest days a slip, and never tells the same story twice about one habit."),
            GuideItem(lead: "Habit suggestions", text: "three at a time, rotating each week; anything close to something you already track is left out. Add this habit opens the new-habit sheet with the name, icon and target filled in — nothing is created until you press Save."),
            GuideItem(lead: "Sending the report", text: "Settings, Send last week's report does the picture whenever you want it. On iPhone and iPad it opens the share sheet; on the Mac it saves as a PNG."),
        ]),
        GuideTopic(id: "stats", icon: "chart", title: "Stats, milestones and aspirations", items: [
            GuideItem(lead: "Stats", text: "an overview of all habits: current and best streak, this month vs last month, and the last 30 days as a pixel strip per habit. When your current streak comes within 3 days (1 week for weekly habits) of your best, the card adds a line like “2 days to your record”. A fasting habit with at least five recorded fasts also gets a rhythm card: usual start time, strongest weekday, average fast, and a Mon–Sun chart of average hours per weekday."),
            GuideItem(lead: "Achievements", text: "at the top of Stats: earned streak milestones per habit, your longest fast, best streak, and total days tracked."),
            GuideItem(lead: "Milestones", text: "hitting a round streak (7, 14, 30, 50, 100 … days, or 4, 10, 26, 52 weeks) or setting a personal-best fast earns a short celebration. Each milestone fires once."),
            GuideItem(lead: "Aspirations", text: "one sentence about who you are becoming, such as “Strong and durable into my seventies”. No date and no number — the habits carry those — and no colour of its own, because colour means which habit. Habits are attached from either side: the aspiration's sheet asks Which habits serve it?, and editing a habit gains a Serves row once an aspiration exists. A habit attached to nothing works exactly as it always has."),
            GuideItem(lead: "Answered every week", text: "each aspiration is answered weekly: how many of its habits ran, on its own screen and in Last week. One silent for three weeks is asked about — “Is it still true?” The app mentions once, and not again for a month, that an aspiration has no habits or some habits serve nothing."),
            GuideItem(lead: "Starting one", text: "the sheet offers four sentences to start from; whichever you pick is yours to rewrite. Archiving an aspiration never touches its habits — they become unattached — and Undo puts it back."),
        ]),
        GuideTopic(id: "edit", icon: "plus", title: "Adding, editing, reordering", items: [
            GuideItem(lead: "Adding and editing", text: "＋ creates a habit with a name, icon, colour and type; the icon picker offers hand-drawn icons and a search field that understands English and German words (try “kaffee” or “sleep”). A live preview at the top shows the card exactly as it will look on Today. The pencil on a habit's page edits it. On the Mac, ⌘N starts a new habit and right-click on a card offers Edit."),
            GuideItem(lead: "Changing a habit's type later", text: "edit it and pick Daily check or Weekly target. Every day you have ticked stays as it is — both kinds record one mark per day and only read it differently. Going to a weekly target starts at the number of scheduled days; the streak then counts weeks that reached it. Start / Stop stays fixed: it keeps start and end times, which the other two have nowhere to put."),
            GuideItem(lead: "Drag to reorder", text: "press and hold a card (not the round button) until it lifts, then drag it onto another card; a blue outline shows where it lands. The new order is saved at once, with Undo, and reaches your other devices. Settings, Reorder habits has drag handles for precise moves. The press-and-hold shortcuts on the round button itself are untouched."),
            GuideItem(lead: "Layout and theme", text: "Settings, Layout switches between the list view and a two-column grid; Theme picks auto (follow the system), always light, or always dark."),
            GuideItem(lead: "Archiving", text: "done with a habit but want to keep its history? Archive it from its page: it disappears from Today but keeps everything, and can be restored any time from Settings, Archived habits. Deleting, by contrast, is for good."),
        ]),
        GuideTopic(id: "icloud", icon: "export", title: "iCloud, safety copies and backups", items: [
            GuideItem(lead: "One file in iCloud Drive", text: "all your habits live in one file in iCloud Drive, and every device reads and writes it. Changes are merged habit by habit: if two devices changed different habits, both changes stay; if both changed the same habit, the newest change wins. A habit you remove on one device is removed on the others too. The order of your habits is shared too. Turn on iCloud Drive for Tracking on every device; Settings shows where the data lives and whether it is in step."),
            GuideItem(lead: "Safety copies", text: "a safety copy is made by itself every day and the last 30 are kept. Each copy is read back and checked before it counts. A file the app cannot read is never written over: it is parked in the safety copies first. Because of this there is no “back up” reminder any more."),
            GuideItem(lead: "Export and Import backup", text: "Settings, Export backup (JSON) shares a file with everything; Import backup restores it, after asking before anything is replaced. The file has the same shape as the web app's, so a backup from the Safari web app imports here."),
            GuideItem(lead: "Moving in from the web app", text: "in the Safari web app: Settings, Export backup (JSON). Here: Settings, Import backup. If you had already imported into the TestFlight app 1.51, 2.0 takes those habits over by itself on its first start."),
            GuideItem(lead: "CSV for Excel", text: "“Export CSV for Excel” shares two spreadsheet-ready files (semicolon-separated, decimal commas): one row per logged day with status and note, and one row per fast with start, end and duration."),
            GuideItem(lead: "Updates", text: "new versions arrive through TestFlight; there is no Update button in the app. The version you are on is written in Settings."),
        ]),
        GuideTopic(id: "reminder", icon: "bell", title: "Reminder and icon number", items: [
            GuideItem(lead: "Daily reminder", text: "Settings, Daily reminder: pick the time, allow notifications, done. The device plans a notification for the next 30 days at that hour, naming what is still open: “2 still open: Intermittent Fasting, Reading”. No server is involved. It is planned again whenever you open the app or tick something; when everything scheduled for today is done, no reminder comes. If the app is not opened for 30 days the reminders stop until you open it again."),
            GuideItem(lead: "Per device", text: "the reminder and the icon number are set on each device on its own — a phone may remind you at 20:00 and the Mac not at all."),
            GuideItem(lead: "Icon number", text: "the app icon can show how many scheduled habits are still open today. It is off until you switch it on in Settings. It needs your yes to notifications, the same permission as the reminder. On the Mac the number is on the Dock icon."),
        ]),
    ]
}
