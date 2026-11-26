import SwiftUI

/// Settings › What's new: every version, newest first (Lane D).
/// 2.0 is the native app; 1.51 and everything below it is the web app's own history, copied word for word.
struct Release: Identifiable {
    let version: String
    let date: String
    let tagline: String
    let bullets: [String]
    var id: String { version }
}

struct WhatsNewScreen: View {
    @State private var open: Set<String> = ["2.0"]

    var body: some View {
        Page(id: "screen-whatsnew") {
            PageTitle(title: "What's new", subtitle: "Every version, newest first")
            ForEach(Releases.all) { r in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            if open.contains(r.version) { open.remove(r.version) } else { open.insert(r.version) }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Version \(r.version)").font(.headline.weight(.heavy)).foregroundStyle(r.version == "2.0" ? Ink.accent : Ink.text)
                            Text(r.date).font(.footnote.weight(.medium)).foregroundStyle(Ink.dim)
                            Spacer(minLength: 0)
                            Text(open.contains(r.version) ? "Hide" : "Show").font(.footnote.weight(.semibold)).foregroundStyle(Ink.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("version-\(r.version)")
                    if open.contains(r.version) {
                        Text(r.tagline).font(.subheadline.weight(.semibold)).foregroundStyle(Ink.text).padding(.top, 6)
                        ForEach(Array(r.bullets.enumerated()), id: \.offset) { _, b in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•").foregroundStyle(Ink.dim)
                                Text(b).font(.subheadline).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 5)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18).fill(Ink.surface))
            }
        }
    }
}

enum Releases {
    static let all: [Release] = [native] + web

    static let native = Release(version: "2.0", date: "26 Nov 2026",
        tagline: "Tracking is now a real app — for iPhone, iPad and Mac, kept in step by iCloud.",
        bullets: [
        "One app on three devices — the same Tracking icon on iPhone, iPad and Mac. It replaces the TestFlight app Tracking 1.51 of this morning (same place in the App Store, so it updates over it). The Safari web app stays as it was.",
        "iPad and Mac: three columns side by side — a sidebar (Today, Stats, Last week, Last month, Aspirations, Settings), the part you picked in the middle, and the tapped habit's page on the right. Before, every screen pushed over the last one.",
        "iPhone: as before, Today with the floating bar at the bottom. The bar's three buttons now carry their words under the marks — Stats, Add, Settings — so no mark is left to guess.",
        "iCloud Drive keeps every device in step — one file, merged habit by habit, and the newest change wins. A habit you remove on one device is removed on the others too. Settings shows where the data lives and when it was last in step.",
        "A proved safety copy is made by itself every day, and the last 30 are kept. Each copy is read back before it counts. A file the app cannot read is never written over — it is parked in the safety copies first. Because of this, the old “back up” reminder is gone.",
        "Export backup and Import backup stay, in the same file shape as the web app — a backup from the web app imports here, and the other way round.",
        "Moving in from the web app: in the Safari web app use Settings, Export backup (JSON); then here use Settings, Import backup. If you had already imported into this morning's TestFlight app (1.51), 2.0 takes those habits over by itself on its first start — nothing to do.",
        "Siri works on the data directly now: “Hey Siri, start fasting in Tracking”, “stop fasting in Tracking”, “start a fast in Tracking”, “end my fast in Tracking”. The fast is changed at once — no waiting until the app opens, no “Siri: fast started” message later. Siri still answers out loud without opening the app. Also in Shortcuts and Spotlight.",
        "The Home Screen icon menu works the same way: Start Fasting (the moon) or Stop Fasting with “Since 20:13” (the fork and knife) changes the fast directly.",
        "Mac: Siri and Shortcuts work too.",
        "Daily reminder and the number on the icon are per device. The reminder is a local notification: the next 30 days at the time you choose, naming what is still open (“2 still open: Intermittent Fasting, Reading”). No server is involved any more, and nothing leaves your devices except through iCloud. On the Mac the number is on the Dock icon.",
        "Mac: right-click a card for Done today, Skip today, Yesterday done, Start or Stop fast, and Edit. ⌘N starts a new habit. Escape closes a sheet like Cancel.",
        "Reorder is by dragging: press and hold a card (not the round button) and drag it onto another card — a blue outline shows where it will land. Settings, Reorder habits has drag handles instead. Swiping a card right (done) or left (skip) works as before on iPhone and iPad, with the green or grey ring showing when the swipe is far enough.",
        "Everything else from the web app is here: daily, weekly-target, several-part and start/stop habits, the fasting ring and stages, the editable calendar, skip days and vacations, day notes, year posters, Stats and Achievements, Last week and Last month with the written analysis and the picture report, Aspirations, habit ideas, archive, fasting-history import, CSV export, text size that follows the system.",
        "How it works is rewritten for the native app, in topics you can open one at a time, and it has Signs in this app — every mark and colour with its meaning, including the words under the floating bar, the blue drop outline, the swipe ring and the sidebar marks.",
        "Removed: the “Check for app update” row and the Update button (TestFlight brings new versions); the sample habit on a first start (with iCloud, a new device must not add one); the web-only ?fast= links.",
        "Needs iOS 17 or later on iPhone and iPad, macOS 14 or later on the Mac."
        ])

    static let web: [Release] = [
    Release(version: "1.51", date: "26 Nov 2026", tagline: "Start and stop a fast without opening the app — from the Home Screen icon and by voice.", bullets: [
        "iPhone app only — everything below works in the iPhone app from TestFlight. The app added to the Home Screen from Safari cannot do it, and nothing changes there.",
        "Press and hold the icon — the menu now shows one fasting entry, the one that fits: Start Fasting (a small moon) when no fast runs, Stop Fasting (a small fork and knife) with the line “Since 20:13” while one runs. Tapping it opens the app and starts or ends the fast at that moment, with the same message and Undo as tapping the fasting card.",
        "Siri, nothing to set up — say “Hey Siri, start fasting in Tracking” or “stop fasting in Tracking” (also “start a fast in Tracking”, “end my fast in Tracking”). The app does not open. Siri answers, for example “Fast started at 20:13. Goal 16 h, until 12:13.” or “Fast ended after 16 h 5 min. Goal of 16 h met.”",
        "Siri tells you when it cannot — “You are already fasting, since 20:13.”, “No fast is running.”, and, before the app has ever been opened, “Open Tracking once, then try again.”",
        "In the Shortcuts app — Start Fasting and Stop Fasting appear by themselves under “Tracking”, so they can go into your own shortcuts, onto the Action button, or be found in Spotlight. To say only “Hey Siri, start fasting”, add the action in Shortcuts and name the shortcut “Start Fasting” (same for Stop). The steps are in How it works.",
        "Kept with Siri's exact time — a fast started or ended by Siri while the app is closed is saved with the time Siri heard you. The next time you open the app it shows up, with a message like “Siri: fast started at 20:13” or “Siri: fast ended at 12:05 — 16:05 h” and Undo. Several Siri steps while the app was closed are all applied, in order.",
        "Which habit — the first fasting habit in your list (the first start/stop habit that is not archived), the same one the old ?fast= links used.",
        "iOS 17 or later — the iPhone app now needs iOS 17 (it was iOS 15).",
        "How it works changed — the old paragraph saying Siri and Shortcuts cannot start the app is replaced by the steps above, and a new section, Signs in this app, lists every mark and colour with its meaning, including the moon and the fork and knife.",
        "New app icon — the day grid, now hand-drawn in the style of your other apps: white ticks for done days and open squares for days still to do, on a flat calm blue (before: filled squares on a blue-to-purple fade). Your pick “1” of four. The iPhone app shows it at once; the app added from Safari keeps the icon it was added with until you remove and re-add it (back up first — see App icon above)."
    ]),
    Release(version: "1.50", date: "24 Nov 2026", tagline: "A real iPhone app, through TestFlight.", bullets: [
        "What it is — the app can now also be built as a native iPhone app and installed through Apple's TestFlight. It is the same app with the same screens: its files are packed into a native shell instead of being loaded from the web.",
        "Nothing changes in the app you have — the one added from Safari works exactly as before, including the daily reminder through the reminder service. This release only adds the parts the iPhone app needs, and they stay switched off everywhere else.",
        "Separate data — the iPhone app starts empty. Move your data once with Export backup (old app) and Import backup (new app); after that the two apps do not sync with each other.",
        "Reminder without a server — in the iPhone app the phone plans the notifications itself, for the next 30 days at the time you choose. They are re-planned whenever you open the app or tick something off; today's is dropped once everything is done. Turn the reminder on once in the new app, also after importing a backup in which it was on.",
        "Icon badge, sharing — the count on the icon and the share sheet for backups, CSV files, the weekly report and posters use the iPhone's own functions there.",
        "A safety copy of your data — the iPhone app writes every change to a second place, a file inside the app, and restores from it if its normal storage is ever found empty.",
        "Updates through TestFlight — every release is uploaded to TestFlight as a new build, and a fresh build is uploaded on the 1st of each month because a TestFlight build expires after 90 days. The iPhone app therefore has no “Check for app update” row.",
        "Long names on the fasting card are no longer cut off — since the icons grew in v1.49, a longer name on a start/stop card could end in “…” on the iPhone (“Intermittent Fas…”). The app now measures each name on Today and makes it a size smaller when it does not fit, and smaller once more if needed; only a name that does not fit even at the smallest size keeps its “…”. This applies to the web app as well.",
        "Five more tests — the reminder planned on the phone, the badge, the share sheet for a backup, and the safety copy with its restore are each tested against a stand-in for the iPhone's functions, and one test checks that a long name is fitted; on GitHub the iPhone app itself is compiled and started in a simulator on every change."
    ]),
    Release(version: "1.49", date: "24 Nov 2026", tagline: "Habit icons you can see.", bullets: [
        "Before — v1.48 had already enlarged the picture in front of each habit's name on Today from 19 to 24 points.",
        "Changed — it is now 32 points at the standard text size, the largest of the three sizes you compared (24, 28, 32). The grid layout keeps its 22 points: those cards are narrow, and a larger icon there would cut long names shorter.",
        "Unchanged — the cards are exactly as tall as before, and in the list a long habit name is still shown in full; the week dots sit about three points lower inside the card. The icon keeps following the iPhone's text-size setting.",
        "A seventh test — the icon must have this size, a long name must not be cut off, and a card with a long name must be no taller than one with a short name."
    ]),
    Release(version: "1.48", date: "24 Nov 2026", tagline: "A grid for an icon, and Today without a header.", bullets: [
        "New app icon — the flame is replaced by a day grid: four rows of four squares on the same blue-violet background, solid for days done, pale for days missed, and a hollow square for today — the year grid from a habit's detail view in miniature. All icon files changed together (Home Screen, notifications, browser tab).",
        "Your installed app keeps the flame until it is re-added — an iPhone stores the icon when the app is added to the Home Screen and does not fetch it again. To see the new icon: export a backup first (Settings → Export backup), remove the app from the Home Screen, add it again from Safari, import the backup, and switch the daily reminder on again. Removing the app can delete its data, so the backup comes first.",
        "Today has no header any more — four things you crossed out are gone: the Morning / Afternoon / Evening greeting, the faint version number at the top right, the segmented day bar, and the “2 of 7 done” counter next to it. The screen now begins with the first habit card.",
        "Larger habit icons in the list — the small picture in front of each habit's name on Today is about a quarter larger (24 instead of 19 points at the standard text size), in the list and in the grid layout. The cards keep their height.",
        "Gone with the day bar — the short celebration it played when the last habit of the day was checked off. The check mark on each card still draws itself, and the milestone celebrations are unchanged.",
        "Where the version went — it is written at the very bottom of Settings, as before. Tapping the version number on Today to look for an update is no longer possible; Settings → Check for app update does the same, and the app still checks by itself whenever it is opened.",
        "A sixth test — Today must begin with the habit cards and nothing above them, and the version must be readable in Settings. The start-up test now reads the version there instead of from the removed pill."
    ]),
    Release(version: "1.47", date: "18 Nov 2026", tagline: "No more goal sheet on hold.", bullets: [
        "Before — pressing and holding the fasting habit's start button opened the Tonight's goal sheet (the habit default, 13h, 15h, 16h, 18h) to pick a goal for one fast.",
        "Changed — that sheet is gone. Holding the fasting button now does nothing special; a normal tap starts and stops the fast as before.",
        "Now — the fasting goal is set in one place only, Edit habit (the main goal plus the optional goals for single weekdays). Fasts that already carry a goal picked earlier keep it.",
        "Unchanged — press-and-hold on check-off habits still marks yesterday done or picks parts."
    ]),
    Release(version: "1.46", date: "18 Nov 2026", tagline: "One place for the fasting goal.", bullets: [
        "Before — tapping a running fast opened the Edit fast sheet with the Started time and a row of up to five goal buttons (Goal for this fast: the habit default plus 13h, 15h, 16h, 18h), so the goal could be changed in two places.",
        "Changed — the goal buttons are gone from that sheet. The fasting goal is now set once, in Edit habit (the main goal plus the optional goals for single weekdays).",
        "Now — the sheet for a running fast has only the Started time, the duration line, Delete, and Cancel/Save (a finished fast also has Ended). A goal you already picked for a running fast is kept.",
        "Unchanged — press-and-hold on the start button still opens Tonight's goal for a single fast."
    ]),
    Release(version: "1.45", date: "2 Oct 2026", tagline: "The badge is a choice again.", bullets: [
        "The number on the app icon is off unless you switch it on — since v1.29 it appeared by itself the moment notifications were allowed, and the daily reminder allows them, so turning the reminder on put a number on your icon you never asked for. It is gone. Settings → Show the count on the app icon turns it on; the same row, now reading Hide the count on the app icon, turns it off again.",
        "The icon in notifications matches the Home Screen — the notification and the Notifications list in iPhone Settings use a different icon file than the Home Screen does, and that file was a pre-rounded tile with see-through corners that iOS rounded a second time, which made it look smaller and darker. All icon files now carry the same full-bleed flame. An app already on the Home Screen may keep the icon it was installed with; a fresh installation gets the right one.",
        "A third test — the icon badge stays off after notifications are allowed, shows the count when switched on, and clears when switched off."
    ]),
    Release(version: "1.44", date: "2 Oct 2026", tagline: "A reminder at your hour.", bullets: [
        "Daily reminder — Settings → Daily reminder. Pick the time in the field on the right (it starts at 20:00), tap the row, allow notifications. Every day at that hour the phone shows a notification, app closed or not, that names what is still open — “2 still open: Intermittent Fasting, Reading” — or just says it is time to fill things in if the app has not been opened that day. Tapping it opens the app. Tap the row again to turn it off; change the time whenever you like.",
        "Quiet when there is nothing left — if everything scheduled for today is ticked off before the hour, no reminder comes.",
        "The first thing that leaves the phone — an installed web app cannot wake itself, so a tiny program of Martin's at Cloudflare (its code is in the repository) keeps the reminder time, the phone's push address and a yes/no “done today”, and sends the nudge. It never sees a habit. With the reminder off, nothing is sent at all — the rest of the app stays exactly as private as before. How it works says this in full.",
        "Every update is tested before it goes live — automatic tests now run the app at iPhone size on every change, and a failing run keeps the previous version online. The first two tests check that the app starts cleanly with one consistent version number everywhere, and that the reminder turns on, keeps its time across a restart, and turns off."
    ]),
    Release(version: "1.43", date: "15 Sep 2026", tagline: "Two buttons that cannot be lost.", bullets: [
        "The review cards are gone; two permanent buttons replace them — Last week and Last month, always under your habits on Today. You swiped one away and could not get it back, which is a fault in the design and not in the swipe: something that vanishes for six days on one gesture should never have been dismissible.",
        "“Last week” is written once, on the button — the heading above it said the same words, which was one word too many in two centimetres.",
        "Settings → “Show week in review” is gone with them — it existed to bring back a card you could lose. There is nothing to bring back now, because there is nothing to lose. It was also buried where nobody would look, which is why it was no help to you."
    ]),
    Release(version: "1.42", date: "15 Sep 2026", tagline: "The month goes the same way.", bullets: [
        "“August in review” is off the home screen too — same shape as the week card, same reason. It is now one line with a Last month button, and Stats has the same entry.",
        "The screen it opens starts with a chart — ticks in each week of the month, with the day each week began under its bar. A month that starts on a Saturday opens with a two-day bar, which is why those dates are printed and named in the line underneath: a short first or last bar is a short week, not a bad one.",
        "Everything the card listed is there, and a little more — each habit's figure and its change on the month before, and for daily habits the longest run of the month spelled out rather than left as a bare number beside a flame."
    ]),
    Release(version: "1.41", date: "15 Sep 2026", tagline: "A chart, and Today gets its screen back.", bullets: [
        "The week as a chart — last week's analysis now opens with a proper bar chart: how many habits you completed on each day, Monday to Sunday, each bar in its own track so a quiet day reads as quiet rather than missing. A line underneath names the day that carried the most.",
        "Why the bars are one colour and not six — a stacked bar coloured by habit would ask you to tell your habits apart by hue in a 40px block, and your palette has two reds and two purples in it. The chart answers “which days carry the week”; identity stays in the rows below, where each habit's name is written beside its own colour.",
        "The “Last week” card is off the home screen — you circled it and said so, and you were right: Today is about today, and a six-row table of the week before was the largest thing on it. What remains is one line with the dates and a Last week button. Nothing was lost — the figures and the streak changes moved onto the analysis rows, beside the seven-day drawing."
    ]),
    Release(version: "1.40", date: "15 Sep 2026", tagline: "The week, drawn, at the top.", bullets: [
        "Last week's analysis opens with a picture — the headline count of habits on target, then each habit's seven days as coloured squares. The report you can send has always had a drawing and the screen you actually read went straight into text, which was the wrong way round.",
        "Same alphabet as the rest of the app — solid is done, plain is missed, a dashed outline is an excused day, dim is a day the habit was not asked for. Nothing new to learn, and tapping a row opens that habit.",
        "The figures come from the same reading as the summary and the picture, so the three cannot disagree. Everything below it is unchanged."
    ]),
    Release(version: "1.39.1", date: "15 Sep 2026", tagline: "Two things v1.39 should not have shipped with.", bullets: [
        "Habits can be attached from the aspiration — the sheet now asks Which habits serve it? and lists every habit as a tap-to-attach chip. Before, the only route was to edit each habit in turn and use its Serves row, which meant writing an aspiration and then having no way to fill it from the screen you had just written it on. Both routes work; the habit's own row is unchanged.",
        "A habit held by another aspiration says so — its chip carries that aspiration's name, so moving it is a decision rather than something that happens quietly behind you.",
        "The aspiration text field was tiny — it had no styling of its own and fell back to the browser's default, next to prose at full size. It is now the same field as the habit name box. The rule covers both boxes rather than naming one, so the next field added cannot be forgotten the same way."
    ]),
    Release(version: "1.39", date: "15 Sep 2026", tagline: "What the habits are for.", bullets: [
        "Aspirations — Stats → Aspirations. One sentence about who you are becoming, with habits attached to it. No date, no number, no colour of its own. Editing a habit gains a Serves row, and it only appears once you have written an aspiration — until then nothing about the app changes at all.",
        "It is answered every week, which is the whole point — its own screen, a section in last week's analysis and a line in the written summary all say how many of its habits ran. A goals field nothing reads back is dead text within a month; this one has to earn its place every Monday.",
        "A quiet one gets asked about — three silent weeks and it says “Nothing has run under this for 6 weeks. Is it still true?” That is either a run of bad weeks or a sign it is no longer what you want, and only you can say which.",
        "Said once, then left alone for a month — that an aspiration has no habits under it, or that some habits serve nothing. Both are true and neither is urgent, and a true sentence repeated weekly stops being read, taking the useful notes with it.",
        "Never a blank box — the sheet offers four sentences to start from, and whatever you pick is yours to rewrite. Nothing in particular stays available for every habit, forever. Archiving an aspiration leaves every habit exactly where it was, and Undo puts it back.",
        "Nothing was removed to make room for any of this."
    ]),
    Release(version: "1.38.1", date: "15 Sep 2026", tagline: "A shorter button.", bullets: [
        "The button on the “Last week” card reads Last week. Your wording. The screen it opens keeps its own title, and the Stats entry is unchanged.",
        "This entry is late: v1.38.1 shipped without one, which it should not have."
    ]),
    Release(version: "1.38", date: "15 Sep 2026", tagline: "Both sends, in one place.", bullets: [
        "Send this report has moved — it sat on the “Last week” card while the written summary's send button sat on the analysis screen, which split the same job across two places. Both now sit under the summary, on the screen about the week they send.",
        "They say which is which — Send this summary as text and Send the week as a picture. Two buttons both reading “send this” would have told you nothing about the difference.",
        "The “Last week” card now has one button, Last week, which opens the analysis. Settings → Send last week's report is unchanged."
    ]),
    Release(version: "1.37", date: "15 Sep 2026", tagline: "The cards are back.", bullets: [
        "Nothing should have been removed — you asked for a written summary as well as the cards, and v1.36 put the text in and took the cards out. How it went and What to try next week are back, below the summary, exactly as they were: one card per observation in its habit's colour, each tapping through to that habit.",
        "The overlap is deliberate — the text and the cards say the same things. The words are what you read through and send; the cards are what you glance at and tap. Neither replaces the other, and neither should have been asked to."
    ]),
    Release(version: "1.36", date: "15 Sep 2026", tagline: "A summary, written out.", bullets: [
        "Last week's analysis is now text — you asked for a written summary with insights in it, and twice got a screen of cards instead. A list of findings is not a summary. It now reads as paragraphs: what happened (“Between 7 and 13 September you ticked 16 days across 3 habits. I am reached 6 of 6, Cold shower ran every one of its 7 days and Intermittent Fasting recorded 3 fasts averaging 16:00”), whether that was good measured against your recent normal, the pattern underneath it with what to do about it, and one habit idea.",
        "Send this summary — the whole text goes to the share sheet, which is the mail-and-message route you asked about at the start. The picture and the words are separate buttons on purpose: a photograph suits one person and a paragraph suits another.",
        "Each paragraph says which habit it is about — obvious in a card, where the habit's name was the heading, and easily lost in prose. “5 of your 9 missed days were followed by another” now arrives attached to the habit it belongs to.",
        "A habit is no longer judged on days before it existed — found while writing the summary. A habit created on a Thursday was reported as “0 of 7 days” for that week. Weekly figures now only cover habits that were there for the whole week, and when nothing qualifies the screen says why and when there will be something."
    ]),
    Release(version: "1.35", date: "15 Sep 2026", tagline: "Last week's analysis, and only that.", bullets: [
        "The screen is now what its button promises — press Read last week’s analysis on the “Last week” card and you get last week's analysis. It is titled the same words as the button, and dated to the week that ended (“Sep 7 – Sep 13”) rather than the one you are in.",
        "“Where you are” is gone from it — a section about the week in progress had no business on a screen opened from a card about the week before. This week's count already sits on the Today card, which is where you are looking anyway.",
        "What stayed — How it went (last week judged against your recent normal), What to try next week (the pattern read across eight weeks), and Something new?. The analysis was never the problem; where it was and what it was called were."
    ]),
    Release(version: "1.34", date: "15 Sep 2026", tagline: "Last week, and what it meant.", bullets: [
        "A button on the “Last week” card called itself “this week's notes” — you went looking for last week's and reasonably expected both. It now says Read the notes, and the screen is called How it’s going: it covers last week, this week and next, so a title naming one of the three was always going to send somebody the wrong way.",
        "And you were right that last week's was missing — the card and the picture give the week's figures, and nothing said whether they were any good. The screen now opens with Last week: “6 of 6 for the first time in eight weeks”, “ended on 4 of 6 after four weeks that made it”, “better than any of the last eight weeks”.",
        "It only speaks when something stood out — a best week, a first in months, a run beginning or ending. A week that matched your normal gets no sentence, and a habit with less than three weeks of history gets none either. Two at most.",
        "Why the two readings are separate — Last week judges one week against your recent normal. What to try next week ignores single weeks entirely and reads eight of them for a pattern. A bad week is not a habit, and a habit cannot be seen in one week; keeping them apart is what stops either from lying."
    ]),
    Release(version: "1.33", date: "15 Sep 2026", tagline: "The app says something.", bullets: [
        "This week's notes — a new screen, from Stats or from the “Last week” card. Where you are says how each weekly target stands and how many days are left to save it. What to try next week gives at most three observations from your last eight weeks. Something new? offers three habit ideas.",
        "Every note shows its working — “4 of your last 8 misses fell on a Thursday”, “Sunday was blank in every one of the 4 weeks you came up short, against 0 of the 4 you made”. The figure is in the sentence so you can disagree with it. This is arithmetic on your own data, not intelligence and not anything sent anywhere; the app has no server and your data has still never left the phone.",
        "It would rather say nothing — most notes need several weeks of history before they will speak, and when nothing honest can be said the screen says so. Two data points are a coincidence, and a confident sentence about a coincidence is worse than a blank.",
        "It knows the difference between a rest day and a miss — on a weekly target of 6 out of 7, one blank day every week is the plan. The notes never treat that as a lapse; for a weekly habit they look at the weeks that fell short and compare them with the weeks that did not, which is how “Sunday” surfaces instead of the Wednesday you always take off.",
        "Habit suggestions, three at a time — rotating weekly, with anything resembling a habit you already keep left out, and each with a reason rather than just a name. Add this habit opens the normal new-habit sheet filled in; nothing exists until you press Save."
    ]),
    Release(version: "1.32", date: "15 Sep 2026", tagline: "Your week, as a picture you can send.", bullets: [
        "A weekly report — the “Last week” card now has a Send this report button. It draws the week as a picture: every habit with its seven days as coloured squares, what you managed, how each streak moved, and a headline counting the habits that hit their target. The share sheet takes it to Messages, Mail, WhatsApp, anywhere.",
        "It offers itself — that card already appears by itself the first time you open the app in a new week, so the report is waiting for you rather than hidden in a menu. Settings → Send last week's report gets it back any time, including after you have dismissed the card.",
        "Automatic sending is not possible, and it is worth knowing why — an installed web app is given no time to run while it is closed, so nothing can fire on a Sunday evening by itself. And a server somewhere could not help: your data has never left this phone, so there would be nothing for it to report on. Sending it automatically would mean uploading everything you track, which is the one thing this app has never done. One tap, from a card that comes to you, is as close as it gets honestly.",
        "The card and the picture can no longer disagree — both now read the same single set of figures. Before, the card worked them out for itself; a second copy of the same arithmetic is how a summary and its own export end up telling different stories."
    ]),
    Release(version: "1.31", date: "15 Sep 2026", tagline: "How many this week.", bullets: [
        "A weekly target now says where you stand — its Today card leads with the count, “4/6”, and the words “this week” beneath. It turns green when you reach the target. The week streak keeps its flame on a smaller line underneath, so nothing that was on the card has gone.",
        "Why this is not the counter you had removed — in v1.23 the little “3/7” after the week dots was taken off, because it sat on every card and the filled dots already told the story. This one appears only on a weekly target, where the dots do not: counting six filled dots out of seven is exactly the thing a number saves you. Daily and fasting cards are untouched, and nothing was put back after the dots.",
        "The guide had been describing this ratio since weekly targets were introduced, and the card never actually showed it. Now it does."
    ]),
    Release(version: "1.30", date: "15 Sep 2026", tagline: "A habit may change its mind.", bullets: [
        "Daily and weekly can now be swapped on a habit that already has history — you asked to move “I am” from a daily check to six times a week and found the choice greyed out. It was locked for every habit, on the grounds that the three types keep their history differently. That is true of Start / Stop, and it was never true of the other two: a daily check and a weekly target both record one mark per day, in the same place, and differ only in how that is read. So the lock has been lifted for those two. Edit the habit, pick the other type, save — every day you have ticked stays.",
        "The number to start from — switching to a weekly target offers the count of days the habit was scheduled for, so a habit that ran all seven days offers 7×. Tap 6 (or whatever you want) before saving.",
        "It tells you what will change — while the type is switched, a line under the buttons says that your ticks stay and that the streak will restate itself: weeks that reached the target, instead of days in a row. That is the one thing that genuinely changes, and it changes on screen rather than in your data.",
        "A weekly habit's completion count was short by one — found while testing the switch. Until Sunday came, the week you were in was counted as a week already missed, so “weeks met” and the completion percentage on a weekly habit always read one week worse than the truth. The streak was never affected. Fixed, and it corrects itself for past weeks too — nothing about your data had to change, only the counting.",
        "Start / Stop stays fixed — a fasting habit cannot become a daily check and a daily check cannot become a fasting habit. Fasts are start and end times; days are days. There is no honest conversion, so the buttons stay off rather than pretending."
    ]),
    Release(version: "1.29", date: "10 Sep 2026", tagline: "The icon badge never actually worked.", bullets: [
        "The badge has never appeared, and now it can — the home-screen icon was supposed to show how many habits are still open today. An iPhone only allows an installed app to put a number on its icon once you have agreed to notifications, and this app never asked. It asked the system for the badge, the system refused, and the refusal was quietly discarded — so the feature described in this guide has simply never happened on your phone.",
        "How to switch it on — Settings now has Show the count on the app icon. Tap it, allow the prompt, and the number appears. The button then tells you it is on. Nothing else changed, and the count itself works exactly as it always did: scheduled habits still open today, with a running fast counted as underway rather than open.",
        "Found while fixing the same fault elsewhere — AMS CountDown had it too, along with a more serious one where a backup could save no file yet still report success. That has been repaired across CountDown, PackTrack, ColdShower, TechLingo, FermentLog, Breathing and the Main Hub. This app's own backup was already correct — it has used the share sheet all along."
    ]),
    Release(version: "1.28", date: "3 Sep 2026", tagline: "Parts on an earlier day.", bullets: [
        "Yesterday, part by part — press and hold the big circle of a multi-part habit and a sheet opens for yesterday with one button per part. Tick just the ones you did and save. Until now the hold marked all parts done, which was the one thing v1.27 couldn't express.",
        "Any earlier day too — tapping a day in a multi-part habit's calendar opens the same sheet for that day, with its current parts already ticked, instead of the done → skip → empty cycle. Saving with nothing ticked empties the day, and “Mark as skip day instead” excuses it, so nothing that was possible before has been lost.",
        "Every change made this way shows an Undo bar that puts the day back exactly as it was, and backfilled days still never trigger a celebration. Habits without parts are completely untouched — hold still marks yesterday done in one go.",
        "Documentation — the “Habits with several parts” section now covers earlier days, and the “Forgot yesterday?” and “Fixing the past” paragraphs say what happens on a multi-part habit. That gap was the reason for this release."
    ]),
    Release(version: "1.27", date: "3 Sep 2026", tagline: "One habit, three parts.", bullets: [
        "Multi-part habits by tap count — a habit named with vertical bars, like Medit | Brea | Cold, is now tracked part by part. One tap on the big circle toggles the first part, two quick taps the second, three the third — exactly as requested. Nothing to set up: the parts are read from the name, so the habit you already have works the moment this update lands, and your history for it stays untouched.",
        "You can see the count landing — while you tap, the part that's about to be toggled lights up, so a double tap visibly moves the highlight from the first word to the second. A moment after your last tap the change registers and a bar confirms it (“Brea done”, “Medit cleared”) with Undo, in case a tap was counted differently than you meant. Extra taps stay on the last part rather than doing something unexpected.",
        "Colored where it counts — parts you've done are written in the habit's color, the rest stay gray, and the big circle is checked as soon as any one part is done, so streaks, week dots and the day bar treat the day as complete. Tapping a part's word toggles precisely that part, and a swipe to the right still marks the whole set at once.",
        "The CSV export gained a parts column listing which parts each day holds."
    ]),
    Release(version: "1.26", date: "3 Sep 2026", tagline: "A goal for every weekday.", bullets: [
        "Per-weekday fasting goals — editing a fasting habit now shows seven small fields under the main goal, one per weekday (Mon–Sun). Fill in only the days that differ — say 16 for Mon–Thu and 14 on Friday — and leave the rest empty to use the main goal. A goal belongs to the day a fast ends on (the day it counts for), so Friday's softer goal applies to the fast you begin Thursday evening.",
        "Everything follows the day's goal — the traffic-light ring, the countdown and goal clock, the “until” time of the eating window, the goal chips when starting or backfilling a fast, and the green/gray hour circles in the calendar all use the goal of that particular day. A per-fast goal picked with the long-press still overrides everything, exactly as before.",
        "Nothing changes if you don't touch the new fields — one goal for all days keeps working exactly as it always has."
    ]),
    Release(version: "1.25", date: "3 Sep 2026", tagline: "The month, and the pattern.", bullets: [
        "Month in review — when a new month begins, a card like the Monday “Last week” one sums up the finished month: for daily habits the days completed and the longest unbroken run of the month, for weekly habits the total check-offs versus the month before, and for fasting the number of fasts with the average length and its change versus the previous month. Tap a row to open the habit; the × dismisses it until the next month.",
        "Fasting rhythm — once a fasting habit has at least five recorded fasts, Stats gains a rhythm card: your usual start time (computed the right way around midnight), your strongest weekday, your average fast, and a Mon–Sun bar chart of average fasting hours per weekday. Now the app doesn't just record your fasts — it shows you their shape."
    ]),
    Release(version: "1.24", date: "3 Sep 2026", tagline: "Two gentle nudges.", bullets: [
        "Record within reach — when a habit's current streak comes within 3 days (or 1 week for weekly-target habits) of your all-time best, its Stats card shows a quiet line in the habit's color: “2 days to your record”. It appears only while the record is genuinely close and disappears once you pass it — then the milestone confetti takes over.",
        "Backup nudge — your data lives only on this phone. If the last backup is more than 30 days old (or was never made), the app now says so once when opened — at most once a month — with a “Back up” button that opens the share sheet directly. Backing up from Settings resets the clock."
    ]),
    Release(version: "1.23.3", date: "2 Sep 2026", tagline: "Clearer words on the eating window.", bullets: [
        "“until 19:01” instead of “next fast 19:01” — the line under the eating counter now completes the sentence: “6:22 eating, until 19:01” means the eating window closes at 19:01, which is when to start fasting again to keep the daily rhythm. Once that moment passes, it says “time to fast” instead of “next fast now”. Same calculation, friendlier words — Martin found “next fast” unclear."
    ]),
    Release(version: "1.23.2", date: "2 Sep 2026", tagline: "A quieter header.", bullets: [
        "The heading greets the time of day — instead of “Today”, the main screen now says Morning, Afternoon, or Evening, matching the clock. The date line underneath is gone — your phone already knows the date, and the screen is about what to do, not when it is. Requested by Martin.",
        "Washed-out version number — the bright blue version pill is now a faint gray number that stays out of the way. It still shows which version you're on and a tap still checks for an update immediately."
    ]),
    Release(version: "1.23.1", date: "2 Sep 2026", tagline: "Less counting, more looking.", bullets: [
        "The x/7 counter is gone — the little “3/7” (and the weekly “2/5”) after the week dots has been removed from the Today cards. The filled dots already tell the story at a glance, so the number was just noise. Requested by Martin. The dots themselves are unchanged — still tappable shortcuts into that day of the calendar, and a weekly habit's target is still visible in its detail view and when editing the habit."
    ]),
    Release(version: "1.23", date: "2 Sep 2026", tagline: "Colors you can see, an edit zone that's always there.", bullets: [
        "Richer card colors — the pastel panel behind each habit is noticeably stronger, and the color mixing was reworked so every hue keeps its character in the pale tint. The purple and lilac cards, which used to melt into the gray background, now stand out just as clearly as the yellow, green, and pink ones. Requested by Martin: “you can almost not see them.”",
        "Edit zone between fasts — the edit word and tap zone on the fasting card no longer disappear when no fast is running. Between fasts, tapping the number on the right (the eating time or your last fast's length) opens that last fast in the editor — so a forgotten stop or a wrong end time can be fixed straight from the Today screen, without going through the calendar.",
        "All seven day dots on one line — the weekday indicators are slightly smaller everywhere, and one size smaller on the fasting card, whose right side (eating window, goal times) needs the room. The M–S row plus the 3/7 count now fits on a single line instead of wrapping."
    ]),
    Release(version: "1.22", date: "2 Sep 2026", tagline: "Fast to start, honest offline, and a day bar with segments.", bullets: [
        "Segmented day progress — the “3 of 5 done” bar is now made of one segment per habit scheduled today, so you can count the filled pieces at a glance. It adapts automatically when habits are added, removed, archived, or skip-marked. The filled part walks the traffic light as the day progresses — red when the day has barely started, amber in the middle, green when everything is done — and the completion flourish stays.",
        "Much faster startup — the offline cache now answers requests for the app's style and code files directly instead of asking the network on every launch, and a slow connection can no longer hold up the start: after 2 seconds the stored app appears immediately while the network update finishes in the background for next time.",
        "Update mismatches fixed — the updater could fill its offline store with files from the previous version, because the web server is allowed to answer from a 10-minute cache right after a release. Installing now demands truly fresh files, which is what broke today's update on the phone.",
        "White-screen fix — when a style or code file failed to load over a bad connection, the app used to answer with the wrong content, which could paint everything white and drop the icons (as seen right after today's update). A failed file now fails honestly and comes from the offline cache instead, so this can't happen again.",
        "Fasting card back on one line — v1.21's tap-area words made the card wrap on narrower screens; the labels now sit in the card's bottom edge and the card is a single line again."
    ]),
    Release(version: "1.21", date: "2 Sep 2026", tagline: "Signed and signposted.", bullets: [
        "Version pill — a small blue pill at the top right of the Today screen shows the app version at a glance (handy for checking that an update actually arrived). Tapping it checks for a new version immediately, same as the Settings button.",
        "Labeled tap areas on the fasting card — the faint dashed dividers from v1.15.2 now come with words: a tiny start (or stop while fasting) sits under the round button, stats under the middle area that opens the details, and edit under the running timer number that fixes the start time. The edit label appears exactly when that tap zone exists — while a fast is running."
    ]),
    Release(version: "1.20", date: "2 Sep 2026", tagline: "Your hands, your eyes.", bullets: [
        "Swipe actions on Today cards — swipe right to mark today done (a running fast is stopped; an idle fasting habit opens the record-hours sheet), swipe left to excuse today as a skip day. A green or gray ring appears once the swipe is far enough to fire, releasing earlier cancels, and both actions come with the Undo bar. Already-done or already-skipped days answer with a note instead of changing anything.",
        "Drag to reorder — press and hold a Today card until it lifts, drag it to its new spot (list or grid), and release; the order is saved with Undo. The reorder sheet in Settings stays for button-based moves, and the round button's own press-and-hold shortcuts still work exactly as before.",
        "Respects your iPhone text size — all type, icons, buttons, dots, and calendar circles now scale with the system's Display & Text Size preference instead of being frozen at one size. This closes the ten-improvement batch approved on 2 September.",
        "Easier-to-read gray text — the dim gray used for hints, labels, and dates is darker in the light theme (and the “backup is old” amber deeper), meeting the WCAG 4.5:1 contrast guideline in both themes."
    ]),
    Release(version: "1.19", date: "2 Sep 2026", tagline: "The feel, part two.", bullets: [
        "Day-complete moment — checking off the last scheduled habit of the day makes the progress bar pop briefly, glow, and draw a small hand-drawn checkmark next to “All N done”. Ending the day's fast counts too. Purely celebratory, fires once per completion, and stays still when the system's reduce-motion setting is on.",
        "Native-feeling screen changes — opening a habit's details or the stats screen now slides in from the right, and going back slides home from the left, like iOS push/pop navigation. Short, subtle, and disabled under reduced motion.",
        "Live preview when adding or editing — the add/edit sheet opens with a mini Today card at the top that updates with every keystroke and every icon, color, type, and weekday pick, so you see exactly what the card will look like before saving."
    ]),
    Release(version: "1.18", date: "2 Sep 2026", tagline: "Find your way.", bullets: [
        "Jump back to today — after browsing to another month in a habit's calendar, a target button appears in the header; one tap returns the view to the current month. It hides again while you're already on it.",
        "Fasting-calendar legend — a one-line key under the fasting calendar explains the hour circles (green = goal met, gray = fell short, red = fast running, dashed = skip day), so the colors don't have to be remembered.",
        "Week dots are tappable — the M–S dots on a Today card now open that habit's calendar on the tapped day and flash it briefly, so “what happened on Tuesday?” is one tap instead of a navigation trip.",
        "Today's note on the card — when today carries a note, a small colored dot appears next to the habit's name; tapping it shows the note in the bottom bar with an Edit button that opens the note editor directly."
    ]),
    Release(version: "1.17", date: "2 Sep 2026", tagline: "History, trophies, and no more gray boxes.", bullets: [
        "Import fasting history — Settings → Import fasting history takes pasted rows from another app (day + hours like “2026-08-15;14”, start/end pairs, or this app's own fasts.csv), shows a live preview of what it can read, skips days that already have a fast, and imports with one tap — undoable from the bar.",
        "Achievements — the Stats screen now opens with a trophy card: every earned streak milestone per habit (with the next one shown hollow), plus longest fast ever, best streak, and total days tracked.",
        "Proper sheets instead of browser pop-ups — recording a forgotten fast now opens a sheet with hour chips (13/15/16/18 or a typed value) and a “skip day” option, and day notes get a real editor with save and delete. Validation messages moved from pop-ups to the bar at the bottom."
    ]),
    Release(version: "1.16", date: "2 Sep 2026", tagline: "The whole rhythm.", bullets: [
        "Eating window on the card — after stopping a fast, the card now shows how long you've been eating and the clock time your next fast is due to hold the daily rhythm (24 hours minus your goal, e.g. 19:30 for a 15h goal). Ticks live; after 24 hours without a new fast it returns to showing the last fast's length.",
        "Forgotten-stop guard — a fast running longer than 24 hours turns amber with “still fasting? tap timer to fix”, since it's almost certainly a missed stop; the familiar timer-tap opens the editor to set the real end time."
    ]),
    Release(version: "1.15.2", date: "2 Sep 2026", tagline: "Three taps, made visible.", bullets: [
        "Touch-zone hints on the fasting card — the fasting tile always had three tap areas (the start/stop button on the left, the card body opening the details, and the running timer number fixing the start time), but nothing showed where one ended and the next began. Two very faint dashed vertical lines now mark the boundaries: the first is always there, the second appears only while a fast is running — matching when the timer becomes tappable. Purely visual; every tap works exactly as before. Requested by Martin after a day of live use."
    ]),
    Release(version: "1.15.1", date: "2 Sep 2026", tagline: "The review, where and when you want it.", bullets: [
        "Week review moved down — the “Last week” card now sits under the habit list instead of pushing it down from the top, so the day's check-offs stay first. Requested after one day of live use.",
        "Bring it back any time — dismissed the review too quickly? Settings → “Show week in review” shows it again immediately (and scrolls to it); previously it was gone until the next Monday. If there's nothing to summarize yet, a note says so instead."
    ]),
    Release(version: "1.15", date: "2 Sep 2026", tagline: "A year on one picture.", bullets: [
        "Year-poster export — every year card in a habit's detail view now has a share button next to its heading. It renders that year as a 1080×1350 poster in the app's style: the hand-drawn habit icon and name up top, the full year as a month-by-month pixel grid in the habit's color (completed days filled, skip days as dashed outlines, future days faint), the year's key stats as big tiles — streak, longest streak, and completion for the current year; days done and scheduled for past years — and a small “AMS Tracking” footer. Shared via the share sheet on iPhone (Messages, Photos, Instagram…) or saved as a PNG elsewhere, following the same pattern as the CSV and backup exports, including the Undo-free quiet toast.",
        "This completes the five-feature batch planned on 31 August — all suggestions have now shipped."
    ]),
    Release(version: "1.14", date: "2 Sep 2026", tagline: "Know where you stand.", bullets: [
        "Week in review — starting each Monday, a dismissable “Last week” card tops the Today screen with one row per habit: days done out of scheduled (or check-offs against the weekly target), the streak change over that week as a green or red number with the flame, and for fasting the number of fasts, their average length, and how that average compares to the week before. Rows open the habit's detail; the card holds no new data — everything is computed from what's already tracked.",
        "Fasting stages — the fasting detail view gains a “Fasting stages” card: a colored track from 0 to 20+ hours divided into Digestion (0–4h), Settling in (4–12h), Fat burning (12–16h), and Deep fast (16h+). During a fast, a marker shows the elapsed time on the track, the current stage lights up while the others dim, and a “Now:” line names the stage; it updates live every 20 seconds, as does the calendar's running hour count. Clearly labeled as a popular approximation, not medical advice."
    ]),
    Release(version: "1.13", date: "2 Sep 2026", tagline: "Life happens — in bulk.", bullets: [
        "Skip several days at once — a new “Skip several days (vacation)” button under the month calendar opens a small sheet with a first and a last day. Every day in the range becomes an excused skip day in one go — no more tapping through two weeks of holiday day by day. Days already checked off stay done, days already skipped stay untouched, and the Undo bar removes exactly the days the range added.",
        "Apply to all habits — a checkbox in the same sheet marks the range for every active habit at once (pre-ticked when there is more than one), since a vacation rarely pauses just one habit.",
        "Plan ahead — the range may lie in the future, so next month's trip can be entered today. The calendar now navigates up to a year forward; planned skip days show with their usual dashed outline, and tapping one un-marks it (other future days remain locked).",
        "Long-press for yesterday — forgot to check something off before bed? Press and hold the check circle of a daily or weekly habit on the Today screen and yesterday is marked done, with an Undo bar. If yesterday was already done, the app just says so. As with all backfills, no milestone celebration fires from it."
    ]),
    Release(version: "1.12.3", date: "31 Aug 2026", tagline: "Started too late? One tap.", bullets: [
        "Tap the timer to fix the start — while a fast runs, tapping the elapsed-time number on the Today card opens the fast editor directly, for the started-10-minutes-late case; saving returns straight to Today.",
        "Bottom bar rearranged — new order: Stats, New habit, Settings; the New habit button now matches its neighbors instead of being blue."
    ]),
    Release(version: "1.12.2", date: "31 Aug 2026", tagline: "Siri, on hold.", bullets: [
        "Voice launch parked — field testing showed current iOS offers no way for Shortcuts to open an installed web app, so the guide now recommends the Dock icon and explains what to re-try after future iOS updates."
    ]),
    Release(version: "1.12.1", date: "31 Aug 2026", tagline: "Honest Siri instructions.", bullets: [
        "Corrected voice-command setup — the “Open URLs” Shortcut recipe from v1.12 opens Safari on iOS, which holds a separate, empty copy of the app's data; anything started there never reaches the installed app. The recommended recipe is now a Shortcut with the “Open App” action targeting AMS Tracking: “Hey Siri, Fasten” opens the real app with the start/stop button one tap away. The URL commands remain for platforms that route links into the installed app."
    ]),
    Release(version: "1.12", date: "31 Aug 2026", tagline: "Hey Siri.", bullets: [
        "Voice-controllable fasting — the app now accepts URL commands (?fast=start, ?fast=stop, ?fast=toggle) acting on the fasting habit, so an iOS Shortcut opening that address starts or ends the fast — and Siri can run the Shortcut by name. Guards included: starting while already fasting or stopping with none running shows a note instead of doing anything, every action shows the usual Undo bar, and the command is cleaned from the address so it can't repeat on reload. Setup steps are in “How it works”."
    ]),
    Release(version: "1.11.3", date: "31 Aug 2026", tagline: "Updates that announce themselves.", bullets: [
        "Self-update check — the app now compares its version against the server when opened (and whenever it returns to the foreground, at most every 5 minutes). When a newer version is live, a bar appears with an Update button; one tap fetches and loads it. No more force-quitting to get updates.",
        "Manual check — Settings → “Check for app update” asks the server immediately and reports either the update bar or “You're on the latest version”."
    ]),
    Release(version: "1.11.2", date: "31 Aug 2026", tagline: "Buttons where the thumb lives.", bullets: [
        "Bottom bar — the settings, stats, and add buttons moved from the top of the Today screen into a floating bar at the bottom, within one-handed reach. The habit list gets extra bottom room so the last card never hides behind it, and the Undo bar now appears just above it."
    ]),
    Release(version: "1.11.1", date: "31 Aug 2026", tagline: "Never destructive on a tap.", bullets: [
        "Tapping a recorded fast opens its editor — previously, tapping a day with a fast on the fasting calendar removed it immediately (with only a brief Undo bar as the safety net). Now the tap opens the fast edit sheet with its start and stop times, a Delete button, and Cancel — nothing is changed or removed until you explicitly choose. Empty days still offer the backfill prompt, and skip days still un-mark on tap."
    ]),
    Release(version: "1.11", date: "31 Aug 2026", tagline: "The feel release.", bullets: [
        "Swipe between months — the history calendar now answers a horizontal swipe with the previous or next month; the arrows remain.",
        "Drag sheets to close — every bottom sheet follows your finger downward and dismisses when dragged far enough, like native iOS sheets. Tapping outside still works.",
        "Day progress under Today — a slim bar with “4 of 6 done” shows how the day stands at a glance, turning green when everything scheduled is done. Skip-marked days are excused from the count.",
        "Ink-drawn checkmarks — checking a habit off now draws the hand-drawn check in a quick stroke instead of an instant swap (still instant under reduced motion).",
        "Type & status-bar polish — long habit names shrink to fit their card and the detail title instead of truncating; forcing light or dark theme now also tints the iOS status bar correctly."
    ]),
    Release(version: "1.10.1", date: "31 Aug 2026", tagline: "Skip days, unmistakable.", bullets: [
        "Clearer skip-day cue — on the fasting calendar, a skip day now shows a bold dash inside its dashed circle in the habit's color at full strength, so it can't be confused with an empty day's faint ring."
    ]),
    Release(version: "1.10", date: "31 Aug 2026", tagline: "The fasting month, in hours.", bullets: [
        "Hours on the calendar — the fasting habit's month calendar now shows, for every day, the date on top and the number of hours fasted in a circle beneath it: green when that day's goal was met, gray when the fast fell short, red with a live count for a fast currently running, and the familiar dashed outline for skip days. Days with multiple fasts show their combined hours; per-fast goals are respected when judging green vs gray.",
        "Goal met counter — the Fasts card adds a “Goal met: N days” row alongside average, longest, and total.",
        "All calendar interactions are unchanged: tap to backfill or remove, 0 hours for a skip day, pencil for notes."
    ]),
    Release(version: "1.9.1", date: "31 Aug 2026", tagline: "Traffic-light ring.", bullets: [
        "Progress ring with phase colors — the fasting ring is now thicker and changes color with progress toward the goal: red for the first third, yellow for the middle third, green for the last stretch and beyond. One glance at the ring now tells you roughly how deep into the fast you are."
    ]),
    Release(version: "1.9", date: "31 Aug 2026", tagline: "An icon for everything.", bullets: [
        "24 new hand-drawn icons — the habit icon set grows from 16 to 40: heart, heartbeat, music, sleep, medication, water glass, coffee, less-screen-time, quit-smoking, alcohol-free, leaf, walking shoe, swimming, kettlebell, idea bulb, camera, paint brush, saving (€), pet paw, flower, mountain, conversation, cold shower (snowflake), and stairs — all in the same wobbly ink style.",
        "Icon search — a search field above the icon picker filters by name and keywords in both English and German (“kaffee”, “schlafen”, “rauchen”, “swim”…), so the right icon is three letters away."
    ]),
    Release(version: "1.8.1", date: "31 Aug 2026", tagline: "More habits per screen.", bullets: [
        "Compact cards — the Today panels are about a quarter shorter: tighter padding and gaps, a slightly smaller button, ring, and type, with every element still present. Roughly two more habits now fit on screen before scrolling."
    ]),
    Release(version: "1.8", date: "31 Aug 2026", tagline: "Polish & protection.", bullets: [
        "Every pixel answers — tapping a day in the year grid shows its date, status (done / skip / not done), and note in a toast; skip days now render hollow in the year grid too.",
        "Month markers — small letters in the year grid mark where each month begins, so a specific week is findable in the 365 pixels.",
        "App icon badge — the installed app's icon shows the number of scheduled habits still open today (a running fast counts as underway, not open). Updates whenever the app is used; the count clears when everything is done.",
        "Theme choice — Settings → Theme cycles auto / light / dark, for those who want the app permanently dark (or light) regardless of the system setting.",
        "Storage protection — the app requests persistent storage from the system so habit data can't be silently evicted, and Settings shows the protection status and current data size."
    ]),
    Release(version: "1.7", date: "30 Aug 2026", tagline: "The analysis layer.", bullets: [
        "Stats overview — a new chart button on the Today screen opens a per-habit overview: current streak, best streak, this month vs last month (completion % for daily and fasting habits, check-off count for weekly targets), and the last 30 days as a mini pixel strip with skip days hollow. Archived habits stay out of it.",
        "CSV export for Excel — Settings → “Export CSV for Excel” produces two files via the share sheet (or as downloads): days.csv with one row per logged day (date; habit; type; done/skip; note) and fasts.csv with one row per fast (habit; start; end; duration in hours). Semicolon-separated with decimal commas, so they open cleanly in German/Austrian Excel."
    ]),
    Release(version: "1.6", date: "30 Aug 2026", tagline: "Life happens.", bullets: [
        "Skip days — a third state for any past day: excused. In the history calendar, daily and weekly habits now cycle done → skip → empty on tap; for fasting, entering 0 hours marks a skip day. Skip days show as hollow dashed circles (and hollow week dots), don't break streaks, don't count as completed, and leave the completion denominator — so a holiday no longer wipes out a 100-day streak. For weekly targets, a week containing a skip day is excused when the target wasn't met.",
        "Per-fast goal — press-and-hold the start button to choose tonight's goal (13/15/16/18h or the default) before the fast begins, or change the running fast's goal from its entry in the detail list. Ring, countdown, and goal time all follow it; the habit's default stays unchanged.",
        "Day notes — a pencil toggle in the calendar header switches to note mode: tap a day to write a short note, marked on the day and listed under the calendar for that month. Notes are included in backups."
    ]),
    Release(version: "1.5.4", date: "30 Aug 2026", tagline: "Color, fine-tuned.", bullets: [
        "Only the goal time is colored — under the fasting timer, the “goal 11:30” line keeps the habit's color while the “14:19 left” line is back to quiet gray, so the time you can eat again stands out."
    ]),
    Release(version: "1.5.3", date: "30 Aug 2026", tagline: "Countdown in color.", bullets: [
        "Countdown matches the timer — the “left / goal” lines under the fasting timer now use the habit's color, same as the elapsed time above them, instead of gray; “goal reached” shows in green like the timer does."
    ]),
    Release(version: "1.5.2", date: "30 Aug 2026", tagline: "Goal time on the card.", bullets: [
        "Goal arrival time — the fasting countdown now also shows the clock time at which the goal will be reached, in 24-hour format right below the remaining time (e.g. “14:19 left / goal 11:30”), so you know at a glance when you can eat again. Suggested by the household's second user."
    ]),
    Release(version: "1.5.1", date: "30 Aug 2026", tagline: "Countdown to the goal.", bullets: [
        "Time left to goal — while a fast is running, the label under the timer now shows how many hours and minutes remain until your goal (e.g. “14:20 to goal”) instead of just naming the goal. It updates live and still switches to “goal reached” in green once you cross it."
    ]),
    Release(version: "1.5", date: "30 Aug 2026", tagline: "Delight & data.", bullets: [
        "Milestone celebrations — reaching a round streak (7, 14, 30, 50, 100, 200, 365… days for daily habits; 4, 10, 26, 52, 104 weeks for weekly targets) or finishing your longest fast yet triggers a brief hand-drawn confetti burst in the habit's color. Each milestone celebrates exactly once, celebrations never block a tap, and they respect the system's reduced-motion setting.",
        "Fast-length chart — the fasting detail view now charts up to the last 30 fasts as bars with a dashed line at your goal, so you can see the trend, not just the average. Tapping a bar opens that fast for editing.",
        "Backups via the share sheet — on iPhone, Export now opens the native share sheet so the backup JSON can be saved straight to iCloud Drive or sent anywhere; on desktop browsers it downloads as before. Settings shows when the last backup was made and turns amber once it is more than 30 days old (or was never made)."
    ]),
    Release(version: "1.4", date: "30 Aug 2026", tagline: "Habit power.", bullets: [
        "Weekly-target habits — a third habit type for \"3× per week\" goals: pick a target from 1–7 when creating the habit, check off days as they happen, and the card shows this week's count against the target. Streaks are counted in weeks that hit the target (like \"21 weeks\"), and the week in progress never breaks a streak early. The detail view shows weekly streaks and how many weeks you've met since starting.",
        "Archive habits — a habit you're done with (season over, goal reached) can be archived from its detail view: it leaves the Today screen but keeps its full history, visible count in Settings → Archived habits, restorable with one tap, with Undo when archiving.",
        "Grid layout — Settings → Layout toggles a two-column card grid for the Today screen, handy once the habit list grows; the setting is remembered and included in backups.",
        "The habit type picker was redesigned as a vertical list to fit the three types comfortably."
    ]),
    Release(version: "1.3", date: "30 Aug 2026", tagline: "The daily loop, sharpened.", bullets: [
        "Edit fast times — tap any fast in the detail list, including the one currently running, to correct when it actually started and ended, or to delete it. No more wrong fasts because you pressed start late.",
        "Fasting goal with progress ring — give a start/stop habit a goal (e.g. 16 hours) when editing it; while fasting, a ring fills around the card's button and turns green with the timer once the goal is reached.",
        "Reorder habits — Settings → Reorder habits, with up/down arrows per habit.",
        "Undo instead of pop-ups — starting/ending a fast and removing entries now show a brief Undo bar instead of confirmation dialogs; only deleting a whole habit still asks first."
    ]),
    Release(version: "1.2", date: "30 Aug 2026", tagline: "Edit the past.", bullets: [
        "Editable history calendar — each habit's detail view now starts with a month calendar where any past day can be toggled: tap an empty day to check it off late, tap a filled day to remove an entry made by mistake. Arrows navigate back through earlier months; future days are locked, today is outlined.",
        "Backfilled fasts — for start/stop habits, tapping an empty past day asks for the fast's length in hours and records it against that day; tapping a filled day removes the fast(s) recorded there, after confirmation.",
        "Streaks, week dots, pixel grids, and completion stats all recompute immediately after an edit."
    ]),
    Release(version: "1.1", date: "30 Aug 2026", tagline: "Hand-drawn icons.", bullets: [
        "Hand-drawn icon set — every stock emoji in the app has been replaced with a custom hand-drawn ink-style icon: all 16 habit icons, the check/play/stop action buttons, the streak flame, the week-dot cards' details, and every settings and navigation glyph. Icons are drawn as wobbly round-cap strokes and take on each habit's color.",
        "Matching app icons — the launcher, favicon, and home-screen icons were redrawn in the same hand-drawn style.",
        "Habits created in v1.0 are migrated automatically — stored emoji are mapped to the corresponding hand-drawn icon."
    ]),
    Release(version: "1.0", date: "30 Aug 2026", tagline: "Initial release of AMS Tracking.", bullets: [
        "Today overview — all habits as colored cards in one scrolling area: emoji icon, habit color, check circle, current streak with a flame, and Monday-first week dots with a completed/scheduled ratio.",
        "Daily habit type — one tap checks off today, one tap undoes it; optional weekday scheduling (e.g. Mon/Wed/Fri only) where off-days neither count nor break streaks.",
        "Start/stop timer habit type — built for intermittent fasting: a single toggle button starts the fast in the evening and stops it when eating again; the card shows the live elapsed time (h:mm) while running and the last fast's duration when stopped. An \"Intermittent Fasting\" habit is pre-created on first launch.",
        "Fast history — the detail view lists the last 10 fasts with date and duration, plus average, longest, and total count; individual fasts can be deleted. Accidental stops under 5 minutes require confirmation.",
        "Pixel year view — a \"365 days, pixel by pixel\" grid per year (all years with data), with current streak, longest streak, and completion percentage.",
        "Habit management — create and edit habits with 16 emoji icons and an 8-color palette; delete with confirmation removes the habit and its history.",
        "Backup — export all data as a JSON file and import it back, with a confirmation before anything is replaced.",
        "App platform — installable PWA with generated icons, offline via service worker (network-first pages so updates arrive), automatic light/dark mode, and all data kept in local storage on the device — no servers, no accounts."
    ]),
    ]
}
